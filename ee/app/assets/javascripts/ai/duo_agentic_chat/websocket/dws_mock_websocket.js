/**
 * A transparent wrapper around `WebSocket` for local development and tests.
 *
 * It behaves exactly like the socket it wraps, so Duo Chat still talks to a real
 * Duo Workflow Service. On top of that it can synthesise `open`, `message`, `close`
 * and `error` events on demand, which lets connection-error handling be exercised
 * against close codes a real backend will not produce (1006, 1008, 1013, ...).
 *
 * Only used when DWS_MOCK_WEBSOCKET_ENABLED; see stream_worker.js. Drive it from the browser console
 * through `gl.dwsMockSocket`; see exposeMockSocket below.
 */
export const DWS_MOCK_WEBSOCKET_ENABLED =
  process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test';

export class DwsMockWebSocket {
  #socket;

  constructor(url) {
    this.#socket = new WebSocket(url);

    this.#socket.onopen = (event) => this.onopen?.(event);
    this.#socket.onmessage = (event) => this.onmessage?.(event);
    this.#socket.onclose = (event) => this.onclose?.(event);
    this.#socket.onerror = (event) => this.onerror?.(event);
  }

  get readyState() {
    return this.#socket.readyState;
  }

  // Forwarded with rest args rather than named ones so the wrapped socket is called
  // with exactly the arguments it was given, not padded with `undefined`.
  send(...args) {
    this.#socket.send(...args);
  }

  close(...args) {
    this.#socket.close(...args);
  }

  /**
   * Invokes one of the `on*` handlers as though the server had produced the event.
   *
   * A synthesised `close` also tears down the wrapped socket, otherwise the client
   * would reconnect while the old connection is still open and the real `close`
   * would arrive later as a second, unexpected event.
   */
  dispatchMockEvent(event, payload = {}) {
    switch (event) {
      case 'open':
        this.onopen?.({});
        break;
      case 'message':
        if (!payload?.data) {
          throw new Error(
            // eslint-disable-next-line @gitlab/require-i18n-strings
            'You should provide a message payload. The websocket message event listener will not be emitted.',
          );
        }
        this.onmessage?.({ data: payload.data });
        break;
      case 'error':
        this.onerror?.({});
        break;
      case 'close':
        this.#detachAndClose();
        this.onclose?.({ code: payload.code ?? 1006, reason: payload.reason ?? '' });
        break;
      default:
        break;
    }
  }

  #detachAndClose() {
    this.#socket.onopen = null;
    this.#socket.onmessage = null;
    this.#socket.onclose = null;
    this.#socket.onerror = null;
    this.#socket.close();
  }
}

/**
 * Exposes `gl.dwsMockSocket` in development and test builds, so connection failures
 * can be reproduced from the browser console against a live backend:
 *
 *   gl.dwsMockSocket.close(1001)   // retryable, expect a silent reconnect
 *   gl.dwsMockSocket.close(1013)   // non-retryable, expect the stream to stop
 *   gl.dwsMockSocket.error()
 *   gl.dwsMockSocket.message('{"newCheckpoint":{}}')
 *
 * The worker forwards these to DwsMockWebSocket, which invokes the corresponding handler
 * as though the server had produced the event.
 *
 * Each caller overwrites `gl.dwsMockSocket`, so while stream_manager and WorkflowStream
 * both exist it drives whichever of them created a worker last. Nothing to fix until
 * stream_manager is retired -- but worth knowing before concluding a close was ignored.
 */
export function exposeMockSocket(getWorker) {
  const emit = (event, payload) => getWorker()?.postMessage({ type: 'mockEvent', event, payload });

  window.gl = window.gl || {};
  window.gl.dwsMockSocket = {
    close: (code = 1006, reason = '') => emit('close', { code, reason }),
    error: () => emit('error'),
    message: (data) => emit('message', { data }),
    open: () => emit('open'),
  };
}
