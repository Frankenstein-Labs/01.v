import { installWebSocketMock, restoreWebSocket } from './websocket_mock';

// The harness swaps a global, so its install/restore pairing has to survive being
// called out of order. Both cases below silently corrupted `global.WebSocket` for
// the rest of the process before the guards existed, and neither fails loudly at
// the point of the mistake -- it surfaces as a later spec in the same file quietly
// using the fake, or none at all.

describe('websocket_mock install and restore', () => {
  let realWebSocket;

  beforeAll(() => {
    realWebSocket = global.WebSocket;
  });

  afterEach(() => {
    restoreWebSocket();
  });

  it('installs the fake in place of the real constructor', () => {
    installWebSocketMock();

    expect(global.WebSocket).not.toBe(realWebSocket);
  });

  it('restores the real constructor after a repeated install', () => {
    installWebSocketMock();
    const fake = global.WebSocket;

    installWebSocketMock();

    // The second install must not record the fake as the "original".
    expect(global.WebSocket).toBe(fake);

    restoreWebSocket();

    expect(global.WebSocket).toBe(realWebSocket);
  });

  it('leaves the real constructor alone when restored more often than installed', () => {
    installWebSocketMock();
    restoreWebSocket();
    restoreWebSocket();

    expect(global.WebSocket).toBe(realWebSocket);
  });

  it('exposes the readyState statics that stream_worker reads off the global', () => {
    installWebSocketMock();

    expect(global.WebSocket.CONNECTING).toBe(0);
    expect(global.WebSocket.OPEN).toBe(1);
    expect(global.WebSocket.CLOSING).toBe(2);
    expect(global.WebSocket.CLOSED).toBe(3);
  });
});
