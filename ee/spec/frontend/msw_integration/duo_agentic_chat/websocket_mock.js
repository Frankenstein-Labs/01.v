/**
 * Replaces `global.WebSocket` so Duo Agentic Chat's whole streaming layer runs for
 * real in integration tests: `stream_manager` (subscriber fan-out, message
 * buffering, error escalation) and `stream_worker` (framing, decoding, the
 * open/close/error protocol) are the code under test, not doubles. Only the
 * transport is faked, which is the lowest seam available -- MSW 1.x cannot
 * intercept websockets.
 *
 * `stream_worker` reads `WebSocket.OPEN` / `WebSocket.CONNECTING` off the global
 * constructor, so the fake carries those statics.
 *
 * ## Every spec must terminate the stream manager
 *
 * `stream_manager` keeps its worker, subscribers, message buffer and connected
 * flag in module state, which outlives a component unmount and leaks into the
 * next test in the file. There is no way for this module to clean that up on a
 * spec's behalf, so each spec has to do it explicitly:
 *
 *     import { terminate } from 'ee/ai/duo_agentic_chat/websocket/stream_manager';
 *
 *     beforeEach(() => {
 *       installWebSocketMock();
 *     });
 *
 *     afterEach(() => {
 *       wrapper?.destroy();
 *       terminate();          // <- releases the worker and clears module state
 *       restoreWebSocket();
 *     });
 *
 * Skipping `terminate()` does not fail loudly; it surfaces as a later test in the
 * same file reusing a dead worker, or receiving a buffered checkpoint it never
 * pushed.
 *
 * ## A socket only exists once a prompt is sent
 *
 * `stream_manager.subscribe()` does not start the worker -- only `connect()` does,
 * which the state manager calls from `startWorkflow`. So a spec has to send a
 * prompt (or hydrate a RUNNING workflow) before `waitForSocket()` can resolve.
 */
import { waitFor } from '@testing-library/vue';
import waitForPromises from 'helpers/wait_for_promises';

const DEFAULT_GOAL = 'dummy-question';

const READY_STATE = { CONNECTING: 0, OPEN: 1, CLOSING: 2, CLOSED: 3 };

const state = {
  sockets: [],
  originalWebSocket: null,
  isInstalled: false,
  timestampCounter: 0,
};

/**
 * Stands in for a browser `WebSocket`. Client-facing methods (`send`, `close`)
 * record what the worker did; the `simulate*` methods play the part of the
 * duo-workflow-service by invoking the handlers the worker assigned.
 */
class FakeWebSocket {
  constructor(url) {
    this.url = url;
    this.readyState = READY_STATE.CONNECTING;
    this.sent = [];
    this.closeCalls = [];
    this.onopen = null;
    this.onmessage = null;
    this.onclose = null;
    this.onerror = null;

    state.sockets.push(this);

    // A real socket opens on its own; do the same so specs don't have to drive a
    // handshake they aren't testing.
    setTimeout(() => this.simulateOpen(), 0);
  }

  send(payload) {
    // A real socket throws `InvalidStateError` once it is no longer OPEN.
    // `stream_worker.send()` guards on `readyState === OPEN`, so this only fires
    // if that guard is ever lost -- which is exactly when we want to hear about it.
    if (this.readyState !== READY_STATE.OPEN) {
      throw new Error(
        `Tried to send on a socket in readyState ${this.readyState}; a real WebSocket would throw.`,
      );
    }

    this.sent.push(payload);
  }

  close(code, reason) {
    this.closeCalls.push({ code, reason });
    // A real socket sits in CLOSING until the close event lands, and only then
    // becomes CLOSED.
    this.readyState = READY_STATE.CLOSING;

    // A real socket emits `close` even when the client initiated it, so emit it
    // here too and let the production code decide what to do with it. On this
    // path `stream_worker.disconnect()` nulls its `socket` reference before the
    // event arrives, and its handler is guarded by `socket === ws`, so a
    // client-initiated close is deliberately *not* reported to `stream_manager`.
    // Emitting it anyway keeps that guard under test instead of hiding it.
    //
    // Deferred to a later task because `stream_worker.connect()` disconnects and
    // then immediately reopens; firing synchronously would order the close
    // before the reconnect, which a real socket never does.
    setTimeout(() => {
      this.readyState = READY_STATE.CLOSED;
      this.onclose?.({ code, reason: reason ?? '' });
    }, 0);
  }

  simulateOpen() {
    if (this.readyState !== READY_STATE.CONNECTING) {
      return;
    }
    this.readyState = READY_STATE.OPEN;
    this.onopen?.({});
  }

  simulateMessage(data) {
    this.onmessage?.({ data });
  }
}

// `stream_worker` reads these off the global constructor, so the fake carries
// them. Assigned once, rather than on every install.
Object.assign(FakeWebSocket, READY_STATE);

/**
 * Call from `beforeEach`. Pair with `restoreWebSocket()`.
 *
 * Safe to call twice without an intervening restore: the real constructor is
 * captured only on the first install. Capturing it again would record
 * `FakeWebSocket` as the "original", and `restoreWebSocket()` would then leave the
 * fake installed for the rest of the process -- every later spec in the same file
 * would silently keep using it.
 */
