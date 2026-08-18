<script>
import { GlIcon } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { n__, s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { BV_HIDE_POPOVER } from '~/lib/utils/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { SESSION_AWAITING_INPUT_GROUP } from 'ee/ai/shared/widgets/constants';
import { eventHub, SHOW_SESSION, requestScrollToSessions } from 'ee/ai/events/panel';

import getDuoAgentSessionsOnWorkItemQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_work_item.query.graphql';
import { SESSIONS_PAGE_SIZE } from '../constants';
import BoardCardSessionBadgePopover from './board_card_session_badge_popover.vue';

export default {
  name: 'BoardCardSessionBadge',
  SESSIONS_PAGE_SIZE,
  components: {
    GlIcon,
    BoardCardSessionBadgePopover,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['view-all-sessions'],
  data() {
    return {
      sessions: [],
      hasNextPage: false,
      queryError: false,
      badgeId: uniqueId('session-badge-'),
    };
  },
  apollo: {
    sessions: {
      query: getDuoAgentSessionsOnWorkItemQuery,
      variables() {
        return {
          id: this.item.id,
          first: SESSIONS_PAGE_SIZE,
        };
      },
      skip() {
        return !this.glFeatures.duoAgentSessionsOnBoard || !this.item.id;
      },
      update(data) {
        const connection = data?.workItem?.features?.aiSession?.duoWorkflows;
        this.hasNextPage = connection?.pageInfo?.hasNextPage ?? false;
        return connection?.nodes ?? [];
      },
      error() {
        this.queryError = true;
      },
      fetchPolicy: 'cache-first',
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.sessions.loading;
    },
    hasSessions() {
      return this.sessions.length > 0;
    },
    displayCount() {
      if (this.queryError) {
        return '!';
      }
      if (this.hasNextPage) {
        return `${SESSIONS_PAGE_SIZE}+`;
      }
      return `${this.sessions.length}`;
    },
    isAwaitingInput() {
      return this.sessions.some((session) =>
        SESSION_AWAITING_INPUT_GROUP.statuses.includes(session.status),
      );
    },
    iconVariant() {
      return this.isAwaitingInput ? 'warning' : 'subtle';
    },
    badgeAriaLabel() {
      const base = sprintf(
        n__(
          'DuoAgentPlatform|%{count} Duo agent session. Activate to view.',
          'DuoAgentPlatform|%{count} Duo agent sessions. Activate to view.',
          this.sessions.length,
        ),
        { count: this.displayCount },
      );
      if (this.isAwaitingInput) {
        return sprintf(s__('DuoAgentPlatform|%{base} Attention required.'), { base });
      }
      return base;
    },
    showBadge() {
      return (!this.isLoading && this.hasSessions) || this.queryError;
    },
    badgeClasses() {
      return this.isAwaitingInput
        ? 'gl-inline-flex gl-items-center gl-gap-2 gl-rounded-pill gl-border gl-bg-status-warning gl-px-3 gl-py-1.5 gl-text-status-warning session-badge-awaiting'
        : 'gl-text-subtle';
    },
  },
  methods: {
    hidePopover() {
      this.$root.$emit(BV_HIDE_POPOVER, this.badgeId);
    },
    showSession(session) {
      eventHub.$emit(SHOW_SESSION, { id: getIdFromGraphQLId(session.id) });
      this.hidePopover();
    },
    retryQuery() {
      this.queryError = false;
      this.$apollo.queries.sessions.refetch();
    },
    viewAllSessions() {
      requestScrollToSessions();
      this.$emit('view-all-sessions');
      this.hidePopover();
    },
  },
};
</script>

<template>
  <div
    v-if="showBadge"
    class="js-no-trigger gl-isolate gl-inline-flex"
    data-testid="board-card-session-badge"
  >
    <span
      :id="badgeId"
      :aria-label="badgeAriaLabel"
      tabindex="0"
      class="gl-cursor-pointer gl-text-sm"
      :class="badgeClasses"
      data-testid="session-badge-button"
    >
      <gl-icon name="session-ai" :size="12" :variant="iconVariant" />
      <span data-testid="session-badge-count">{{ displayCount }}</span>
    </span>

    <board-card-session-badge-popover
      :target="badgeId"
      :sessions="sessions"
      :is-loading="isLoading"
      :query-error="queryError"
      :has-next-page="hasNextPage"
      :display-count="displayCount"
      @show-session="showSession"
      @view-all="viewAllSessions"
      @retry="retryQuery"
    />
  </div>
</template>
