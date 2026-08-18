import {
  WS_CLOSE_GOING_AWAY,
  WS_CLOSE_INVALID_REQUEST,
  WS_CLOSE_NORMAL,
  WS_CLOSE_POLICY_VIOLATION,
  WS_CLOSE_TRY_AGAIN_LATER,
} from '../constants';
import { logStreamClose, reportStreamClose } from '../observability/stream_close_reporting';
import StreamWorker from './stream_worker?worker';
import { BufferedEventHub } from './buffered_event_hub';
import { BufferOverflowError } from './buffer_overflow_error';
import { DWS_MOCK_WEBSOCKET_ENABLED, exposeMockSocket } from './dws_mock_websocket';

export const WORKFLOW_STREAM_STATES = Object.freeze({
  IDLE: 'idle',
  CONNECTING: 'connecting',
  OPENED: 'opened',
  CLOSED: 'closed',
  ERROR: 'error',
});

// Maps WebSocket close codes to categorised close descriptors.
//
// `expected` marks a close as an outcome rather than a fault, which is what keeps
// it out of Sentry; see reportStreamClose. Codes absent from the map are treated
// as transient errors: retryable, and not expected, because a code we do not
// recognise is worth hearing about once retrying has failed.
const CLOSE_CODE_CATEGORIES = new Map([
  [WS_CLOSE_NORMAL, { category: 'normal', retryable: false, expected: true }],
  // The server is restarting, which is routine; reconnecting is the whole answer.
  [WS_CLOSE_GOING_AWAY, { category: 'going_away', retryable: true, expected: true }],
  // The user is out of credits or billing is blocked -- a state, not a defect.
  [WS_CLOSE_POLICY_VIOLATION, { category: 'policy_violation', retryable: false, expected: true }],
  // Another tab is already streaming this workflow, so retrying would fight it.
  [WS_CLOSE_TRY_AGAIN_LATER, { category: 'try_again_later', retryable: false, expected: true }],
  // The backend rejected what we sent it, so the request itself is wrong.
  [WS_CLOSE_INVALID_REQUEST, { category: 'invalid_request', retryable: false, expected: false }],
]);

function categorizeCloseCode(code) {
  return CLOSE_CODE_CATEGORIES.get(code) ?? { category: 'error', retryable: true, expected: false };
}

export function toAbsoluteWebSocketUrl(relativeUrl) {
  if (relativeUrl.startsWith('ws://') || relativeUrl.startsWith('wss://')) {
    return relativeUrl;
  }
  if (typeof window === 'undefined') {
    return relativeUrl;
  }
  const url = new URL(relativeUrl, window.location.href);
  // eslint-disable-next-line @gitlab/require-i18n-strings
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  return url.href;
}

export class WorkflowStream {
  #state = WORKFLOW_STREAM_STATES.IDLE;
  #url = null;
  #initialMessage = null;
  #worker = null;
  #hub = new BufferedEventHub(['message']);
  #workflowStatus = null;
  #closeHandler = null;

  // Arrow function field so it can be passed to addEventListener without binding.
  #handleWorkerMessage = ({ data }) => {
    switch (data.type) {
      case 'open':
        this.#state = WORKFLOW_STREAM_STATES.OPENED;
        this.#hub.$emit('open', data);
        break;
      case 'message': {
        const status = data.data?.newCheckpoint?.status;
        if (status !== undefined) {
          this.#workflowStatus = status;
        }
        this.#emitMessage(data);
        break;
      }
      case 'close':
        this.#handleClose(data);
        break;
      case 'error':
        this.#hub.$emit('error', data);
        break;
      default:
        break;
    }
  };

  get state() {
    return this.#state;
  }

  get url() {
    return this.#url;
  }

  get initialMessage() {
    return this.#initialMessage;
  }

  get workflowStatus() {
    return this.#workflowStatus;
  }

  get hub() {
    return this.#hub;
  }

  /**
   * Hands close handling to a collaborator, which then decides whether the close
   * reaches subscribers at all -- that decision cannot be made by a subscriber,
   * because by then every other subscriber has seen it too.
   *
   * Only one handler: this transfers a responsibility rather than observing one.
   * Without a handler the stream emits its own closes as usual.
   */
  interceptClose(handler) {
    this.#closeHandler = handler;
  }

  connect(url, initialMessage) {
    this.#url = toAbsoluteWebSocketUrl(url);
    this.#initialMessage = initialMessage;
    this.#hub.clear();
    this.#workflowStatus = null;
    this.#state = WORKFLOW_STREAM_STATES.CONNECTING;

    this.#ensureWorker();
    this.#worker.postMessage({ type: 'connect', url: this.#url, initialMessage });
  }

  send(message) {
    if (this.#worker) {
      this.#worker.postMessage({ type: 'send', message });
    }
  }

  disconnect() {
    if (this.#worker) {
      this.#worker.postMessage({ type: 'disconnect' });
    }
    // `stream_worker` drops its socket reference before the socket's own close
    // event fires, and its `socket === ws` guard then suppresses that event, so
    // nothing will report this close back to us. Record it here or the stream
    // keeps claiming to be open with no socket behind it.
    this.#state = WORKFLOW_STREAM_STATES.CLOSED;
    this.#hub.clear();
  }

  subscribe(eventType, callback) {
    return this.#hub.subscribe(eventType, callback);
  }

  getStatus() {
    return {
      connected: this.#state === WORKFLOW_STREAM_STATES.OPENED,
      state: this.#state,
      bufferedCount: this.#hub.count,
      workflowStatus: this.#workflowStatus,
    };
  }

  terminate() {
    if (this.#worker) {
      this.#worker.postMessage({ type: 'disconnect' });
      this.#worker.removeEventListener('message', this.#handleWorkerMessage);
      this.#worker.terminate();
      this.#worker = null;
    }
    this.#state = WORKFLOW_STREAM_STATES.IDLE;
    this.#workflowStatus = null;
    this.#hub.dispose();
  }

  // A full buffer means the backlog outgrew the connection it was meant to
  // replay, so the oldest events are the ones worth losing. Drop them and emit
  // again: the buffer is empty by then, so the retry cannot overflow, and the
  // message that triggered this is both buffered and delivered as normal.
  #emitMessage(data) {
    try {
      this.#hub.$emit('message', data);
    } catch (e) {
      if (!(e instanceof BufferOverflowError)) {
        throw e;
      }
      this.#hub.clear();
      this.#hub.$emit('message', data);
    }
  }

  #ensureWorker() {
    if (!this.#worker) {
      this.#worker = new StreamWorker();
      this.#worker.addEventListener('message', this.#handleWorkerMessage);

      if (DWS_MOCK_WEBSOCKET_ENABLED) {
        exposeMockSocket(() => this.#worker);
      }
    }
  }

  #handleClose(data) {
    const descriptor = categorizeCloseCode(data.code);
    this.#state = descriptor.retryable
      ? WORKFLOW_STREAM_STATES.ERROR
      : WORKFLOW_STREAM_STATES.CLOSED;
    // The buffer only exists to replay the current connection, so it is stale
    // the moment that connection ends. Bounding its lifetime this way is also
    // what keeps it from ever reaching the overflow limit in practice.
    this.#hub.clear();

    const event = { ...data, ...descriptor };

    logStreamClose(event);

    if (this.#closeHandler) {
      this.#closeHandler(event);
      return;
    }

    reportStreamClose(event);
    this.#hub.$emit('close', event);
  }
}
