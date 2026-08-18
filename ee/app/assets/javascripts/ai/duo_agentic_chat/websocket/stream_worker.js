import { DwsMockWebSocket, DWS_MOCK_WEBSOCKET_ENABLED } from './dws_mock_websocket';

// Outside development and test this is the real WebSocket, so the wrapper never runs.
// Note this module must not `export` anything: the Jest worker fake evaluates it with
// `Function('self', 'require', code)`, which supplies `require` but not `exports`.
const SocketClass = DWS_MOCK_WEBSOCKET_ENABLED ? DwsMockWebSocket : WebSocket;

let socket = null;

function disconnect() {
  if (socket) {
    if (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) {
      socket.close(1000);
    }
    socket = null;
  }
}

function send(message) {
  if (socket?.readyState === WebSocket.OPEN) {
    const payload = typeof message === 'string' ? message : JSON.stringify(message);
    socket.send(payload);
  }
}

function decodeBinaryPayload(payload) {
  if (payload instanceof ArrayBuffer || payload?.byteLength !== undefined) {
    return new TextDecoder().decode(payload);
  }
  if (typeof payload?.text === 'function') return payload.text();
  return String(payload);
}

function connect(url, initialMessage) {
  disconnect();

  try {
    const ws = new SocketClass(url);
    socket = ws;

    ws.onopen = () => {
      if (initialMessage) {
        send(initialMessage);
      }
      self.postMessage({ type: 'open' });
    };

    ws.onmessage = async (event) => {
      let data;
      try {
        data = typeof event.data === 'string' ? event.data : await decodeBinaryPayload(event.data);
      } catch (e) {
        self.postMessage({
          type: 'error',
          origin: 'decode',
          message: e?.message,
          name: e?.name,
          dataCtor: event.data?.constructor?.name,
          dataSize: event.data?.size ?? event.data?.byteLength,
        });
        return;
      }

      try {
        self.postMessage({ type: 'message', data });
      } catch (e) {
        self.postMessage({
          type: 'error',
          origin: 'post_message',
          message: e?.message,
          name: e?.name,
        });
      }
    };

    ws.onclose = (event) => {
      if (socket === ws) {
        socket = null;
        self.postMessage({ type: 'close', code: event.code, reason: event.reason });
      }
    };

    ws.onerror = () => {
      if (socket === ws) {
        self.postMessage({ type: 'error', origin: 'socket_error', readyState: ws.readyState });
      }
    };
  } catch (e) {
    self.postMessage({ type: 'error', origin: 'connect', message: e?.message });
  }
}

self.addEventListener('message', ({ data }) => {
  switch (data.type) {
    case 'connect':
      connect(data.url, data.initialMessage);
      break;
    case 'send':
      send(data.message);
      break;
    case 'disconnect':
      disconnect();
      break;
    case 'mockEvent':
      if (DWS_MOCK_WEBSOCKET_ENABLED) {
        socket?.dispatchMockEvent(data.event, data.payload);
      }
      break;
    default:
      break;
  }
});
