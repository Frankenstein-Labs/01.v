import { RetryableWorkflowStream } from 'ee/ai/duo_agentic_chat/websocket/retryable_workflow_stream';
import { BufferedEventHub } from 'ee/ai/duo_agentic_chat/websocket/buffered_event_hub';
import { WORKFLOW_STREAM_STATES } from 'ee/ai/duo_agentic_chat/websocket/workflow_stream';
import {
  RECONNECT_TRIGGERS,
  logStreamReconnect,
  reportStreamClose,
} from 'ee/ai/duo_agentic_chat/observability/stream_close_reporting';

// Partial, so RECONNECT_TRIGGERS stays real: the decorator reads it, and a mocked
// constant would make every assertion here agree with itself and nothing else.
jest.mock('ee/ai/duo_agentic_chat/observability/stream_close_reporting', () => ({
  ...jest.requireActual('ee/ai/duo_agentic_chat/observability/stream_close_reporting'),
  logStreamReconnect: jest.fn(),
  reportStreamClose: jest.fn(),
}));

const RETRYABLE_CLOSE = {
  type: 'close',
  code: 1001,
  category: 'going_away',
  retryable: true,
  expected: true,
};

/**
 * Stands in for a WorkflowStream, matching it on the three things this decorator
 * relies on: closes arrive through `interceptClose` rather than the hub, the hub
 * is cleared before the handler runs, and `terminate()` disposes the hub.
 *
 * That last one matters: disposing drops every subscription made on the hub,
 * including the decorator's own. A `terminate: jest.fn()` that left the hub
 * intact would let a decorator that never re-subscribes still pass.
 */
function makeInner() {
  const hub = new BufferedEventHub(['message']);
  let closeHandler = null;

  return {
    url: 'ws://localhost/test',
    initialMessage: { startRequest: { workflowID: '123' } },
    state: WORKFLOW_STREAM_STATES.ERROR,
    hub,
    interceptClose: (handler) => {
      closeHandler = handler;
    },
    subscribe: (eventType, callback) => hub.subscribe(eventType, callback),
    emit(eventType, payload) {
      if (eventType !== 'close') {
        hub.$emit(eventType, payload);
        return;
      }
      hub.clear();
      closeHandler(payload);
    },
    connect: jest.fn(),
    send: jest.fn(),
    disconnect: jest.fn(),
    terminate: jest.fn(() => hub.dispose()),
    getStatus: jest.fn().mockReturnValue({ connected: false, state: 'idle', bufferedCount: 0 }),
  };
}

