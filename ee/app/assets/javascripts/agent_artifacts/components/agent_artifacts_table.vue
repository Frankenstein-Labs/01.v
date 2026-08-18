<script>
import {
  GlAvatar,
  GlAvatarLink,
  GlTable,
  GlLink,
  GlSprintf,
  GlKeysetPagination,
  GlLoadingIcon,
  GlBadge,
  GlTruncate,
  GlAlert,
  GlIcon,
} from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';
import { getClientType } from '../utils';
import getAgentArtifactsQuery from '../graphql/queries/get_agent_artifacts.query.graphql';
import getProjectAgentArtifactsQuery from '../graphql/queries/get_project_agent_artifacts.query.graphql';

const DEFAULT_PAGE_SIZE = 10;

export default {
  name: 'AgentArtifactsTable',
  components: {
    GlAvatar,
    GlAvatarLink,
    GlTable,
    GlLink,
    GlSprintf,
    GlKeysetPagination,
    GlLoadingIcon,
    GlBadge,
    GlTruncate,
    GlAlert,
    GlIcon,
  },
  inject: {
    groupFullPath: { default: null },
    projectFullPath: { default: null },
    aiAuditEventsStorageEnabled: { default: true },
    aiAuditEventsSettingsPath: { default: '' },
  },
  props: {
    activeItem: {
      type: Object,
      required: false,
      default: null,
    },
    filter: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['row-click'],
  apollo: {
    sessionArtifacts: {
      query() {
        return this.isProjectMode ? getProjectAgentArtifactsQuery : getAgentArtifactsQuery;
      },
      variables() {
        const paging = {
          last: this.before ? DEFAULT_PAGE_SIZE : null,
          first: this.before ? null : DEFAULT_PAGE_SIZE,
          after: this.after,
          before: this.before,
        };

        if (this.isProjectMode) {
          return {
            projectFullPath: this.projectFullPath,
            ...paging,
            ...this.filter,
          };
        }

        return {
          groupFullPath: this.groupFullPath,
          ...paging,
          ...this.filter,
        };
      },
      skip() {
        return this.isProjectMode ? !this.projectFullPath : !this.groupFullPath;
      },
      update(data) {
        this.hasError = false;
        return (data.project ?? data.group)?.duoWorkflowSessionArtifacts || [];
      },
      error() {
        this.hasError = true;
      },
    },
  },
  data() {
    return {
      sessionArtifacts: null,
      after: null,
      before: null,
      hasError: false,
    };
  },
  computed: {
    isProjectMode() {
      return Boolean(this.projectFullPath);
    },
    isLoading() {
      return this.$apollo.queries.sessionArtifacts.loading;
    },
    items() {
      return this.sessionArtifacts?.nodes || [];
    },
    hasActiveFilter() {
      return Object.keys(this.filter).length > 0;
    },
    showStorageDisabledMessage() {
      return !this.aiAuditEventsStorageEnabled && !this.hasActiveFilter && !this.hasError;
    },
    pageInfo() {
      return this.sessionArtifacts?.pageInfo || {};
    },
    fields() {
      return [
        {
          key: 'aiItem',
          label: s__('AgentArtifacts|AI Item'),
          tdClass: '@max-sm/panel:gl-w-full @max-lg/panel:gl-wrap-anywhere @sm/panel:gl-max-w-30',
          thClass: '@sm/panel:gl-max-w-30',
        },
        {
          key: 'triggeredBy',
          label: __('User'),
          tdClass: 'gl-whitespace-nowrap',
        },
        {
          key: 'id',
          label: s__('AgentArtifacts|Session ID'),
          tdClass: 'gl-whitespace-nowrap',
        },
        {
          key: 'auditEvents',
          label: s__('AgentArtifacts|Audit events'),
          tdClass: 'gl-whitespace-nowrap',
        },
        // The Project column is redundant in project mode (every row is the current project).
        ...(this.isProjectMode
          ? []
          : [
              {
                key: 'project',
                label: __('Project'),
                tdClass:
                  '@max-lg/panel:gl-w-full @max-lg/panel:gl-wrap-anywhere @lg/panel:gl-max-w-30 gl-hidden @lg/panel:!gl-table-cell',
                thClass: 'gl-max-w-30 gl-hidden @lg/panel:!gl-table-cell',
              },
            ]),
        {
          key: 'startTime',
          label: s__('AgentArtifacts|Start time'),
          tdClass: 'gl-whitespace-nowrap',
        },
      ];
    },
  },
  watch: {
    filter() {
      this.after = null;
      this.before = null;
    },
  },
  methods: {
    rowClass(item) {
      const classes = ['gl-cursor-pointer', 'hover:gl-bg-gray-50'];
      if (item === this.activeItem) {
        classes.push('!gl-bg-blue-50');
      }
      return classes;
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
    },
    formatStartDate(dateString) {
      return formatDate(dateString, 'yyyy-mm-dd');
    },
    formatStartTime(dateString) {
      return formatDate(dateString, 'HH:MM:ss Z');
    },
    getSessionId(sessionId) {
      return getIdFromGraphQLId(sessionId);
    },
    formatName(name) {
      return formatAgentDefinition(name);
    },
    getClientType(item) {
      return getClientType(item);
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="hasError" variant="danger" :dismissible="false" class="gl-mb-5">
      {{ s__('AgentArtifacts|Failed to load agent artifacts.') }}
    </gl-alert>
    <gl-table
      :fields="fields"
      :items="items"
      :busy="isLoading"
      show-empty
      stacked="sm"
      :tbody-tr-class="rowClass"
      :tbody-tr-attr="{ 'data-testid': 'agent-artifacts-table-row' }"
      @row-clicked="$emit('row-click', $event)"
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-my-5" />
      </template>

      <template #empty>
        <div
          v-if="showStorageDisabledMessage"
          class="gl-py-5 gl-text-center"
          data-testid="storage-disabled-empty-state"
        >
          <gl-sprintf
            :message="
              s__(
                'AgentArtifacts|AI audit event storage is turned off, so no audit events are being recorded. %{linkStart}Turn on storage%{linkEnd} to start capturing audit events.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link
                v-if="aiAuditEventsSettingsPath"
                :href="aiAuditEventsSettingsPath"
                data-testid="enable-storage-link"
                >{{ content }}</gl-link
              >
              <span v-else>{{ content }}</span>
            </template>
          </gl-sprintf>
        </div>
        <div v-else class="gl-py-5 gl-text-center">
          {{ s__('AgentArtifacts|No agent artifacts found.') }}
        </div>
      </template>

      <template #cell(aiItem)="{ item }">
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-icon
            :name="getClientType(item).icon"
            :size="16"
            class="gl-shrink-0"
            data-testid="ai-item-client-type-icon"
          />
          <div class="gl-flex gl-min-w-0 gl-flex-col">
            <span data-testid="ai-item-client-type-name">{{ getClientType(item).name }}</span>
            <gl-truncate
              :text="formatName(item.workflowDefinition)"
              class="gl-min-w-0 gl-max-w-full gl-text-sm gl-text-subtle"
              with-tooltip
              data-testid="ai-item-name"
            />
          </div>
        </div>
      </template>

      <template #cell(triggeredBy)="{ item }">
        <div
          v-if="item.triggeredBy?.webPath"
          class="gl-flex gl-items-center gl-gap-2"
          data-testid="user-cell"
        >
          <gl-avatar-link :href="item.triggeredBy.webPath">
            <gl-avatar
              :src="item.triggeredBy.avatarUrl"
              :entity-name="item.triggeredBy.name"
              :size="16"
              data-testid="user-avatar"
            />
          </gl-avatar-link>
          <gl-link :href="item.triggeredBy.webPath" data-testid="user-link">{{
            item.triggeredBy.name
          }}</gl-link>
        </div>
        <span v-else class="gl-text-subtle" data-testid="user-empty">—</span>
      </template>

      <template #cell(id)="{ item }">
        <gl-link v-if="item.webPath" :href="item.webPath" data-testid="session-link">
          #{{ getSessionId(item.id) }}
        </gl-link>
        <span v-else class="gl-text-subtle" data-testid="session-empty">—</span>
      </template>

      <template #cell(auditEvents)="{ item }">
        <gl-badge variant="neutral" class="gl-px-4" data-testid="audit-events-count">
          {{ item.auditEventsCount }}
        </gl-badge>
      </template>

      <template #cell(project)="{ item }">
        <gl-link
          v-if="item.project?.webPath"
          :href="item.project.webPath"
          data-testid="project-link"
        >
          <gl-truncate
            :text="item.project.name"
            class="gl-min-w-0 gl-max-w-full hover:gl-underline"
            with-tooltip
          />
        </gl-link>
        <span v-else class="gl-text-subtle" data-testid="project-empty">—</span>
      </template>

      <template #cell(startTime)="{ item }">
        <div class="gl-text-subtle" data-testid="start-time">
          <div>{{ formatStartDate(item.workflowCreatedAt) }}</div>
          <div>{{ formatStartTime(item.workflowCreatedAt) }}</div>
        </div>
      </template>
    </gl-table>

    <div
      v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage"
      class="gl-mt-5 gl-flex gl-justify-center"
    >
      <gl-keyset-pagination v-bind="pageInfo" @prev="handlePrev" @next="handleNext" />
    </div>
  </div>
</template>
