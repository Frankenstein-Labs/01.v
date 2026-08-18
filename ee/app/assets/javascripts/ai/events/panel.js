import createEventHub from '~/helpers/event_hub_factory';

export const eventHub = createEventHub();

export const SHOW_SESSION = 'SHOW_SESSION';
export const SCROLL_TO_SESSIONS = 'SCROLL_TO_SESSIONS';

// Sticky flag: set before the sessions widget mounts, consumed on mount.
let pendingScrollToSessions = false;
export function requestScrollToSessions() {
  pendingScrollToSessions = true;
  eventHub.$emit(SCROLL_TO_SESSIONS);
}
export function consumeScrollToSessions() {
  const was = pendingScrollToSessions;
  pendingScrollToSessions = false;
  return was;
}
export const SHOW_NEW_CHAT = 'SHOW_NEW_CHAT';
export const QUEUE_CHAT_COMMAND = 'QUEUE_CHAT_COMMAND';
export const OPEN_AGENT_PLAN_PANEL = 'OPEN_AGENT_PLAN_PANEL';

export const DUO_CHAT_REGISTER_EMPTY_STATE_HEADER = 'DUO_CHAT_REGISTER_EMPTY_STATE_HEADER';
export const DUO_CHAT_REQUEST_EMPTY_STATE_HEADER = 'DUO_CHAT_REQUEST_EMPTY_STATE_HEADER';
