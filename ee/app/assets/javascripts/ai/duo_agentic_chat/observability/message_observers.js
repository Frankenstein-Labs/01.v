import {
  DUO_CHAT_TOOL_REQUESTED_EVENT,
  DUO_CHAT_TOOL_COMPLETED_EVENT,
  DUO_CHAT_TOOL_FAILURE_EVENT,
  subscribeToEvent,
} from '../events/event_hub';
import { captureExceptionForDuoChat } from './sentry_utils';

export function initMessageObservers(eventsTracker) {
  const requestedSubscription = subscribeToEvent(
    DUO_CHAT_TOOL_REQUESTED_EVENT,
    ({ messageId, name }) => {
      eventsTracker.trackToolRecommended({ messageId, toolName: name });
    },
  );

  const completedSubscription = subscribeToEvent(
    DUO_CHAT_TOOL_COMPLETED_EVENT,
    ({ messageId, name }) => {
      eventsTracker.trackToolSucceeded({ messageId, toolName: name });
    },
  );

  const failureSubscription = subscribeToEvent(
    DUO_CHAT_TOOL_FAILURE_EVENT,
    ({ messageId, name, content }) => {
      eventsTracker.trackToolFailed({ messageId, toolName: name });
      captureExceptionForDuoChat(new Error(`${name}: ${content}`));
    },
  );

  return {
    dispose() {
      requestedSubscription.dispose();
      completedSubscription.dispose();
      failureSubscription.dispose();
    },
  };
}
