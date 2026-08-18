<script>
import { GlIcon, GlLink } from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import getAgentArtifactsQuery from 'ee/agent_artifacts/graphql/queries/get_agent_artifacts.query.graphql';
import getProjectAgentArtifactsQuery from 'ee/agent_artifacts/graphql/queries/get_project_agent_artifacts.query.graphql';
import DashboardListCard from './dashboard_list_card.vue';

const LIMIT = 5;

export default {
  name: 'AuditTrailCard',
  components: {
    DashboardListCard,
    TimeAgoTooltip,
    GlIcon,
    GlLink,
  },
  inject: {
    groupFullPath: { default: null },
    projectFullPath: { default: null },
  },
  apollo: {
    sessionArtifacts: {
      query() {
        return this.isProjectMode ? getProjectAgentArtifactsQuery : getAgentArtifactsQuery;
      },
      variables() {
        return this.isProjectMode
          ? { projectFullPath: this.projectFullPath, first: LIMIT }
          : { groupFullPath: this.groupFullPath, first: LIMIT };
      },
      update(data) {
        return (data.project ?? data.group)?.duoWorkflowSessionArtifacts?.nodes || [];
      },
      error() {
        this.hasError = true;
      },
    },
  },
  data() {
    return {
      sessionArtifacts: [],
      hasError: false,
    };
  },
  computed: {
    isProjectMode() {
      return Boolean(this.projectFullPath);
    },
    loading() {
      return this.$apollo.queries.sessionArtifacts.loading;
    },
    sessions() {
      return (this.sessionArtifacts || []).map((node) => {
        const id = getIdFromGraphQLId(node.id);

        return {
          id,
          webPath: node.webPath,
          createdAt: node.workflowCreatedAt,
          title: sprintf(s__('AiGovernance|Session #%{id} · %{name}'), {
            id,
            name: formatAgentDefinition(node.workflowDefinition),
          }),
          subtitle: n__(
            'AiGovernance|%d audit event',
            'AiGovernance|%d audit events',
            node.auditEventsCount ?? 0,
          ),
        };
      });
    },
    isEmpty() {
      return !this.loading && !this.hasError && this.sessions.length === 0;
    },
    errorText() {
      return this.hasError ? s__('AiGovernance|Failed to load audit trail.') : '';
    },
  },
  i18n: {
    title: s__('AiGovernance|Audit trail'),
    viewAll: s__('AiGovernance|View full audit log'),
    empty: s__('AiGovernance|No recent agent sessions.'),
  },
  // Links to the "Audit events" tab on the same governance page.
  viewAllHref: '?tab=agent-artifacts',
};
</script>

<template>
  <dashboard-list-card
    :title="$options.i18n.title"
    :view-all-text="$options.i18n.viewAll"
    :view-all-href="$options.viewAllHref"
    :loading="loading"
    :error-text="errorText"
    :is-empty="isEmpty"
    :empty-text="$options.i18n.empty"
  >
    <li
      v-for="session in sessions"
      :key="session.id"
      class="gl-border-b gl-border-section last:gl-border-b-0"
    >
      <component
        :is="session.webPath ? 'gl-link' : 'div'"
        :href="session.webPath || undefined"
        class="gl-flex gl-items-center gl-justify-between gl-gap-3 gl-p-4 gl-text-default"
        :class="{ 'hover:gl-bg-strong hover:gl-no-underline': session.webPath }"
        data-testid="audit-trail-row"
      >
        <span class="gl-flex gl-min-w-0 gl-items-center gl-gap-3">
          <gl-icon name="documents" class="gl-shrink-0 gl-text-subtle" />
          <span class="gl-min-w-0">
            <span class="gl-block gl-truncate gl-font-bold">{{ session.title }}</span>
            <span class="gl-block gl-truncate gl-text-sm gl-text-subtle">
              {{ session.subtitle }}
            </span>
          </span>
        </span>
        <span class="gl-flex gl-shrink-0 gl-items-center gl-gap-2 gl-text-sm gl-text-subtle">
          <time-ago-tooltip :time="session.createdAt" />
          <gl-icon v-if="session.webPath" name="chevron-right" data-testid="audit-trail-chevron" />
        </span>
      </component>
    </li>
  </dashboard-list-card>
</template>