export const installWebSocketMock = () => {
  state.sockets = [];
  state.timestampCounter = 0;

  if (!state.isInstalled) {
    state.originalWebSocket = global.WebSocket;
    state.isInstalled = true;
  }

  global.WebSocket = FakeWebSocket;
};

/**
 * Call from `afterEach`, after the spec's own `terminate()`.
 *
 * A no-op unless a mock is currently installed, so calling it twice -- or without
 * a matching install -- cannot overwrite the real constructor with `null`.
 */
export const restoreWebSocket = () => {
  if (!state.isInstalled) {
    return;
  }

  global.WebSocket = state.originalWebSocket;
  state.originalWebSocket = null;
  state.isInstalled = false;
  state.sockets = [];
};

export const getSockets = () => state.sockets;

const lastSocket = () => state.sockets[state.sockets.length - 1];

/**
 * Waits for the worker to open a socket. Requires that the spec has already sent
 * a prompt -- see the note about `connect()` at the top of this file.
 */
export const waitForSocket = async () => {
  await waitFor(() => {
    expect(lastSocket()?.readyState).toBe(READY_STATE.OPEN);
  });

  return lastSocket();
};

const nextTimestamp = () => {
  state.timestampCounter += 1;
  return new Date(Date.UTC(2026, 4, 19, 10, 0, state.timestampCounter)).toISOString();
};

/**
 * Every field the real checkpoint `ui_chat_log` entries carry. Keep in sync with
 * `ee/spec/frontend/fixtures/ai/duo_agentic_chat.rb`.
 *
 * `content` must never be empty: `commitMessage` in
 * `ee/ai/tanuki_bot/store/actions.js` silently drops contentless messages.
 */
const logEntry = ({
  messageId,
  content,
  messageType,
  role = null,
  status = 'success',
  messageSubType = null,
  toolInfo = null,
  additionalContext = null,
}) => ({
  content,
  message_type: messageType,
  message_sub_type: messageSubType,
  status,
  tool_info: toolInfo,
  timestamp: nextTimestamp(),
  correlation_id: null,
  message_id: messageId,
  role,
  component_name: null,
  subsession_id: null,
  additional_context: additionalContext,
});

export const userLogEntry = ({ id, content, additionalContext = null, status = 'success' }) =>
  logEntry({
    messageId: id,
    content,
    messageType: 'user',
    role: 'user',
    status,
    additionalContext,
  });

export const agentLogEntry = ({ id, content, status = 'success' }) =>
  logEntry({
    messageId: id,
    content,
    messageType: 'agent',
    role: 'assistant',
    status,
  });

/**
 * A completed tool call. `message_tool.vue` derives its label, secondary text and
 * project chip entirely from `tool_info`, so `name` and `args` are what drive the
 * assertions.
 */
export const toolLogEntry = ({
  id,
  name,
  args = {},
  content,
  toolResponse = null,
  subType = null,
  status = 'success',
}) =>
  logEntry({
    messageId: id,
    content,
    messageType: 'tool',
    messageSubType: subType,
    status,
    toolInfo: {
      name,
      args,
      ...(toolResponse ? { tool_response: toolResponse } : {}),
    },
  });

/**
 * A tool call awaiting approval. `message_map.vue` routes `message_type: 'request'`
 * to `message_tool_approval.vue`, which renders the Approve/Deny card and turns
 * into an "Approved" badge once `status` becomes `success`.
 */
export const toolRequestLogEntry = ({ id, name, args = {}, content, status = 'pending' }) =>
  logEntry({
    messageId: id,
    content,
    messageType: 'request',
    status,
    toolInfo: { name, args },
  });

/**
 * Pushes a checkpoint frame onto the socket, in the exact envelope the service
 * sends. It travels the real path from here: `stream_worker.onmessage` decodes and
 * posts it, `stream_manager` buffers and fans it out, the state manager parses it.
 *
 * `status` defaults to `INPUT_REQUIRED` because that is the state the workflow
 * service leaves a finished turn in, and it is what clears `isWaitingOnPrompt` and
 * re-enables the composer. Pass `RUNNING` for a mid-stream checkpoint.
 *
 * `stream_worker.onmessage` is async, so await this before asserting.
 */
export const pushCheckpoint = (
  uiChatLog,
  { status = 'INPUT_REQUIRED', goal = DEFAULT_GOAL } = {},
) => {
  const socket = lastSocket();

  if (!socket) {
    throw new Error('No socket yet. Send a prompt, then await waitForSocket().');
  }

  socket.simulateMessage(
    JSON.stringify({
      newCheckpoint: {
        checkpoint: JSON.stringify({ channel_values: { ui_chat_log: uiChatLog } }),
        status,
        goal,
      },
    }),
  );

  return waitForPromises();
};

/** Query params of the last socket URL, e.g. `workflow_definition`. */
export const lastWebsocketParams = () => new URL(lastSocket().url).searchParams;

/**
 * The `startRequest` the worker flushed on open. Parsed off the wire rather than
 * read from a `connect()` call, so it covers the worker's serialisation too.
 */
export const lastStartRequest = () => {
  const payload = lastSocket()?.sent[0];

  return payload ? JSON.parse(payload).startRequest : undefined;
};

export const lastAdditionalContext = () => lastStartRequest()?.additional_context ?? [];

/** How many times the client closed a socket -- the cancel/disconnect path. */
export const getCloseCount = () =>
  state.sockets.reduce((total, socket) => total + socket.closeCalls.length, 0);
