<script>
import { GlIcon, GlLink, GlPopover, GlSkeletonLoader, GlButton } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { formatAgentFlowTitle } from 'ee/ai/duo_agents_platform/utils';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';
import { SESSIONS_PAGE_SIZE } from '../constants';

export default {
  name: 'BoardCardSessionBadgePopover',
  components: {
    AgentStatusIcon,
    GlButton,
    GlIcon,
    GlLink,
    GlPopover,
    GlSkeletonLoader,
  },
  props: {
    target: {
      type: String,
      required: true,
    },
    sessions: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    queryError: {
      type: Boolean,
      required: true,
    },
    hasNextPage: {
      type: Boolean,
      required: true,
    },
    displayCount: {
      type: String,
      required: true,
    },
  },
  emits: ['retry', 'show-session', 'view-all'],
  computed: {
    popoverTitle() {
      return sprintf(
        n__(
          'DuoAgentPlatform|%{count} session',
          'DuoAgentPlatform|%{count} sessions',
          this.sessions.length,
        ),
        { count: this.displayCount },
      );
    },
    showingFirstText() {
      return sprintf(s__('DuoAgentPlatform|Showing most recent %{count}'), {
        count: SESSIONS_PAGE_SIZE,
      });
    },
  },
  methods: {
    sessionNumericId(session) {
      return getIdFromGraphQLId(session.id);
    },
    sessionTitle(session) {
      return formatAgentFlowTitle(session.title, session.workflowDefinition);
    },
  },
};
</script>

<template>
  <gl-popover
    :target="target"
    triggers="click blur"
    placement="bottom"
    data-testid="session-badge-popover"
  >
    <template #title>
      <div class="gl-flex gl-items-center gl-gap-2">
        <gl-icon name="session-ai" :size="16" />
        <span data-testid="popover-title">{{ popoverTitle }}</span>
      </div>
    </template>

    <div v-if="queryError" data-testid="popover-error">
      <p class="gl-mb-3 gl-text-subtle">
        {{ s__("DuoAgentPlatform|Couldn't load sessions.") }}
      </p>
      <gl-button size="small" data-testid="popover-retry-button" @click="$emit('retry')">
        {{ s__('DuoAgentPlatform|Retry') }}
      </gl-button>
    </div>

    <div v-else-if="isLoading" data-testid="popover-loading">
      <gl-skeleton-loader :lines="3" />
    </div>

    <template v-else>
      <div
        v-for="session in sessions"
        :key="session.id"
        class="gl-flex gl-items-center gl-gap-2 gl-py-2 first-of-type:gl-pt-0"
        data-testid="popover-session-row"
      >
        <agent-status-icon
          :status="session.status"
          :human-status="session.humanStatus"
          class="gl-shrink-0 gl-scale-75"
        />
        <gl-link
          class="gl-text-sm gl-font-bold"
          data-testid="popover-session-link"
          @click.prevent="$emit('show-session', session)"
        >
          #{{ sessionNumericId(session) }}
        </gl-link>
        <span
          class="gl-truncate gl-text-sm gl-text-subtle"
          :title="sessionTitle(session)"
          data-testid="popover-session-definition"
        >
          {{ sessionTitle(session) }}
        </span>
        <span v-if="!session.title" class="gl-text-sm" data-testid="popover-session-status">
          {{ session.humanStatus }}
        </span>
      </div>

      <div
        class="gl-border-t gl-mt-2 gl-pt-2 gl-text-sm gl-text-subtle"
        data-testid="popover-footer"
      >
        <span v-if="hasNextPage" data-testid="popover-showing-first">
          {{ showingFirstText }} &middot;
        </span>
        <gl-link
          class="gl-text-sm"
          data-testid="popover-view-all-link"
          @click.prevent="$emit('view-all')"
        >
          {{ s__('DuoAgentPlatform|View all sessions') }}
        </gl-link>
      </div>
    </template>
  </gl-popover>
</template>
