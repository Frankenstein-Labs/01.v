<script>
import { GlAvatar, GlAvatarLink, GlButton, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { projectAutomateAgentSessionPath } from 'ee/lib/utils/path_helpers/project';
import { formatAgentFlowTitle, getNumericId } from 'ee/ai/duo_agents_platform/utils';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'AgentSessionRow',
  components: {
    GlAvatar,
    GlAvatarLink,
    GlButton,
    GlLink,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    session: {
      type: Object,
      required: true,
    },
    showViewDetails: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    numericId() {
      return getIdFromGraphQLId(this.session.id);
    },
    sessionUrl() {
      const fullPath = this.session.project?.fullPath;
      return fullPath ? projectAutomateAgentSessionPath(fullPath, this.numericId) : null;
    },
    formattedTitle() {
      return formatAgentFlowTitle(this.session.title, this.session.workflowDefinition);
    },
    user() {
      return this.session.user || null;
    },
    userId() {
      return getNumericId(this.user?.id);
    },
  },
};
</script>

<template>
  <div
    class="gl-flex gl-items-center gl-justify-between gl-px-4 gl-py-3"
    data-testid="agent-session-row"
  >
    <div class="gl-flex gl-items-center gl-gap-2">
      <gl-link
        v-if="sessionUrl"
        :href="sessionUrl"
        target="_blank"
        class="gl-min-w-12 gl-shrink-0"
        data-testid="session-id"
        >#{{ numericId }}</gl-link
      >
      <span v-else class="gl-min-w-12 gl-shrink-0 gl-text-subtle" data-testid="session-id">
        #{{ numericId }}
      </span>
      <span class="gl-truncate gl-text-subtle" data-testid="session-title">
        {{ formattedTitle }}
      </span>
    </div>
    <div class="gl-flex gl-items-center gl-gap-3">
      <time-ago-tooltip
        v-if="session.updatedAt"
        :time="session.updatedAt"
        class="gl-text-sm gl-text-subtle"
        data-testid="session-updated-at"
      />
      <gl-button
        v-if="sessionUrl && showViewDetails"
        :href="sessionUrl"
        target="_blank"
        size="small"
        variant="confirm"
        category="tertiary"
        data-testid="session-view-details-button"
      >
        {{ s__('DuoAgentPlatform|View details') }}
      </gl-button>
      <gl-avatar-link
        v-if="user"
        v-gl-tooltip.bottom
        :href="user.webPath"
        :title="user.name"
        :data-user-id="userId"
        :data-username="user.username"
        class="js-user-link"
        data-testid="session-triggered-user"
      >
        <gl-avatar
          :src="user.avatarUrl"
          :entity-name="user.name"
          :alt="user.name"
          :size="16"
          shape="circle"
        />
      </gl-avatar-link>
    </div>
  </div>
</template>
