import {
  connect,
  send,
  disconnect,
  subscribe,
  getStatus,
  terminate,
  toAbsoluteWebSocketUrl,
} from 'ee/ai/duo_agentic_chat/websocket/stream_manager';
import StreamWorker from 'ee/ai/duo_agentic_chat/websocket/stream_worker';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';

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

describe('stream_manager', () => {
  const TEST_URL = 'ws://localhost/api/v4/ai/duo_workflows/ws';
  const TEST_INITIAL_MESSAGE = { startRequest: { workflowID: '123' } };

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

    terminate();

    connect(TEST_URL, TEST_INITIAL_MESSAGE);

    {
      const [, handler] = mockAddEventListener.mock.calls.find(([event]) => event === 'message');
      workerMessageHandler = handler;
    }
  });

  afterEach(() => {
    terminate();
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

      connect('ws://other', null);

      expect(StreamWorker.mock.instances).toHaveLength(callCount);
    });

    it('clears message buffer on new connect', () => {
      simulateWorkerMessage({ type: 'message', data: '{"old": true}' });

      connect('ws://other', null);

      const callback = jest.fn();
      subscribe('message', callback);

      expect(callback).not.toHaveBeenCalled();
    });
  });

  describe('send', () => {
    it('forwards send command to worker', () => {
      const message = { approval: { approved: true } };
      send(message);

      expect(mockPostMessage).toHaveBeenCalledWith({
        type: 'send',
        message,
      });
    });

    it('does nothing when worker is not created', () => {
      terminate();
      expect(() => send({ test: true })).not.toThrow();
    });
  });

  describe('disconnect', () => {
    it('sends disconnect command to worker', () => {
      disconnect();

      expect(mockPostMessage).toHaveBeenCalledWith({ type: 'disconnect' });
    });

    it('does nothing when worker is not created', () => {
      terminate();
      expect(() => disconnect()).not.toThrow();
    });
  });

  describe('subscribe', () => {
    it('receives messages from worker', () => {
      const callback = jest.fn();
      subscribe('message', callback);

      const payload = { type: 'message', data: '{"test": true}' };
      simulateWorkerMessage(payload);

      expect(callback).toHaveBeenCalledWith(payload);
    });

    it('receives open events', () => {
      const callback = jest.fn();
      subscribe('open', callback);

      simulateWorkerMessage({ type: 'open' });

      expect(callback).toHaveBeenCalledWith({ type: 'open' });
    });

    it('receives close events with code and reason', () => {
      const callback = jest.fn();
      subscribe('close', callback);

      simulateWorkerMessage({ type: 'close', code: 1013, reason: 'flow locked' });

      expect(callback).toHaveBeenCalledWith({ type: 'close', code: 1013, reason: 'flow locked' });
    });

    it('receives error events', () => {
      const callback = jest.fn();
      subscribe('error', callback);

      simulateWorkerMessage({ type: 'error' });

      expect(callback).toHaveBeenCalledWith({ type: 'error' });
    });

    it('captures the error with an origin tag and the full payload as extra', () => {
      simulateWorkerMessage({
        type: 'error',
        origin: 'decode',
        message: 'read failed',
      });

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(
        new Error('Duo Chat WebSocket error (decode)'),
        {
          extra: { type: 'error', origin: 'decode', message: 'read failed' },
          tags: { origin: 'decode' },
        },
      );
    });

    it('falls back to an unknown origin tag when the worker does not provide one', () => {
      simulateWorkerMessage({ type: 'error' });

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(
        new Error('Duo Chat WebSocket error (unknown)'),
        {
          extra: { type: 'error' },
          tags: { origin: 'unknown' },
        },
      );
    });

    it('supports multiple subscribers for the same event', () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();
      subscribe('message', callback1);
      subscribe('message', callback2);

      const payload = { type: 'message', data: '{"test": true}' };
      simulateWorkerMessage(payload);

      expect(callback1).toHaveBeenCalledWith(payload);
      expect(callback2).toHaveBeenCalledWith(payload);
    });

    it('returns a disposable subscription', () => {
      const callback = jest.fn();
      const subscription = subscribe('message', callback);

      subscription.dispose();

      simulateWorkerMessage({ type: 'message', data: '{}' });

      expect(callback).not.toHaveBeenCalled();
    });

    it('removes event type entry from subscribers when last callback is disposed', () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();
      const sub1 = subscribe('message', callback1);
      const sub2 = subscribe('message', callback2);

      sub1.dispose();
      sub2.dispose();

      // After disposing all subscribers, new messages should buffer
      simulateWorkerMessage({ type: 'message', data: '{"new": true}' });

      expect(getStatus().bufferedCount).toBe(1);
    });
  });

  describe('error throttling', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('suppresses repeated errors while the connection keeps delivering messages', () => {
      let now = 1_000_000;
      jest.spyOn(Date, 'now').mockImplementation(() => now);

      simulateWorkerMessage({ type: 'open' });

      const callback = jest.fn();
      subscribe('error', callback);

      for (let i = 0; i < 5; i += 1) {
        now += 300;
        simulateWorkerMessage({ type: 'message', data: `{"id": ${i}}` });
        now += 50;
        simulateWorkerMessage({ type: 'error' });
      }

      expect(callback).not.toHaveBeenCalled();
      expect(captureExceptionForDuoChat).not.toHaveBeenCalled();
    });

    it('escalates an error once the connection has been silent past the stall threshold', () => {
      let now = 1_000_000;
      jest.spyOn(Date, 'now').mockImplementation(() => now);

      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'message', data: '{}' });

      const callback = jest.fn();
      subscribe('error', callback);

      now += 5001;
      simulateWorkerMessage({ type: 'error' });

      expect(callback).toHaveBeenCalledWith({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(1);
    });

    it('rate-limits repeated escalations for a connection that stays stalled', () => {
      let now = 1_000_000;
      jest.spyOn(Date, 'now').mockImplementation(() => now);

      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'message', data: '{}' });

      now += 5001;
      simulateWorkerMessage({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(1);

      now += 1000; // still within ERROR_ESCALATION_INTERVAL_MS of the last escalation
      simulateWorkerMessage({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(1);

      now += 10001; // past ERROR_ESCALATION_INTERVAL_MS
      simulateWorkerMessage({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(2);
    });

    it('escalates an error that arrives before any message has ever been received', () => {
      const callback = jest.fn();
      subscribe('error', callback);

      simulateWorkerMessage({ type: 'error' });

      expect(callback).toHaveBeenCalledWith({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(1);
    });

    it('escalates an error that fires right after open, before any data has arrived', () => {
      // Regression case: a server can accept the handshake and then immediately
      // send an error frame (e.g. an auth or protocol failure) without ever
      // delivering a real message. `open` must not count as proof of liveness,
      // or this would be silently suppressed for up to STALL_THRESHOLD_MS.
      const callback = jest.fn();
      subscribe('error', callback);

      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'error' });

      expect(callback).toHaveBeenCalledWith({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(1);
    });

    it('resets stall tracking on a fresh connect', () => {
      let now = 1_000_000;
      jest.spyOn(Date, 'now').mockImplementation(() => now);

      simulateWorkerMessage({ type: 'open' });
      now += 5001;
      simulateWorkerMessage({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(1);

      connect(TEST_URL, TEST_INITIAL_MESSAGE);
      {
        const [, handler] = mockAddEventListener.mock.calls.find(([event]) => event === 'message');
        workerMessageHandler = handler;
      }

      // Immediately after a fresh connect, no message has arrived yet, so this
      // error should escalate again rather than being rate-limited by the
      // previous connection's escalation.
      simulateWorkerMessage({ type: 'error' });
      expect(captureExceptionForDuoChat).toHaveBeenCalledTimes(2);
    });
  });

  describe('message buffering', () => {
    it('buffers messages when no subscribers exist', () => {
      const msg1 = { type: 'message', data: '{"id": 1}' };
      const msg2 = { type: 'message', data: '{"id": 2}' };
      simulateWorkerMessage(msg1);
      simulateWorkerMessage(msg2);

      expect(getStatus().bufferedCount).toBe(2);
    });

    it('replays buffered messages when subscriber arrives', () => {
      const msg1 = { type: 'message', data: '{"id": 1}' };
      const msg2 = { type: 'message', data: '{"id": 2}' };
      simulateWorkerMessage(msg1);
      simulateWorkerMessage(msg2);

      const callback = jest.fn();
      subscribe('message', callback);

      expect(callback).toHaveBeenCalledTimes(2);
      expect(callback).toHaveBeenNthCalledWith(1, msg1);
      expect(callback).toHaveBeenNthCalledWith(2, msg2);
    });

    it('replays buffer to each new subscriber without clearing it', () => {
      simulateWorkerMessage({ type: 'message', data: '{}' });

      const callback1 = jest.fn();
      subscribe('message', callback1);

      const callback2 = jest.fn();
      subscribe('message', callback2);

      expect(callback1).toHaveBeenCalledTimes(1);
      expect(callback2).toHaveBeenCalledTimes(1);
      expect(getStatus().bufferedCount).toBe(1);
    });

    it('buffers live messages received while subscribers are active', () => {
      const callback = jest.fn();
      subscribe('message', callback);

      const msg = { type: 'message', data: '{"live": true}' };
      simulateWorkerMessage(msg);

      expect(callback).toHaveBeenCalledWith(msg);
      expect(getStatus().bufferedCount).toBe(1);
    });

    it('buffers messages after last subscriber unsubscribes', () => {
      const callback = jest.fn();
      const subscription = subscribe('message', callback);
      subscription.dispose();

      simulateWorkerMessage({ type: 'message', data: '{"after": true}' });

      expect(callback).not.toHaveBeenCalled();
      expect(getStatus().bufferedCount).toBe(1);
    });

    it('does not clear buffer when replay callback throws', () => {
      const msg = { type: 'message', data: '{"id": 1}' };
      simulateWorkerMessage(msg);

      const error = new Error('subscriber error');
      const throwingCallback = jest.fn(() => {
        throw error;
      });

      expect(() => subscribe('message', throwingCallback)).not.toThrow();
      expect(throwingCallback).toHaveBeenCalledWith(msg);
      expect(getStatus().bufferedCount).toBe(1);
      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });

    it('caps buffer at 1000 messages', () => {
      for (let i = 0; i < 1050; i += 1) {
        simulateWorkerMessage({ type: 'message', data: `{"id": ${i}}` });
      }

      expect(getStatus().bufferedCount).toBe(1000);
    });

    it('does not buffer non-message events', () => {
      simulateWorkerMessage({ type: 'close', code: 1000 });
      simulateWorkerMessage({ type: 'error' });

      expect(getStatus().bufferedCount).toBe(0);
    });

    it('clears buffer on disconnect', () => {
      simulateWorkerMessage({ type: 'message', data: '{"id": 1}' });
      simulateWorkerMessage({ type: 'message', data: '{"id": 2}' });

      disconnect();

      expect(getStatus().bufferedCount).toBe(0);
    });
  });

  describe('error handling', () => {
    it('does not propagate errors thrown by a subscriber during live message delivery', () => {
      const throwingCallback = jest.fn(() => {
        throw new Error('subscriber error');
      });
      subscribe('message', throwingCallback);

      expect(() => simulateWorkerMessage({ type: 'message', data: '{}' })).not.toThrow();
    });

    it('captures exception when a subscriber throws during live message delivery', () => {
      const error = new Error('subscriber error');
      subscribe(
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
      subscribe(
        'message',
        jest.fn(() => {
          throw new Error('first subscriber error');
        }),
      );
      subscribe('message', healthyCallback);

      const payload = { type: 'message', data: '{}' };
      simulateWorkerMessage(payload);

      expect(healthyCallback).toHaveBeenCalledWith(payload);
    });

    it('captures exception when a subscriber throws for non-message events', () => {
      const error = new Error('open handler error');
      subscribe(
        'open',
        jest.fn(() => {
          throw error;
        }),
      );

      expect(() => simulateWorkerMessage({ type: 'open' })).not.toThrow();
      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });
  });

  describe('getStatus', () => {
    it('reports disconnected initially', () => {
      expect(getStatus().connected).toBe(false);
    });

    it('reports connected after open event', () => {
      simulateWorkerMessage({ type: 'open' });

      expect(getStatus().connected).toBe(true);
    });

    it('reports disconnected after close event', () => {
      simulateWorkerMessage({ type: 'open' });
      simulateWorkerMessage({ type: 'close', code: 1000 });

      expect(getStatus().connected).toBe(false);
    });
  });

  describe('toAbsoluteWebSocketUrl', () => {
    it('returns absolute ws:// URLs unchanged', () => {
      expect(toAbsoluteWebSocketUrl('ws://example.com/path')).toBe('ws://example.com/path');
    });

    it('returns absolute wss:// URLs unchanged', () => {
      expect(toAbsoluteWebSocketUrl('wss://example.com/path')).toBe('wss://example.com/path');
    });

    it('converts relative path to ws:// when page is http', () => {
      const result = toAbsoluteWebSocketUrl('/api/v4/ai/duo_workflows/ws?foo=bar');

      expect(result).toMatch(/^ws:\/\//);
      expect(result).toContain('/api/v4/ai/duo_workflows/ws?foo=bar');
    });

    it('converts relative path with query params preserving them', () => {
      const result = toAbsoluteWebSocketUrl('/api/ws?a=1&b=2');

      expect(result).toContain('a=1&b=2');
    });

    it('returns relative URL unchanged when window is undefined', () => {
      const originalWindow = global.window;
      delete global.window;

      try {
        expect(toAbsoluteWebSocketUrl('/api/ws')).toBe('/api/ws');
      } finally {
        global.window = originalWindow;
      }
    });
  });

  describe('connect URL conversion', () => {
    it('passes the converted absolute URL to the worker', () => {
      const relativeUrl = '/api/v4/ai/duo_workflows/ws';
      connect(relativeUrl, null);

      const connectCall = mockPostMessage.mock.calls.find(([msg]) => msg.type === 'connect');
      expect(connectCall[0].url).toMatch(/^ws(s)?:\/\//);
      expect(connectCall[0].url).toContain('/api/v4/ai/duo_workflows/ws');
    });
  });

  describe('terminate', () => {
    it('terminates the worker', () => {
      terminate();

      expect(mockTerminate).toHaveBeenCalled();
    });

    it('resets connection status', () => {
      simulateWorkerMessage({ type: 'open' });
      terminate();

      expect(getStatus().connected).toBe(false);
    });

    it('clears message buffer', () => {
      simulateWorkerMessage({ type: 'message', data: '{}' });
      terminate();

      expect(getStatus().bufferedCount).toBe(0);
    });

    it('clears subscribers', () => {
      const callback = jest.fn();
      subscribe('message', callback);
      terminate();

      connect(TEST_URL, TEST_INITIAL_MESSAGE);
      {
        const [, handler] = mockAddEventListener.mock.calls.find(([event]) => event === 'message');
        workerMessageHandler = handler;
      }

      simulateWorkerMessage({ type: 'message', data: '{}' });

      expect(callback).not.toHaveBeenCalled();
    });

    it('sends disconnect before terminating', () => {
      terminate();

      const disconnectCall = mockPostMessage.mock.calls.find(([msg]) => msg.type === 'disconnect');
      expect(disconnectCall).toHaveLength(1);
    });
  });

  describe('buffer replay and close event ordering', () => {
    it('delivers buffered messages before a close event is processed', () => {
      const events = [];

      simulateWorkerMessage({ type: 'message', data: '{"id": 1}' });
      simulateWorkerMessage({ type: 'message', data: '{"id": 2}' });

      subscribe('message', (msg) => events.push({ type: 'message', data: msg.data }));
      subscribe('close', (msg) => events.push({ type: 'close', code: msg.code }));

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

      subscribe('message', first);
      subscribe('message', second);

      expect(first).toHaveBeenCalledTimes(1);
      expect(first).toHaveBeenCalledWith(msg);
      expect(second).toHaveBeenCalledTimes(1);
      expect(second).toHaveBeenCalledWith(msg);
    });
  });

  // NODE_ENV is `test` here, so the global is exposed. It is absent in production builds.
  describe('gl.dwsMockSocket', () => {
    it('is exposed once a worker exists', () => {
      expect(window.gl.dwsMockSocket).toEqual({
        close: expect.any(Function),
        error: expect.any(Function),
        message: expect.any(Function),
        open: expect.any(Function),
      });
    });

    it.each`
      description                 | call                                                      | expected
      ${'close with a code'}      | ${() => window.gl.dwsMockSocket.close(1013, 'try later')} | ${{ type: 'mockEvent', event: 'close', payload: { code: 1013, reason: 'try later' } }}
      ${'close with defaults'}    | ${() => window.gl.dwsMockSocket.close()}                  | ${{ type: 'mockEvent', event: 'close', payload: { code: 1006, reason: '' } }}
      ${'error'}                  | ${() => window.gl.dwsMockSocket.error()}                  | ${{ type: 'mockEvent', event: 'error', payload: undefined }}
      ${'open'}                   | ${() => window.gl.dwsMockSocket.open()}                   | ${{ type: 'mockEvent', event: 'open', payload: undefined }}
      ${'message with a payload'} | ${() => window.gl.dwsMockSocket.message('{"a":1}')}       | ${{ type: 'mockEvent', event: 'message', payload: { data: '{"a":1}' } }}
    `('posts a mockEvent to the worker for $description', ({ call, expected }) => {
      mockPostMessage.mockClear();

      call();

      expect(mockPostMessage).toHaveBeenCalledWith(expected);
    });

    it('does not throw once the worker has been terminated', () => {
      terminate();

      expect(() => window.gl.dwsMockSocket.close(1001)).not.toThrow();
    });
  });
});
