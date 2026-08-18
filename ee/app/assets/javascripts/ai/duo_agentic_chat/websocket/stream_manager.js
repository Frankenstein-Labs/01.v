import { captureExceptionForDuoChat } from '../observability/sentry_utils';
import { DWS_MOCK_WEBSOCKET_ENABLED, exposeMockSocket } from './dws_mock_websocket';
import StreamWorker from './stream_worker?worker';

const MAX_BUFFER_SIZE = 1000;
const STALL_THRESHOLD_MS = 5000;
const ERROR_ESCALATION_INTERVAL_MS = 10000;

let worker = null;
let connected = false;
const subscribers = new Map();
let messageBuffer = [];
let lastMessageAt = null;
let lastErrorEscalatedAt = null;

function broadcastMessages(callbacks, message) {
  for (const cb of callbacks) {
    try {
      cb(message);
    } catch (e) {
      captureExceptionForDuoChat(e);
    }
  }
}

function notify(eventType, payload) {
  const callbacks = subscribers.get(eventType);
  if (callbacks) {
    broadcastMessages(callbacks, payload);
  }
}

function onWorkerMessage({ data }) {
  switch (data.type) {
    case 'open':
      connected = true;
      notify('open', data);
      break;
    case 'message': {
      lastMessageAt = Date.now();
      if (messageBuffer.length < MAX_BUFFER_SIZE) {
        messageBuffer.push(data);
      }
      notify('message', data);
      break;
    }
    case 'close':
      connected = false;
      notify('close', data);
      break;
    case 'error': {
      const now = Date.now();
      const isStalled = lastMessageAt === null || now - lastMessageAt > STALL_THRESHOLD_MS;
      const canEscalate =
        lastErrorEscalatedAt === null || now - lastErrorEscalatedAt > ERROR_ESCALATION_INTERVAL_MS;

      if (!isStalled || !canEscalate) {
        break;
      }

      lastErrorEscalatedAt = now;
      captureExceptionForDuoChat(
        new Error(`Duo Chat WebSocket error (${data.origin ?? 'unknown'})`),
        {
          extra: data,
          tags: { origin: data.origin ?? 'unknown' },
        },
      );
      notify('error', data);
      break;
    }
    default:
      break;
  }
}

function ensureWorker() {
  if (!worker) {
    worker = new StreamWorker();
    worker.addEventListener('message', onWorkerMessage);

    if (DWS_MOCK_WEBSOCKET_ENABLED) {
      exposeMockSocket(() => worker);
    }
  }
  return worker;
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

export function connect(url, initialMessage) {
  const absoluteUrl = toAbsoluteWebSocketUrl(url);
  messageBuffer = [];
  lastMessageAt = null;
  lastErrorEscalatedAt = null;
  ensureWorker();
  worker.postMessage({ type: 'connect', url: absoluteUrl, initialMessage });
}

export function send(message) {
  if (worker) {
    worker.postMessage({ type: 'send', message });
  }
}

export function disconnect() {
  if (worker) {
    worker.postMessage({ type: 'disconnect' });
    messageBuffer = [];
    lastMessageAt = null;
    lastErrorEscalatedAt = null;
  }
}

export function subscribe(eventType, callback) {
  if (!subscribers.has(eventType)) {
    subscribers.set(eventType, new Set());
  }
  subscribers.get(eventType).add(callback);

  if (eventType === 'message' && messageBuffer.length > 0) {
    for (const msg of messageBuffer) {
      broadcastMessages([callback], msg);
    }
  }

  return {
    dispose() {
      const set = subscribers.get(eventType);
      if (set) {
        set.delete(callback);
        if (set.size === 0) {
          subscribers.delete(eventType);
        }
      }
    },
  };
}

export function getStatus() {
  return { connected, bufferedCount: messageBuffer.length };
}

export function terminate() {
  if (worker) {
    worker.postMessage({ type: 'disconnect' });
    worker.removeEventListener('message', onWorkerMessage);
    worker.terminate();
    worker = null;
  }
  connected = false;
  messageBuffer = [];
  lastMessageAt = null;
  lastErrorEscalatedAt = null;
  subscribers.clear();
}