describe('RetryableWorkflowStream', () => {
  let inner;
  let stream;

  beforeEach(() => {
    // Delays are jittered, so pin the randomness to its ceiling and let the
    // jitter itself be asserted on its own below.
    jest.spyOn(Math, 'random').mockReturnValue(1);
    logStreamReconnect.mockClear();
    reportStreamClose.mockClear();

    inner = makeInner();
    stream = new RetryableWorkflowStream(inner);
  });

  afterEach(() => {
    // Restored here rather than at the end of each test, so a failing
    // expectation cannot leak fake timers into the rest of the file.
    jest.useRealTimers();
  });

  describe('event forwarding', () => {
    it.each(['open', 'message', 'error'])('delivers %s events to subscribers', (eventType) => {
      const callback = jest.fn();
      stream.subscribe(eventType, callback);
      const event = { type: eventType };

      inner.emit(eventType, event);

      expect(callback).toHaveBeenCalledWith(event);
    });
  });

  describe('non-retryable close forwarding', () => {
    it.each([
      ['normal', 1000],
      ['policy_violation', 1008],
      ['try_again_later', 1013],
    ])('forwards a %s close without retrying', (category, code) => {
      jest.useFakeTimers();
      const callback = jest.fn();
      stream.subscribe('close', callback);
      const event = { type: 'close', code, category, retryable: false };

      inner.emit('close', event);

      expect(callback).toHaveBeenCalledWith(event);
      jest.runAllTimers();
      expect(inner.connect).not.toHaveBeenCalled();
    });
  });

  describe('retryable close handling (unlimited retries)', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    it('schedules reconnect and does NOT forward close to outer subscribers', () => {
      const callback = jest.fn();
      stream.subscribe('close', callback);

      inner.emit('close', RETRYABLE_CLOSE);

      expect(callback).not.toHaveBeenCalled();
      jest.runAllTimers();
      expect(inner.connect).toHaveBeenCalledWith(inner.url, {
        startRequest: { workflowID: '123', goal: '' },
      });
    });

    it('reconnects with an empty goal so the executor treats it as a resume', () => {
      inner.url = 'ws://reconnect-host/api/v4/ws';
      inner.initialMessage = {
        startRequest: { workflowID: 'abc', goal: 'create a merge request' },
      };

      inner.emit('close', { type: 'close', code: 9999, category: 'error', retryable: true });

      jest.runAllTimers();
      expect(inner.connect).toHaveBeenCalledWith('ws://reconnect-host/api/v4/ws', {
        startRequest: { workflowID: 'abc', goal: '' },
      });
    });

    it('respects the retryDelay option', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { retryDelay: 500 });
      target.emit('close', RETRYABLE_CLOSE);

      jest.advanceTimersByTime(499);
      expect(target.connect).not.toHaveBeenCalled();

      jest.advanceTimersByTime(1);
      expect(target.connect).toHaveBeenCalled();
    });

    // Reconnecting at exactly the same moment as every other client dropped by
    // the same server restart would hand it back the same stampede.
    it('jitters the delay', () => {
      Math.random.mockReturnValue(0);
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { retryDelay: 1000 });

      target.emit('close', RETRYABLE_CLOSE);

      jest.advanceTimersByTime(499);
      expect(target.connect).not.toHaveBeenCalled();

      jest.advanceTimersByTime(1);
      expect(target.connect).toHaveBeenCalled();
    });

    it('backs off exponentially across consecutive failures', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { retryDelay: 1000 });

      target.emit('close', RETRYABLE_CLOSE);
      jest.advanceTimersByTime(1000);
      expect(target.connect).toHaveBeenCalledTimes(1);

      target.emit('close', RETRYABLE_CLOSE);
      jest.advanceTimersByTime(1000);
      expect(target.connect).toHaveBeenCalledTimes(1);

      jest.advanceTimersByTime(1000);
      expect(target.connect).toHaveBeenCalledTimes(2);
    });
  });

  describe('maxRetries', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    it('emits error and stops retrying after maxRetries consecutive retryable closes', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 2 });
      const errorCallback = jest.fn();
      stream.subscribe('error', errorCallback);

      target.emit('close', RETRYABLE_CLOSE); // count=1
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE); // count=2
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE); // at the limit → error

      expect(errorCallback).toHaveBeenCalledWith({
        type: 'error',
        reason: 'max_retries_exceeded',
      });
      expect(target.connect).toHaveBeenCalledTimes(2);
    });

    it('resets the retry count when a message is received', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 2 });
      const errorCallback = jest.fn();
      stream.subscribe('error', errorCallback);

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      target.emit('message', { type: 'message', data: '{}' });

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      expect(errorCallback).not.toHaveBeenCalled();
      expect(target.connect).toHaveBeenCalledTimes(4);
    });

    // terminate() disposes the inner hub, which drops the subscription this
    // reset depends on. The decorator is a long-lived singleton, so a chat
    // session that tears down and starts again reuses the same instance.
    it('resets the retry count when a message is received after terminate() and reconnect', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 2 });
      const errorCallback = jest.fn();
      stream.subscribe('error', errorCallback);

      stream.terminate();
      stream.connect('ws://localhost/test', { startRequest: { workflowID: '123' } });
      stream.subscribe('error', errorCallback);

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      target.emit('message', { type: 'message', data: '{}' });

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      expect(errorCallback).not.toHaveBeenCalled();
    });

    it('resets the retry count on connect()', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 1 });
      const errorCallback = jest.fn();
      stream.subscribe('error', errorCallback);

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      stream.connect('ws://again', { startRequest: { workflowID: '123' } });

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      expect(errorCallback).not.toHaveBeenCalled();
    });
  });

  describe('retry()', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    // The backoff and jitter spread a fleet reconnecting in unison; a person
    // pressing a button is already spread out, and waiting up to a second would
    // just make the button look broken.
    it('reconnects immediately rather than scheduling', () => {
      stream.retry();

      expect(inner.connect).toHaveBeenCalledWith(inner.url, {
        startRequest: { workflowID: '123', goal: '' },
      });
    });

    it('clears the exhausted retry count, so automatic retries resume', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 1 });
      const errorCallback = jest.fn();
      stream.subscribe('error', errorCallback);

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE);
      expect(errorCallback).toHaveBeenCalledTimes(1);

      stream.retry();
      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();

      expect(target.connect).toHaveBeenCalledTimes(3);
      expect(errorCallback).toHaveBeenCalledTimes(1);
    });

    it('drops a reconnect that was already pending', () => {
      inner.emit('close', RETRYABLE_CLOSE);

      stream.retry();
      jest.runAllTimers();

      expect(inner.connect).toHaveBeenCalledTimes(1);
    });

    it('logs the reconnect, including the failures that led to it', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 3 });
      target.emit('close', RETRYABLE_CLOSE);
      logStreamReconnect.mockClear();

      stream.retry();

      expect(logStreamReconnect).toHaveBeenCalledWith({
        trigger: RECONNECT_TRIGGERS.REQUESTED,
        consecutiveFailures: 1,
        maxRetries: 3,
        delay: 0,
      });
    });

    // Reconnecting one would drop a working socket to replace it with an
    // identical one, losing whatever was in flight.
    it.each([WORKFLOW_STREAM_STATES.CONNECTING, WORKFLOW_STREAM_STATES.OPENED])(
      'does nothing while the stream is %s',
      (state) => {
        inner.state = state;

        stream.retry();

        expect(inner.connect).not.toHaveBeenCalled();
      },
    );

    // IDLE is both "never connected" and "terminated": one has no url to resume,
    // and the other was deliberately shut down.
    it('does nothing while the stream is idle', () => {
      inner.state = WORKFLOW_STREAM_STATES.IDLE;

      stream.retry();

      expect(inner.connect).not.toHaveBeenCalled();
    });

    it('does nothing before the stream has ever connected', () => {
      const target = makeInner();
      target.url = null;
      stream = new RetryableWorkflowStream(target);

      expect(() => {
        stream.retry();
        jest.runAllTimers();
      }).not.toThrow();
      expect(target.connect).not.toHaveBeenCalled();
    });
  });

  // A pending reconnect outlives whatever scheduled it, so without cancellation
  // the stream reconnects moments after being torn down, leaving a worker and
  // socket that nobody owns.
  describe('cancelling a pending reconnect', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      inner.emit('close', RETRYABLE_CLOSE);
    });

    it.each(['disconnect', 'terminate'])('does not reconnect after %s()', (method) => {
      stream[method]();

      jest.runAllTimers();

      expect(inner.connect).not.toHaveBeenCalled();
    });

    it('does not stack reconnects when closes arrive faster than the delay', () => {
      inner.emit('close', RETRYABLE_CLOSE);
      inner.emit('close', RETRYABLE_CLOSE);

      jest.runAllTimers();

      expect(inner.connect).toHaveBeenCalledTimes(1);
    });
  });

  describe('observability', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    // A reconnect that works is not an incident, so Sentry hears nothing until
    // recovery itself fails.
    it('does not report a close it is about to retry', () => {
      inner.emit('close', RETRYABLE_CLOSE);

      expect(reportStreamClose).not.toHaveBeenCalled();
    });

    it('logs each reconnect with the attempt and the delay', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { retryDelay: 1000, maxRetries: 3 });

      target.emit('close', RETRYABLE_CLOSE);

      expect(logStreamReconnect).toHaveBeenCalledWith({
        trigger: RECONNECT_TRIGGERS.RETRYABLE_CLOSE,
        consecutiveFailures: 1,
        maxRetries: 3,
        delay: 1000,
      });
    });

    it('reports a close it will not retry', () => {
      const event = { type: 'close', code: 4400, category: 'invalid_request', expected: false };

      inner.emit('close', event);

      expect(reportStreamClose).toHaveBeenCalledWith(event);
    });

    it('reports the close that exhausted the retries', () => {
      const target = makeInner();
      stream = new RetryableWorkflowStream(target, { maxRetries: 1 });

      target.emit('close', RETRYABLE_CLOSE);
      jest.runAllTimers();
      target.emit('close', RETRYABLE_CLOSE);

      expect(reportStreamClose).toHaveBeenCalledTimes(1);
      expect(reportStreamClose).toHaveBeenCalledWith(RETRYABLE_CLOSE, {
        retriesExhausted: true,
      });
    });
  });

  describe('message buffering', () => {
    it('replays the inner stream buffer to a later subscriber', () => {
      const msg1 = { type: 'message', data: '{"id": 1}' };
      const msg2 = { type: 'message', data: '{"id": 2}' };
      inner.emit('message', msg1);
      inner.emit('message', msg2);

      const callback = jest.fn();
      stream.subscribe('message', callback);

      expect(callback).toHaveBeenCalledTimes(2);
      expect(callback).toHaveBeenNthCalledWith(1, msg1);
      expect(callback).toHaveBeenNthCalledWith(2, msg2);
    });

    it('returns a disposable subscription', () => {
      const callback = jest.fn();
      const sub = stream.subscribe('message', callback);
      sub.dispose();

      inner.emit('message', { type: 'message', data: '{}' });

      expect(callback).not.toHaveBeenCalled();
    });
  });

  describe('delegation', () => {
    it('reports the inner status as-is', () => {
      const status = { connected: true, state: 'opened', bufferedCount: 5 };
      inner.getStatus.mockReturnValue(status);

      expect(stream.getStatus()).toEqual(status);
    });

    it('delegates connect() to inner', () => {
      stream.connect('ws://foo', { req: true });

      expect(inner.connect).toHaveBeenCalledWith('ws://foo', { req: true });
    });

    it('delegates send() to inner', () => {
      stream.send({ approval: true });

      expect(inner.send).toHaveBeenCalledWith({ approval: true });
    });

    it('delegates disconnect() to inner', () => {
      stream.disconnect();

      expect(inner.disconnect).toHaveBeenCalled();
    });

    it('delegates terminate() to inner', () => {
      stream.terminate();

      expect(inner.terminate).toHaveBeenCalled();
    });
  });
});
