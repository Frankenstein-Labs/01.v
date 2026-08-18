<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import {
  DuoChatContextConversation as DuoChatConversation,
  MESSAGE_MODEL_ROLES,
} from '@gitlab/duo-ui';
import { WORKFLOW_TERMINAL_STATUSES } from 'ee/ai/duo_agents_platform/constants';
import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';
import AgentFlowEmptyState from 'ee/ai/duo_agents_platform/components/common/agent_flow_empty_state.vue';
import MessageApprovalRequest from 'ee/ai/duo_agents_platform/components/common/message_approval_request.vue';
import MessageTodoChecklist from 'ee/ai/duo_agents_platform/components/common/message_todo_checklist.vue';
import { parseToolInfo } from 'ee/ai/duo_agents_platform/icon_utils';

export default {
  name: 'AgentActivityLogs',
  components: {
    DuoChatConversation,
    GlSkeletonLoader,
    AgentFlowEmptyState,
  },
  provide() {
    return {
      markdownClass: 'md',
    };
  },
  props: {
    createdAt: {
      type: String,
      required: true,
    },
    duoMessages: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    status: {
      required: true,
      type: String,
    },
    updatedAt: {
      type: String,
      required: true,
    },
    user: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    hasLogs() {
      return this.duoMessages && this.duoMessages.length > 0;
    },
    chatMessages() {
      if (!this.hasLogs) {
        return [];
      }

      const normalized = WorkflowUtils.normalizeDuoMessages(this.duoMessages);
      const transformed = WorkflowUtils.transformChatMessages(normalized);

      const isTerminal = WORKFLOW_TERMINAL_STATUSES.includes(this.status);
      const toolNames = transformed.map((msg) => parseToolInfo(msg.tool_info)?.name);
      const latestTodoIndex = toolNames.lastIndexOf('todo_write');

      const messages = transformed.map((msg, index) => {
        const message = {
          ...msg,
          // Keep original message_type as role instead of 'assistant' so messages
          // route through MessageMap (which uses our messageRenderers) rather than
          // the assistant-bubble path that shows copy buttons.
          role: msg.role === 'assistant' ? msg.message_type : msg.role,
        };

        // Don't show the in_progress spinner on old todo lists, or once the session ends
        if (toolNames[index] === 'todo_write') {
          message.todoFinished = isTerminal || index !== latestTodoIndex;
        }

        return message;
      });

      // Mark the last request message so the approval renderer knows to show buttons
      const lastRequest = messages.findLast(
        (msg) => msg.message_type === MESSAGE_MODEL_ROLES.request,
      );
      if (lastRequest) {
        lastRequest.isLastMessage = true;
      }

      return messages;
    },
  },
  messageRenderers: [
    {
      component: MessageApprovalRequest,
      matchMessage: (message) => message.message_type === MESSAGE_MODEL_ROLES.request,
    },
    {
      component: MessageTodoChecklist,
      matchMessage: (message) => parseToolInfo(message?.tool_info)?.name === 'todo_write',
    },
  ],
};
</script>
<template>
  <div class="gl-h-full">
    <div class="gl-relative gl-flex gl-flex-col gl-overflow-x-hidden gl-px-4 gl-py-6">
      <div>
        <template v-if="isLoading">
          <gl-skeleton-loader class="gl-ml-4" />
          <gl-skeleton-loader class="gl-ml-4 gl-mt-4" />
        </template>
        <template v-else>
          <agent-flow-empty-state
            :created-at="createdAt"
            :has-logs="hasLogs"
            :updated-at="updatedAt"
            :status="status"
            :user="user"
          />
          <duo-chat-conversation
            v-if="hasLogs"
            :messages="chatMessages"
            :message-renderers="$options.messageRenderers"
            :show-delimiter="false"
            :with-feedback="false"
            :enable-code-insertion="false"
            data-testid="session-chat-bubbles"
          />
        </template>
      </div>
    </div>
  </div>
</template>
