<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { DuoChatContextConversation as DuoChatConversation } from '@gitlab/duo-ui';
import { s__, sprintf } from '~/locale';
import { getDayDifference } from '~/lib/utils/datetime/date_calculation_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  AGENT_PLATFORM_SESSION_RETENTION_LENGTH,
  AGENT_PLATFORM_STATUS_FAILED,
} from '../../constants';

export default {
  name: 'AgentFlowEmptyState',
  components: {
    DuoChatConversation,
    GlLink,
    GlSprintf,
  },
  props: {
    createdAt: {
      type: String,
      required: true,
    },
    hasLogs: {
      type: Boolean,
      required: true,
    },
    updatedAt: {
      type: String,
      required: true,
    },
    status: {
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
    isWithinRetention() {
      const daysSinceUpdate = getDayDifference(new Date(this.updatedAt), new Date());
      return daysSinceUpdate <= AGENT_PLATFORM_SESSION_RETENTION_LENGTH;
    },
    isFailed() {
      return this.status === AGENT_PLATFORM_STATUS_FAILED;
    },
    emptyStateItems() {
      if (!this.isWithinRetention) {
        return null;
      }

      const items = [];
      const isCreating = !this.hasLogs && !this.status;

      // First item: Session creation status
      items.push({
        id: isCreating ? 'creating-session' : 'created-session',
        icon: isCreating ? 'status_running' : 'status_success',
        text: isCreating
          ? s__('DuoAgentPlatform|Creating session')
          : s__('DuoAgentPlatform|Created session'),
        content: isCreating ? s__('DuoAgentPlatform|Takes a few seconds...') : null,
        showUser: !isCreating,
        variant: 'subtle',
        timestamp: this.createdAt,
      });

      // Second item: Job status (non-failed only)
      if (!this.hasLogs && this.status && !this.isFailed) {
        items.push({
          id: 'starting-job',
          icon: 'status_running',
          text: s__('DuoAgentPlatform|Starting job'),
          content: s__('DuoAgentPlatform|Takes a few minutes...'),
          variant: 'subtle',
          timestamp: this.createdAt,
        });
      }

      return items;
    },
    messages() {
      return this.emptyStateItems.map((item) => {
        let { text } = item;
        if (item.showUser && this.user?.name) {
          text = sprintf(s__('DuoAgentPlatform|%{text} by %{name}'), {
            text,
            name: this.user.name,
          });
        }

        const message = {
          role: 'system',
          message_type: 'agent',
          content: item.content ? `**${text}** ${item.content}` : text,
          requestId: item.id,
          timestamp: item.timestamp,
          status: 'success',
        };

        if (item.variant === 'danger') {
          message.errors = [text];
          message.content = '';
        }

        return message;
      });
    },
    retentionMessage() {
      return s__(
        'DuoAgentPlatform|Activity deleted after 30 days of inactivity. %{linkStart}Learn more.%{linkEnd}',
      );
    },
    showRetentionMessage() {
      return !this.isWithinRetention && !this.hasLogs;
    },
  },
  messageRenderers: [],
  sessionRetentionPath: helpPagePath('user/duo_agent_platform/sessions/_index', {
    anchor: '#session-retention',
  }),
};
</script>

<template>
  <div>
    <div
      v-if="showRetentionMessage"
      class="gl-p-4 gl-text-center"
      data-testid="retention-message-container"
    >
      <gl-sprintf :message="retentionMessage">
        <template #link="{ content }">
          <gl-link :href="$options.sessionRetentionPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>

    <duo-chat-conversation
      v-else-if="messages.length"
      :messages="messages"
      :message-renderers="$options.messageRenderers"
      :show-delimiter="false"
      :with-feedback="false"
      :enable-code-insertion="false"
      data-testid="empty-state-chat-bubbles"
    />
  </div>
</template>
