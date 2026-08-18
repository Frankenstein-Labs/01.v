# Duo Chat WebSocket testing utility

`dws_mock_websocket.js` makes it possible to reproduce WebSocket failures in Duo Agentic
Chat without a backend willing to produce them.

Connection handling branches on close codes such as `1006` abnormal closure, `1008`
policy violation and `1013` try again later. A real Duo Workflow Service does not send
those on demand, so the code that reacts to them is otherwise hard to reach.

`DwsMockWebSocket` wraps a real `WebSocket` and forwards every event untouched, so chat
still connects to your GDK and streams real replies. On top of that it can synthesise
events, which you trigger from the browser console.

## Use it

There is nothing to set up. Open Duo Agentic Chat in your GDK, send a prompt, then in the
browser console:

```javascript
gl.dwsMockSocket.close(1013); // close with a specific code
gl.dwsMockSocket.close(); // abnormal closure, code 1006
gl.dwsMockSocket.error(); // fire an error event
gl.dwsMockSocket.message('{"newCheckpoint":{"status":"running"}}'); // inject a frame
gl.dwsMockSocket.open(); // fire an open event
```

Each call is handled as though the server had produced the event, so the client reacts
exactly as it would in production. Reload the page for a fresh connection.

A synthesised `close` also closes the wrapped socket. Without that the client would
reconnect while the old connection was still open, and the real `close` would arrive
later as a second, unexpected event.

`error()` invokes the socket's `onerror` handler. If the stream worker does not assign
one, nothing surfaces. In that case reach the client's error path through an unclean
close instead, which is what a dropped connection looks like:

```javascript
gl.dwsMockSocket.close(1006);
```

## When it is active

`DWS_MOCK_WEBSOCKET_ENABLED` is true when `NODE_ENV` is `development` or `test`. Anywhere
else the stream worker uses the real `WebSocket` and the global is never defined.

`test` is checked as well as `development` because webpack derives `NODE_ENV` from its
`mode`, so a bundle only ever sees `development` or `production`. The `test` value comes
from Jest at runtime, and it is what lets specs exercise the mock.

The flag is written as two comparisons rather than
`['development', 'test'].includes(...)` because the array form is not statically
foldable: a production build keeps the mock with `includes` and strips it with
comparisons. Keep it that way, or the mock ships to production.
