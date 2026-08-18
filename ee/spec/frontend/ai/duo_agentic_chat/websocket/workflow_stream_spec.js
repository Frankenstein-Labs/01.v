import {
  WorkflowStream,
  WORKFLOW_STREAM_STATES,
} from 'ee/ai/duo_agentic_chat/websocket/workflow_stream';
import StreamWorker from 'ee/ai/duo_agentic_chat/websocket/stream_worker';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';
import {
  logStreamClose,
  reportStreamClose,
} from 'ee/ai/duo_agentic_chat/observability/stream_close_reporting';

const mockPostMessage = jest.fn();
const mockTerminate = jest.fn();
const mockAddEventListener = jest.fn();
const mockRemoveEventListener = jest.fn();

jest.mock('ee/ai/duo_agentic_chat/websocket/stream_worker', () =>
  jest.fn().mockImplementation(() => ({
    postMessage: mockPostMessage,
    terminate: mockTerminate,
    addEventListener: mockAddEventListener,
    removeEventListener: mockRemoveEventListener,
  })),
);

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils', () => ({
  captureExceptionForDuoChat: jest.fn(),
}));

// Mocked rather than asserted through the console, so these tests pin who reports
// what and when; the messages themselves are covered by its own spec.
jest.mock('ee/ai/duo_agentic_chat/observability/stream_close_reporting', () => ({
  logStreamClose: jest.fn(),
  reportStreamClose: jest.fn(),
}));

