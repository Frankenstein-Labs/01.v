<script>
import {
  GlAlert,
  GlBadge,
  GlKeysetPagination,
  GlLoadingIcon,
  GlTable,
  GlTruncate,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import getAiToolRulesQuery from '../../graphql/queries/get_ai_tool_rules.query.graphql';
import AiToolRuleAccessControl from './ai_tool_rule_access_control.vue';
import AiToolRulesFilteredSearch from './ai_tool_rules_filtered_search.vue';

const DEFAULT_PAGE_SIZE = 20;

const READ_BYPASS_WARNING = s__(
  'AiGovernance|This tool can access any GitLab read endpoint. Changes to other read tools may not take effect if this tool remains on Allow.',
);
const COMMAND_BYPASS_WARNING = s__(
  'AiGovernance|This tool can invoke shell commands including git, curl, and file operations. It may bypass restrictions set on other tools.',
);

// Maps a tool id to an inline warning shown under its name in the tool list. These
// warnings surface known bypass paths so admins do not get a false sense of security
// when restricting more specific tools while leaving these on Allow. See #599795.
const TOOL_BYPASS_WARNINGS = {
  gitlab_api_get: READ_BYPASS_WARNING,
  gitlab_graphql: READ_BYPASS_WARNING,
  run_command: COMMAND_BYPASS_WARNING,
};

export default {
  name: 'AiToolRulesTable',
  components: {
    GlAlert,
    GlBadge,
    GlKeysetPagination,
    GlLoadingIcon,
    GlTable,
    GlTruncate,
    AiToolRuleAccessControl,
    AiToolRulesFilteredSearch,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    groupFullPath: {},
    projectFullPath: { default: '' },
    aiToolRulesEditable: { default: true },
  },
  apollo: {
    aiToolRules: {
      query: getAiToolRulesQuery,
      variables() {
        return {
          ...this.queryVariables,
          projectPath: this.projectFullPath || null,
        };
      },
      update(data) {
        return data.aiToolRules;
      },
      result({ data }) {
        if (data) {
          this.hasError = false;
        }
      },
      error() {
        this.hasError = true;
      },
    },
    floorRules: {
      query: getAiToolRulesQuery,
      // Read uncached: floor and effective rules both normalize to AiToolRule:<toolName>,
      // so caching both would collide in Apollo's store and clobber each other. The effective
      // query stays cached so writeFragment after a mutation keeps working.
      fetchPolicy: 'no-cache',
      skip() {
        return !this.projectFullPath;
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.aiToolRules.nodes;
      },
      result({ data }) {
        if (data) {
          this.floorError = false;
        }
      },
      error() {
        this.floorError = true;
      },
    },
  },
  data() {
    return {
      aiToolRules: null,
      floorRules: [],
      after: null,
      before: null,
      search: null,
      actionType: null,
      hasError: false,
      floorError: false,
    };
  },
  computed: {
    isProjectScoped() {
      return Boolean(this.projectFullPath);
    },
    queryVariables() {
      return {
        fullPath: this.groupFullPath,
        search: this.search || null,
        actionType: this.actionType || null,
        last: this.before ? DEFAULT_PAGE_SIZE : null,
        first: this.before ? null : DEFAULT_PAGE_SIZE,
        after: this.after,
        before: this.before,
      };
    },
    isLoading() {
      const floorLoading = this.isProjectScoped && this.$apollo.queries.floorRules.loading;
      return this.$apollo.queries.aiToolRules.loading || floorLoading;
    },
    items() {
      return this.aiToolRules?.nodes || [];
    },
    floorMap() {
      return this.floorRules.reduce((acc, rule) => {
        acc[rule.id] = {
          webAccess: rule.webAccess,
          localAccess: rule.localAccess,
          backgroundAccess: rule.backgroundAccess,
        };
        return acc;
      }, {});
    },
    pageInfo() {
      return this.aiToolRules?.pageInfo || {};
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('AiGovernance|Tool name'),
      thClass: 'gl-w-3/12',
    },
    {
      key: 'source',
      label: s__('AiGovernance|Source'),
      thClass: 'gl-w-1/12 gl-hidden @lg/panel:!gl-table-cell',
      tdClass: 'gl-whitespace-nowrap gl-hidden @lg/panel:!gl-table-cell',
    },
    {
      key: 'actionType',
      label: s__('AiGovernance|Action'),
      thClass: 'gl-w-1/12',
      tdClass: 'gl-whitespace-nowrap',
    },
    {
      key: 'category',
      label: s__('AiGovernance|Category'),
      thClass: 'gl-w-1/12',
      tdClass: 'gl-whitespace-nowrap',
    },
    {
      key: 'webAccess',
      label: s__('AiGovernance|Web access'),
      thClass: 'gl-w-2/12',
      tdClass: 'gl-whitespace-nowrap',
    },
    {
      key: 'localAccess',
      label: s__('AiGovernance|Local access'),
      thClass: 'gl-w-2/12',
      tdClass: 'gl-whitespace-nowrap',
    },
    {
      key: 'backgroundAccess',
      label: s__('AiGovernance|Runner access'),
      thClass: 'gl-w-2/12',
      tdClass: 'gl-whitespace-nowrap',
    },
  ],
  i18n: {
    localAccessNotEnforced: s__('AiGovernance|Local access is not currently enforced.'),
    inheritedFromGroup: s__('AiGovernance|Inherited from group'),
    overridesGroup: s__('AiGovernance|Overrides group'),
    floorLoadError: s__(
      'AiGovernance|Could not load group-level rules. Restriction enforcement may be incomplete.',
    ),
  },
  methods: {
    actionTypeBadgeVariant(actionType) {
      const variants = { READ: 'info', WRITE: 'warning', DESTROY: 'danger' };
      return variants[actionType] ?? 'neutral';
    },
    floorValueFor(item, accessType) {
      return this.floorMap[item.id]?.[accessType] ?? null;
    },
    isOverridden(item, accessType) {
      const floorValue = this.floorValueFor(item, accessType);
      return floorValue !== null && item[accessType] !== floorValue;
    },
    bypassWarningFor(toolId) {
      return TOOL_BYPASS_WARNINGS[toolId] ?? null;
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
    },
    handleFilter({ search, actionType }) {
      // Filters apply across the full result set, so restart keyset pagination.
      this.after = null;
      this.before = null;
      this.search = search || null;
      this.actionType = actionType || null;
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="hasError" variant="danger" :dismissible="false" class="gl-mb-5">
      {{ s__('AiGovernance|Failed to load tool rules.') }}
    </gl-alert>

    <gl-alert
      v-if="floorError"
      variant="warning"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="floor-load-error"
    >
      {{ $options.i18n.floorLoadError }}
    </gl-alert>

    <ai-tool-rules-filtered-search class="gl-mb-5" @filter="handleFilter" />

    <gl-table
      :fields="$options.fields"
      :items="items"
      :busy="isLoading"
      show-empty
      stacked="md"
      :tbody-tr-attr="{ 'data-testid': 'ai-tool-rule-row' }"
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-my-5" />
      </template>

      <template #empty>
        <div class="gl-py-5 gl-text-center" data-testid="ai-tool-rules-empty">
          {{ s__('AiGovernance|No tool rules found.') }}
        </div>
      </template>

      <template #cell(name)="{ item }">
        <gl-truncate
          :text="item.name"
          class="gl-min-w-0 gl-max-w-full gl-font-monospace"
          with-tooltip
          data-testid="tool-name"
        />
        <div
          v-if="bypassWarningFor(item.id)"
          class="gl-mt-2 gl-text-sm gl-text-subtle"
          data-testid="tool-bypass-warning"
        >
          {{ bypassWarningFor(item.id) }}
        </div>
      </template>

      <template #cell(source)="{ item }">
        <gl-truncate
          :text="item.source"
          class="gl-min-w-0 gl-max-w-full"
          with-tooltip
          data-testid="tool-source"
        />
      </template>

      <template #cell(actionType)="{ item }">
        <gl-badge :variant="actionTypeBadgeVariant(item.actionType)" data-testid="tool-action-type">
          {{ item.actionType }}
        </gl-badge>
      </template>

      <template #cell(category)="{ item }">
        <gl-truncate
          :text="item.category"
          class="gl-min-w-0 gl-max-w-full"
          with-tooltip
          data-testid="tool-category"
        />
      </template>

      <template #cell(webAccess)="{ item }">
        <ai-tool-rule-access-control
          :tool-rule="item"
          access-type="webAccess"
          :group-full-path="groupFullPath"
          :project-full-path="projectFullPath"
          :floor-value="floorValueFor(item, 'webAccess')"
          :disabled="!aiToolRulesEditable"
          data-testid="tool-web-access-control"
        />
        <gl-badge
          v-if="isProjectScoped"
          variant="neutral"
          class="gl-mt-2"
          data-testid="tool-web-access-inheritance"
        >
          {{
            isOverridden(item, 'webAccess')
              ? $options.i18n.overridesGroup
              : $options.i18n.inheritedFromGroup
          }}
        </gl-badge>
      </template>

      <template #cell(localAccess)="{ item }">
        <ai-tool-rule-access-control
          :tool-rule="item"
          access-type="localAccess"
          :group-full-path="groupFullPath"
          :project-full-path="projectFullPath"
          :floor-value="floorValueFor(item, 'localAccess')"
          :disabled="!aiToolRulesEditable"
          data-testid="tool-local-access-control"
        />
        <gl-badge
          v-if="isProjectScoped"
          variant="neutral"
          class="gl-mt-2"
          data-testid="tool-local-access-inheritance"
        >
          {{
            isOverridden(item, 'localAccess')
              ? $options.i18n.overridesGroup
              : $options.i18n.inheritedFromGroup
          }}
        </gl-badge>
      </template>

      <template #cell(backgroundAccess)="{ item }">
        <ai-tool-rule-access-control
          :tool-rule="item"
          access-type="backgroundAccess"
          :group-full-path="groupFullPath"
          :project-full-path="projectFullPath"
          :floor-value="floorValueFor(item, 'backgroundAccess')"
          :disabled="!aiToolRulesEditable"
          data-testid="tool-background-access-control"
        />
        <gl-badge
          v-if="isProjectScoped"
          variant="neutral"
          class="gl-mt-2"
          data-testid="tool-background-access-inheritance"
        >
          {{
            isOverridden(item, 'backgroundAccess')
              ? $options.i18n.overridesGroup
              : $options.i18n.inheritedFromGroup
          }}
        </gl-badge>
      </template>

      <template #head(localAccess)="{ label }">
        <span v-gl-tooltip="$options.i18n.localAccessNotEnforced">{{ label }}</span>
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
