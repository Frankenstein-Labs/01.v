import createEventHub from '~/helpers/event_hub_factory';
import { CHAT_MESSAGE_TYPES } from 'ee/ai/constants';
import { processWorkflowMessage } from '../websocket/workflow_utils';

export const DUO_CHAT_TOOL_REQUESTED_EVENT = 'duo:tool-requested';
export const DUO_CHAT_TOOL_COMPLETED_EVENT = 'duo:tool-completed';
export const DUO_CHAT_TOOL_FAILURE_EVENT = 'duo:tool-failure';

const eventHub = createEventHub();
let lastProcessedMessageId = null;

export function subscribeToEvent(event, handler) {
  eventHub.$on(event, handler);
  return {
    dispose() {
      eventHub.$off(event, handler);
    },
  };
}

export function initDuoAgenticChatEventHub(streamManager) {
  const openSubscription = streamManager.subscribe('open', () => {
    lastProcessedMessageId = null;
  });

  const messageSubscription = streamManager.subscribe('message', async (event) => {
    const workflowData = await processWorkflowMessage(event, lastProcessedMessageId);
    if (!workflowData) return;

    lastProcessedMessageId = workflowData.lastProcessedMessageId;

    workflowData.messages.forEach((msg) => {
      const { message_id: messageId, message_type: messageType, tool_info: toolInfo } = msg || {};

      if (!toolInfo?.name) return;

      const toolName = toolInfo.name;
      const status = toolInfo.tool_response?.status;

      if (messageType === CHAT_MESSAGE_TYPES.request) {
        eventHub.$emit(DUO_CHAT_TOOL_REQUESTED_EVENT, { messageId, name: toolName });
        return;
      }

      if (messageType !== CHAT_MESSAGE_TYPES.tool) return;

      if (status === 'success') {
        eventHub.$emit(DUO_CHAT_TOOL_COMPLETED_EVENT, {
          messageId,
          name: toolName,
          args: toolInfo.args,
        });
      } else if (status === 'failure') {
        eventHub.$emit(DUO_CHAT_TOOL_FAILURE_EVENT, {
          messageId,
          name: toolName,
          error: toolInfo.tool_response?.content,
        });
      }
    });
  });

  return {
    dispose() {
      openSubscription.dispose();
      messageSubscription.dispose();
      lastProcessedMessageId = null;
    },
  };
}