describe('WorkflowStream', () => {
  const TEST_URL = 'ws://localhost/api/v4/ai/duo_workflows/ws';
  const TEST_INITIAL_MESSAGE = { startRequest: { workflowID: '123' } };

  let stream;
  let workerMessageHandler;

  function simulateWorkerMessage(data) {
    workerMessageHandler({ data });
  }

  beforeEach(() => {
    mockPostMessage.mockClear();
    mockTerminate.mockClear();
    mockAddEventListener.mockClear();
    mockRemoveEventListener.mockClear();
    captureExceptionForDuoChat.mockClear();
    logStreamClose.mockClear();
    reportStreamClose.mockClear();

    stream = new WorkflowStream();
    stream.connect(TEST_URL, TEST_INITIAL_MESSAGE);

    const [, handler] = mockAddEventListener.mock.calls.find(([event]) => event === 'message');
    workerMessageHandler = handler;
  });

  afterEach(() => {
    stream.terminate();
  });

  describe('connect', () => {
    it('sends connect command to worker', () => {
      expect(mockPostMessage).toHaveBeenCalledWith({
        type: 'connect',
        url: TEST_URL,
        initialMessage: TEST_INITIAL_MESSAGE,
      });
    });

    it('reuses the same worker on subsequent connects', () => {
      const callCount = StreamWorker.mock.instances.length;
      stream.connect('ws://other', null);
      expect(StreamWorker.mock.instances).toHaveLength(callCount);
    });

    it('clears message buffer on new connect', () => {
      simulateWorkerMessage({ type: 'message', data: '{"old": true}' });

      stream.connect('ws://other', null);

      expect(stream.getStatus().bufferedCount).toBe(0);
    });

    it('converts relative URL to absolute before sending to worker', () => {
      const relativeUrl = '/api/v4/ai/duo_workflows/ws';
      stream.connect(relativeUrl, null);

      const connectCall = mockPostMessage.mock.calls.find(([msg]) => msg.type === 'connect');
      expect(connectCall[0].url).toMatch(/^ws(s)?:\/\//);
      expect(connectCall[0].url).toContain('/api/v4/ai/duo_workflows/ws');
    });
  });

  describe('state machine', () => {
    it('starts in IDLE state', () => {
      expect(new WorkflowStream().state).toBe(WORKFLOW_STREAM_STATES.IDLE);
    });

    it('transitions to CONNECTING on connect()', () => {
      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.CONNECTING);
    });

    it('transitions to OPENED on open event', () => {
      simulateWorkerMessage({ type: 'open' });
      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.OPENED);
    });

    it('transitions to CLOSED on normal close (code 1000)', () => {
      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'close', code: 1000 });
      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.CLOSED);
    });

    it('transitions to ERROR on retryable close (code 1001)', () => {
      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'close', code: 1001 });
      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.ERROR);
    });

    it('transitions to ERROR on unknown close code', () => {
      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'close', code: 9999 });
      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.ERROR);
    });
  });

  describe('close-code categorisation', () => {
    it.each([
      [1000, 'normal', false],
      [1001, 'going_away', true],
      [1008, 'policy_violation', false],
      [1013, 'try_again_later', false],
      [4400, 'invalid_request', false],
      [9999, 'error', true],
    ])('code %i → category %s, retryable %s', (code, category, retryable) => {
      const callback = jest.fn();
      stream.subscribe('close', callback);

      simulateWorkerMessage({ type: 'close', code, reason: '' });

      expect(callback).toHaveBeenCalledWith(expect.objectContaining({ code, category, retryable }));
    });
  });

  describe('send', () => {
    it('forwards send command to worker', () => {
      const message = { approval: { approved: true } };
      stream.send(message);
      expect(mockPostMessage).toHaveBeenCalledWith({ type: 'send', message });
    });

    it('does nothing when worker is not created', () => {
      const message = { approval: { approved: true } };
      const messageTwo = { goal: '2+2?' };

      stream.send(message);
      expect(mockPostMessage).toHaveBeenCalledWith({ type: 'send', message });
      stream.terminate();
      stream.send(messageTwo);
      expect(mockPostMessage).not.toHaveBeenCalledWith({ type: 'send', message: messageTwo });
    });
  });

  describe('disconnect', () => {
    it('sends disconnect command to worker', () => {
      stream.disconnect();
      expect(mockPostMessage).toHaveBeenCalledWith({ type: 'disconnect' });
    });

    it('clears message buffer', () => {
      simulateWorkerMessage({ type: 'message', data: '{"id": 1}' });
      expect(stream.getStatus().bufferedCount).toBe(1);
      stream.disconnect();
      expect(stream.getStatus().bufferedCount).toBe(0);
    });

    // `stream_worker` suppresses the close event for a client-initiated close,
    // so nothing arrives to move the state on. Without this the stream keeps
    // reporting itself open with no socket behind it.
    describe('state afterwards', () => {
      beforeEach(() => {
        simulateWorkerMessage({ type: 'open' });
        stream.disconnect();
      });

      it('is closed', () => {
        expect(stream.state).toBe(WORKFLOW_STREAM_STATES.CLOSED);
      });

      it('reports itself disconnected', () => {
        expect(stream.getStatus().connected).toBe(false);
      });
    });
  });

  describe('subscribe', () => {
    it('receives messages from worker', () => {
      const callback = jest.fn();
      stream.subscribe('message', callback);

      const payload = { type: 'message', data: '{"test": true}' };
      simulateWorkerMessage(payload);

      expect(callback).toHaveBeenCalledWith(payload);
    });

    it('receives open events', () => {
      const callback = jest.fn();
      stream.subscribe('open', callback);

      simulateWorkerMessage({ type: 'open' });

      expect(callback).toHaveBeenCalledWith({ type: 'open' });
    });

    it('receives error events from the worker', () => {
      const callback = jest.fn();
      stream.subscribe('error', callback);

      simulateWorkerMessage({ type: 'error', origin: 'decode', message: 'oops' });

      expect(callback).toHaveBeenCalledWith({ type: 'error', origin: 'decode', message: 'oops' });
    });

    it('receives enriched close events with the categorised descriptor', () => {
      const callback = jest.fn();
      stream.subscribe('close', callback);

      simulateWorkerMessage({ type: 'close', code: 1013, reason: 'flow locked' });

      expect(callback).toHaveBeenCalledWith({
        type: 'close',
        code: 1013,
        reason: 'flow locked',
        category: 'try_again_later',
        retryable: false,
        expected: true,
      });
    });

    it('supports multiple subscribers for the same event', () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();
      stream.subscribe('message', callback1);
      stream.subscribe('message', callback2);

      const payload = { type: 'message', data: '{"test": true}' };
      simulateWorkerMessage(payload);

      expect(callback1).toHaveBeenCalledWith(payload);
      expect(callback2).toHaveBeenCalledWith(payload);
    });

    it('returns a disposable subscription', () => {
      const callback = jest.fn();
      const subscription = stream.subscribe('message', callback);

      subscription.dispose();
      simulateWorkerMessage({ type: 'message', data: '{}' });

      expect(callback).not.toHaveBeenCalled();
    });

    it('removes event type entry from subscribers when last callback is disposed', () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();
      const sub1 = stream.subscribe('message', callback1);
      const sub2 = stream.subscribe('message', callback2);

      sub1.dispose();
      sub2.dispose();

      simulateWorkerMessage({ type: 'message', data: '{"new": true}' });

      expect(stream.getStatus().bufferedCount).toBe(1);
    });
  });

  describe('message buffering', () => {
    it('buffers messages when no subscribers exist', () => {
      const msg1 = { type: 'message', data: '{"id": 1}' };
      const msg2 = { type: 'message', data: '{"id": 2}' };
      simulateWorkerMessage(msg1);
      simulateWorkerMessage(msg2);

      expect(stream.getStatus().bufferedCount).toBe(2);
    });

    it('replays buffered messages when subscriber arrives', () => {
      const msg1 = { type: 'message', data: '{"id": 1}' };
      const msg2 = { type: 'message', data: '{"id": 2}' };
      simulateWorkerMessage(msg1);
      simulateWorkerMessage(msg2);

      const callback = jest.fn();
      stream.subscribe('message', callback);

      expect(callback).toHaveBeenCalledTimes(2);
      expect(callback).toHaveBeenNthCalledWith(1, msg1);
      expect(callback).toHaveBeenNthCalledWith(2, msg2);
    });

    it('replays buffer to each new subscriber without clearing it', () => {
      simulateWorkerMessage({ type: 'message', data: '{}' });

      const callback1 = jest.fn();
      stream.subscribe('message', callback1);

      const callback2 = jest.fn();
      stream.subscribe('message', callback2);

      expect(callback1).toHaveBeenCalledTimes(1);
      expect(callback2).toHaveBeenCalledTimes(1);
      expect(stream.getStatus().bufferedCount).toBe(1);
    });

    it('buffers live messages received while subscribers are active', () => {
      const callback = jest.fn();
      stream.subscribe('message', callback);

      const msg = { type: 'message', data: '{"live": true}' };
      simulateWorkerMessage(msg);

      expect(callback).toHaveBeenCalledWith(msg);
      expect(stream.getStatus().bufferedCount).toBe(1);
    });

    it('buffers messages after last subscriber unsubscribes', () => {
      const callback = jest.fn();
      const subscription = stream.subscribe('message', callback);
      subscription.dispose();

      simulateWorkerMessage({ type: 'message', data: '{"after": true}' });

      expect(callback).not.toHaveBeenCalled();
      expect(stream.getStatus().bufferedCount).toBe(1);
    });

    it('does not clear buffer when replay callback throws', () => {
      const msg = { type: 'message', data: '{"id": 1}' };
      simulateWorkerMessage(msg);

      const error = new Error('subscriber error');
      const throwingCallback = jest.fn(() => {
        throw error;
      });

      expect(() => stream.subscribe('message', throwingCallback)).not.toThrow();
      expect(throwingCallback).toHaveBeenCalledWith(msg);
      expect(stream.getStatus().bufferedCount).toBe(1);
      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });

    // The hub refuses to overflow rather than truncating silently. Clearing on
    // close and disconnect is what keeps a real connection from getting here.
    describe('when the message buffer overflows', () => {
      beforeEach(() => {
        for (let i = 0; i < 1000; i += 1) {
          simulateWorkerMessage({ type: 'message', data: `{"id": ${i}}` });
        }
      });

      // This runs inside a worker `message` listener, so an escaping throw
      // would surface as an uncaught error instead of stopping here.
      it('does not let the error escape the worker listener', () => {
        expect(() => simulateWorkerMessage({ type: 'message', data: '{}' })).not.toThrow();
      });

      it('drops the stale backlog, keeping only the message that overflowed', () => {
        simulateWorkerMessage({ type: 'message', data: '{"new": true}' });

        expect(stream.getStatus().bufferedCount).toBe(1);
      });

      it('still delivers the message that overflowed', () => {
        const callback = jest.fn();
        stream.subscribe('message', callback);
        callback.mockClear();

        const msg = { type: 'message', data: '{"overflowing": true}' };
        simulateWorkerMessage(msg);

        expect(callback).toHaveBeenCalledTimes(1);
        expect(callback).toHaveBeenCalledWith(msg);
      });

      // Proves the retry buffered it too, rather than only dispatching it.
      it('replays the recovered message to a later subscriber', () => {
        const msg = { type: 'message', data: '{"overflowing": true}' };
        simulateWorkerMessage(msg);

        const callback = jest.fn();
        stream.subscribe('message', callback);

        expect(callback).toHaveBeenCalledTimes(1);
        expect(callback).toHaveBeenCalledWith(msg);
      });
    });

    it('does not buffer non-message events', () => {
      simulateWorkerMessage({ type: 'close', code: 1000 });
      expect(stream.getStatus().bufferedCount).toBe(0);
    });

    it.each([
      ['a normal close', 1000],
      ['a retryable close', 1001],
    ])('clears the buffer on %s', (_, code) => {
      simulateWorkerMessage({ type: 'message', data: '{"id": 1}' });

      simulateWorkerMessage({ type: 'close', code });

      expect(stream.getStatus().bufferedCount).toBe(0);
    });
  });

  describe('error handling', () => {
    it('does not propagate errors thrown by a subscriber during live message delivery', () => {
      const throwingCallback = jest.fn(() => {
        throw new Error('subscriber error');
      });
      stream.subscribe('message', throwingCallback);

      expect(() => simulateWorkerMessage({ type: 'message', data: '{}' })).not.toThrow();
    });

    it('captures exception when a subscriber throws during live message delivery', () => {
      const error = new Error('subscriber error');
      stream.subscribe(
        'message',
        jest.fn(() => {
          throw error;
        }),
      );

      simulateWorkerMessage({ type: 'message', data: '{}' });

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });

    it('continues delivering to remaining subscribers when one throws', () => {
      const healthyCallback = jest.fn();
      stream.subscribe(
        'message',
        jest.fn(() => {
          throw new Error('first subscriber error');
        }),
      );
      stream.subscribe('message', healthyCallback);

      const payload = { type: 'message', data: '{}' };
      simulateWorkerMessage(payload);

      expect(healthyCallback).toHaveBeenCalledWith(payload);
    });

    it('captures exception when a subscriber throws for non-message events', () => {
      const error = new Error('open handler error');
      stream.subscribe(
        'open',
        jest.fn(() => {
          throw error;
        }),
      );

      expect(() => simulateWorkerMessage({ type: 'open' })).not.toThrow();
      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });
  });

  describe('workflowStatus', () => {
    const makeMessageEvent = (status) => ({
      type: 'message',
      data: { newCheckpoint: { status, checkpoint: {} } },
    });

    it('starts as null', () => {
      expect(stream.getStatus().workflowStatus).toBeNull();
    });

    it('exposes workflowStatus via getter', () => {
      simulateWorkerMessage(makeMessageEvent('RUNNING'));
      expect(stream.workflowStatus).toBe('RUNNING');
    });

    it('stores status from newCheckpoint in received messages', () => {
      simulateWorkerMessage(makeMessageEvent('RUNNING'));
      expect(stream.getStatus().workflowStatus).toBe('RUNNING');
    });

    it('updates workflowStatus when a newer message arrives', () => {
      simulateWorkerMessage(makeMessageEvent('RUNNING'));
      simulateWorkerMessage(makeMessageEvent('INPUT_REQUIRED'));
      expect(stream.getStatus().workflowStatus).toBe('INPUT_REQUIRED');
    });

    it('resets workflowStatus to null on connect()', () => {
      simulateWorkerMessage(makeMessageEvent('RUNNING'));
      stream.connect('ws://other', null);
      expect(stream.getStatus().workflowStatus).toBeNull();
    });

    it('resets workflowStatus to null on terminate()', () => {
      simulateWorkerMessage(makeMessageEvent('RUNNING'));
      stream.terminate();
      expect(stream.getStatus().workflowStatus).toBeNull();
    });
  });

  describe('getStatus', () => {
    it('reports disconnected initially', () => {
      expect(stream.getStatus().connected).toBe(false);
    });

    it('reports connected after open event', () => {
      simulateWorkerMessage({ type: 'open' });
      expect(stream.getStatus().connected).toBe(true);
    });

    it('reports disconnected after normal close', () => {
      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'close', code: 1000 });
      expect(stream.getStatus().connected).toBe(false);
    });

    it('reports disconnected after retryable close (state ERROR)', () => {
      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'close', code: 1001 });
      expect(stream.getStatus().connected).toBe(false);
      expect(stream.getStatus().state).toBe(WORKFLOW_STREAM_STATES.ERROR);
    });
  });

  describe('terminate', () => {
    it('terminates the worker', () => {
      stream.terminate();
      expect(mockTerminate).toHaveBeenCalled();
    });

    it('resets state to IDLE', () => {
      simulateWorkerMessage({ type: 'open' });
      stream.terminate();
      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.IDLE);
    });

    it('resets connection status', () => {
      simulateWorkerMessage({ type: 'open' });
      stream.terminate();
      expect(stream.getStatus().connected).toBe(false);
    });

    it('clears message buffer', () => {
      simulateWorkerMessage({ type: 'message', data: '{}' });
      stream.terminate();
      expect(stream.getStatus().bufferedCount).toBe(0);
    });

    it('clears subscribers so subsequent events are not delivered', () => {
      const callback = jest.fn();
      stream.subscribe('message', callback);
      stream.terminate();

      stream.connect(TEST_URL, TEST_INITIAL_MESSAGE);
      const [, handler] = mockAddEventListener.mock.calls
        .slice()
        .reverse()
        .find(([event]) => event === 'message');
      workerMessageHandler = handler;

      simulateWorkerMessage({ type: 'message', data: '{}' });

      expect(callback).not.toHaveBeenCalled();
    });

    it('sends disconnect before terminating', () => {
      stream.terminate();
      const disconnectCall = mockPostMessage.mock.calls.find(([msg]) => msg.type === 'disconnect');
      expect(disconnectCall).toHaveLength(1);
    });
  });

  describe('close observability', () => {
    it.each([
      ['a normal close', { code: 1000, category: 'normal', expected: true }],
      ['a server restart', { code: 1001, category: 'going_away', expected: true }],
      ['being out of credits', { code: 1008, category: 'policy_violation', expected: true }],
      ['another tab streaming', { code: 1013, category: 'try_again_later', expected: true }],
      ['a rejected request', { code: 4400, category: 'invalid_request', expected: false }],
      ['an unrecognised code', { code: 1006, category: 'error', expected: false }],
    ])('logs %s', (_, descriptor) => {
      simulateWorkerMessage({ type: 'close', code: descriptor.code, reason: '' });

      expect(logStreamClose).toHaveBeenCalledWith(expect.objectContaining(descriptor));
    });

    it('leaves the reporting decision to reportStreamClose', () => {
      simulateWorkerMessage({ type: 'close', code: 1000, reason: '' });

      expect(reportStreamClose).toHaveBeenCalledWith(
        expect.objectContaining({ code: 1000, expected: true }),
      );
    });

    // The handler took the close over, and what to make of it comes with it: a
    // retryable close about to be retried should not be reported twice, or at all.
    describe('when a close handler is installed', () => {
      beforeEach(() => {
        stream.interceptClose(jest.fn());
        simulateWorkerMessage({ type: 'close', code: 4400, reason: '' });
      });

      it('still logs the close', () => {
        expect(logStreamClose).toHaveBeenCalledWith(expect.objectContaining({ code: 4400 }));
      });

      it('does not report it', () => {
        expect(reportStreamClose).not.toHaveBeenCalled();
      });
    });
  });

  describe('interceptClose', () => {
    it('routes closes to the handler instead of emitting them', () => {
      const handler = jest.fn();
      const subscriber = jest.fn();
      stream.interceptClose(handler);
      stream.subscribe('close', subscriber);

      simulateWorkerMessage({ type: 'close', code: 1001, reason: '' });

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({ code: 1001, category: 'going_away', retryable: true }),
      );
      expect(subscriber).not.toHaveBeenCalled();
    });

    // The handler decides whether the close is seen, and emitting on the hub is
    // how it says yes.
    it('lets the handler forward the close on the hub', () => {
      const subscriber = jest.fn();
      stream.interceptClose((event) => stream.hub.$emit('close', event));
      stream.subscribe('close', subscriber);

      simulateWorkerMessage({ type: 'close', code: 1000, reason: '' });

      expect(subscriber).toHaveBeenCalledWith(expect.objectContaining({ code: 1000 }));
    });

    it('still moves the state on, whether or not the close is forwarded', () => {
      stream.interceptClose(jest.fn());

      simulateWorkerMessage({ type: 'close', code: 1000, reason: '' });

      expect(stream.state).toBe(WORKFLOW_STREAM_STATES.CLOSED);
    });

    it('still clears the buffer before the handler runs', () => {
      simulateWorkerMessage({ type: 'message', data: '{"id": 1}' });
      stream.interceptClose(() => {
        expect(stream.getStatus().bufferedCount).toBe(0);
      });

      expect.hasAssertions();
      simulateWorkerMessage({ type: 'close', code: 1001, reason: '' });
    });
  });

  describe('buffer replay and close event ordering', () => {
    it('delivers buffered messages to message subscriber before subsequent close event', () => {
      const events = [];

      simulateWorkerMessage({ type: 'message', data: '{"id": 1}' });
      simulateWorkerMessage({ type: 'message', data: '{"id": 2}' });

      stream.subscribe('message', (msg) => events.push({ type: 'message', data: msg.data }));
      stream.subscribe('close', (msg) => events.push({ type: 'close', code: msg.code }));

      simulateWorkerMessage({ type: 'close', code: 1000 });

      expect(events).toEqual([
        { type: 'message', data: '{"id": 1}' },
        { type: 'message', data: '{"id": 2}' },
        { type: 'close', code: 1000 },
      ]);
    });

    it('replays buffered messages to each new subscriber independently', () => {
      const msg = { type: 'message', data: '{"id": 1}' };
      simulateWorkerMessage(msg);

      const first = jest.fn();
      const second = jest.fn();

      stream.subscribe('message', first);
      stream.subscribe('message', second);

      expect(first).toHaveBeenCalledTimes(1);
      expect(first).toHaveBeenCalledWith(msg);
      expect(second).toHaveBeenCalledTimes(1);
      expect(second).toHaveBeenCalledWith(msg);
    });
  });
});
