import {
  RECONNECT_TRIGGERS,
  logStreamReconnect,
  reportStreamClose,
} from '../observability/stream_close_reporting';
import { WORKFLOW_STREAM_STATES } from './workflow_stream';

// A stream that has connected and then stopped is the only one with anything to
// recover. IDLE covers both never-connected and terminated; CONNECTING and OPENED
// are already on their way or there.
const RECOVERABLE_STATES = [WORKFLOW_STREAM_STATES.CLOSED, WORKFLOW_STREAM_STATES.ERROR];

/**
 * Decorator that wraps a WorkflowStream and automatically reconnects when a
 * retryable close event is received (e.g. server restart / going-away).
 *
 * It takes over the inner stream's close handling rather than subscribing to it:
 * a retryable close must not reach subscribers, and a subscriber cannot prevent
 * that because by the time it runs every other subscriber has seen the event too.
 * Everything else -- open, message, error, buffering, replay -- stays on the
 * inner stream's own hub, so there is one buffer and one event channel.
 *
 * When `maxRetries` consecutive retryable closes occur without a message being
 * received in between, an `error` event is emitted instead of reconnecting.
 * The retry count resets each time a message is received.
 *
 * Taking over the close also means taking over what gets reported: a retryable
 * close that is about to be retried is not worth Sentry's attention, and the
 * same close is, once retrying has failed.
 */
export class RetryableWorkflowStream {
  #inner;
  #retryDelay;
  #maxRetries;
  #retryCount = 0;
  #reconnectTimer = null;
  #messageSubscription = null;

  constructor(inner, { retryDelay = 0, maxRetries = Infinity } = {}) {
    this.#inner = inner;
    this.#retryDelay = retryDelay;
    this.#maxRetries = maxRetries;

    this.#wireToInner();
  }

  connect(url, initialMessage) {
    this.#cancelReconnect();
    this.#retryCount = 0;
    this.#wireToInner();
    this.#inner.connect(url, initialMessage);
  }

  send(message) {
    this.#inner.send(message);
  }

  disconnect() {
    this.#cancelReconnect();
    this.#inner.disconnect();
  }

  subscribe(eventType, callback) {
    return this.#inner.subscribe(eventType, callback);
  }

  getStatus() {
    return this.#inner.getStatus();
  }

  terminate() {
    this.#cancelReconnect();
    this.#inner.terminate();
  }

  /**
   * Reconnects on demand, e.g. after `max_retries_exceeded` was reported.
   *
   * Immediate, unlike an automatic retry: the backoff and jitter exist to spread
   * a fleet of clients reconnecting in unison, and one person pressing a button
   * is already spread out. Waiting would just make the button look broken.
   */
  retry() {
    // Ignored rather than thrown -- the caller is typically a button. Nothing to
    // resume without a url, and reconnecting a live stream would drop a working
    // socket to replace it with an identical one.
    if (!this.#inner.url || !RECOVERABLE_STATES.includes(this.#inner.state)) return;

    this.#cancelReconnect();
    logStreamReconnect({
      trigger: RECONNECT_TRIGGERS.REQUESTED,
      consecutiveFailures: this.#retryCount,
      maxRetries: this.#maxRetries,
      delay: 0,
    });

    this.#retryCount = 0;
    this.#inner.connect(this.#inner.url, this.#buildResumeMessage());
  }

  #wireToInner() {
    this.#inner.interceptClose((event) => this.#onInnerClose(event));

    this.#messageSubscription?.dispose();
    this.#messageSubscription = this.#inner.subscribe('message', () => {
      this.#retryCount = 0;
    });
  }

  #onInnerClose(event) {
    if (!event.retryable) {
      reportStreamClose(event);
      this.#inner.hub.$emit('close', event);
      return;
    }

    if (this.#retryCount >= this.#maxRetries) {
      // Reported whatever the code: recovery is what made this close ignorable,
      // and there is none left.
      reportStreamClose(event, { retriesExhausted: true });
      this.#inner.hub.$emit('error', { type: 'error', reason: 'max_retries_exceeded' });
      return;
    }

    this.#retryCount += 1;
    this.#scheduleReconnect();
  }

  #scheduleReconnect() {
    this.#cancelReconnect();

    const delay = this.#nextDelay();
    logStreamReconnect({
      trigger: RECONNECT_TRIGGERS.RETRYABLE_CLOSE,
      consecutiveFailures: this.#retryCount,
      maxRetries: this.#maxRetries,
      delay,
    });

    this.#reconnectTimer = setTimeout(() => {
      this.#reconnectTimer = null;
      this.#inner.connect(this.#inner.url, this.#buildResumeMessage());
    }, delay);
  }

  // A pending reconnect outlives whatever scheduled it, so disconnect() and
  // terminate() have to cancel it. Otherwise the stream resurrects itself a
  // moment after being torn down, with a worker and socket nobody owns.
  #cancelReconnect() {
    if (this.#reconnectTimer !== null) {
      clearTimeout(this.#reconnectTimer);
      this.#reconnectTimer = null;
    }
  }

  // Exponential, and jittered so that a fleet of clients dropped by one server
  // restart spreads its reconnects out instead of arriving in lockstep.
  #nextDelay() {
    // Only reached from a close that was counted, so the first attempt is 1.
    const ceiling = this.#retryDelay * 2 ** (this.#retryCount - 1);
    return Math.round(ceiling * (0.5 + Math.random() * 0.5));
  }

  // Reconnects must send an empty goal so the workflow executor treats the
  // connection as a resume rather than a new request. A non-empty goal on an
  // already-running workflow would be interpreted as new user input.
  #buildResumeMessage() {
    const msg = this.#inner.initialMessage;
    if (!msg?.startRequest) return msg;
    return { ...msg, startRequest: { ...msg.startRequest, goal: '' } };
  }
}
