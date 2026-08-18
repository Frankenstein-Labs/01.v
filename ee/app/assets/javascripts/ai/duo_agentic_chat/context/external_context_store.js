/*
Registry for additional-context items contributed by features outside the chat
(e.g. the fine-grained access token form). Each provider is a function read at
send time, so the injected content is always the current state, never frozen at
chat start. Items registered here are internal: they are sent to the agent but
hidden from the visible chat transcript (see INTERNAL_CATEGORIES in workflow_utils).

Scope: these items are only injected when a foundational agent drives the send
(see the mergedAdditionalContext branch in duo_agentic_chat_state_manager.vue).
The default Duo chat and catalog agents do not currently receive them.
*/

import { captureExceptionForDuoChat } from '../observability/sentry_utils';

export const PERMISSIONS_FORM_CONTEXT_CATEGORY = 'permissions_form_context';

// Keyed by handle rather than category so a provider can only ever remove its own
// registration: overlapping component lifecycles (an old instance's teardown running
// after a new instance mounts) cannot clobber the live provider.
const providers = new Set();

// `getContent` is read on every send and its return value is JSON-serialized into the
// context item, so providers deal only in plain objects. Return a nullish value to
// contribute nothing for that turn. Returns a disposer that removes this specific
// registration.
export function registerExternalContextProvider(category, getContent) {
  const handle = { category, getContent };
  providers.add(handle);

  return () => providers.delete(handle);
}

export function getExternalContextItems() {
  const items = [];

  providers.forEach(({ category, getContent }) => {
    try {
      const content = getContent();
      if (content != null) {
        items.push({ category, content: JSON.stringify(content), metadata: '{}' });
      }
    } catch (error) {
      // A misbehaving external provider must not break the chat send for everyone.
      captureExceptionForDuoChat(error);
    }
  });

  return items;
}
