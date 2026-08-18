<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlDisclosureDropdown,
  GlEmptyState,
  GlIcon,
  GlLoadingIcon,
  GlSearchBoxByType,
  GlTab,
  GlTabs,
} from '@gitlab/ui';
import { safeLoad } from 'js-yaml';
import { s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import updatePolicyMutation from 'ee/security_orchestration/graphql/mutations/create_policy.mutation.graphql';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { ACTION_TYPES } from '../../constants/action_types';
import { RULE_TYPES } from '../../constants/rule_types';
import StatsBar from './stats_bar.vue';
import BundlesList from './bundles_list.vue';

const NAMESPACE_QUERY_MAP = {
  [NAMESPACE_TYPES.PROJECT]: projectSecurityPoliciesQuery,
  [NAMESPACE_TYPES.GROUP]: groupSecurityPoliciesQuery,
};

const STATUS_VARIANT = {
  active: 'success',
  disabled: 'neutral',
};

function parsePolicyYaml(yaml) {
  try {
    const parsed = safeLoad(yaml);
    if (!parsed || typeof parsed !== 'object') return null;
    // Per-policy YAML is a flat object with top-level `rules`/`actions` arrays.
    // If no top-level rules/actions, check if it's wrapped in a policy-type key.
    if (Array.isArray(parsed.rules) || Array.isArray(parsed.actions)) return parsed;
    const key = Object.keys(parsed).find((k) => Array.isArray(parsed[k]) && parsed[k].length > 0);
    return key ? parsed[key][0] : null;
  } catch {
    return null;
  }
}

export default {
  name: 'PoliciesList',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlDisclosureDropdown,
    GlEmptyState,
    GlIcon,
    GlLoadingIcon,
    GlSearchBoxByType,
    GlTab,
    GlTabs,
    StatsBar,
    BundlesList,
    TimeAgoTooltip,
  },
  inject: ['namespacePath', 'namespaceType'],
  apollo: {
    securityPolicies: {
      query() {
        return NAMESPACE_QUERY_MAP[this.namespaceType];
      },
      variables() {
        return { fullPath: this.namespacePath };
      },
      update(data) {
        return data?.namespace?.securityPolicies?.nodes ?? [];
      },
      error(err) {
        this.fetchError = err?.message || s__('SecurityOrchestration|Failed to load policies');
      },
    },
  },
  STATUS_VARIANT,
  i18n: {
    newPolicy: s__('SecurityOrchestration|New policy'),
    browseBundles: s__('SecurityOrchestration|Browse bundles'),
    policies: s__('SecurityOrchestration|Policies'),
    bundles: s__('SecurityOrchestration|Bundles'),
    subtitle: s__(
      'SecurityOrchestration|Define and enforce governance across your entire software delivery lifecycle.',
    ),
    filterPlaceholder: s__('SecurityOrchestration|Filter policies…'),
    noPoliciesFound: s__('SecurityOrchestration|No policies found'),
    createFirstPolicy: s__('SecurityOrchestration|Create your first policy to get started.'),
    deleteError: s__('SecurityOrchestration|Failed to delete policy. Please try again.'),
    edit: s__('SecurityOrchestration|Edit'),
    delete: s__('SecurityOrchestration|Delete'),
    enable: s__('SecurityOrchestration|Enable'),
    disable: s__('SecurityOrchestration|Disable'),
    rules: s__('SecurityOrchestration|Rules'),
    actions: s__('SecurityOrchestration|Actions'),
  },
  emits: ['create', 'edit'],
  data() {
    return {
      securityPolicies: [],
      searchQuery: '',
      activeTab: 0,
      fetchError: '',
      deleteError: '',
      expandedPolicyName: null,
      statsData: {
        activePolicies: { total: 0, enforcing: 0, warning: 0, audit: 0 },
        actionsThisWeek: { blocked: 0, warned: 0, logged: 0 },
        catching: { count: 0 },
        needsAttention: { total: 0, drafts: 0, disabled: 0, pendingApproval: 0 },
      },
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.securityPolicies.loading;
    },
    filteredPolicies() {
      if (!this.searchQuery) return this.securityPolicies;
      const q = this.searchQuery.toLowerCase();
      return this.securityPolicies.filter((p) => p.name.toLowerCase().includes(q));
    },
  },
  methods: {
    policyStatus(policy) {
      return policy.enabled ? 'active' : 'disabled';
    },
    statusVariant(policy) {
      return STATUS_VARIANT[this.policyStatus(policy)] || 'neutral';
    },
    statusLabel(policy) {
      return policy.enabled
        ? s__('SecurityOrchestration|Active')
        : s__('SecurityOrchestration|Disabled');
    },
    formattedType(type) {
      return (type || '')
        .replace(/_/g, ' ')
        .toLowerCase()
        .replace(/\b\w/g, (c) => c.toUpperCase());
    },
    toggleExpand(policy) {
      this.expandedPolicyName = this.expandedPolicyName === policy.name ? null : policy.name;
    },
    isExpanded(policy) {
      return this.expandedPolicyName === policy.name;
    },
    parsedContent(policy) {
      return parsePolicyYaml(policy.yaml) || {};
    },
    policyRules(policy) {
      return this.parsedContent(policy).rules || [];
    },
    policyActions(policy) {
      return this.parsedContent(policy).actions || [];
    },
    ruleLabel(rule) {
      const def = RULE_TYPES.find((r) => r.id === rule.type);
      return def?.label || this.formattedType(rule.type);
    },
    actionLabel(action) {
      const id = action.type || action.scan;
      const def = ACTION_TYPES.find((a) => a.id === id);
      return def?.label || this.formattedType(id);
    },
    ruleFields({ type: _type, ...rest }) {
      return this.compactFields(rest);
    },
    actionFields({ type: _type, scan: _scan, ...rest }) {
      return this.compactFields(rest);
    },
    compactFields(fields) {
      return Object.fromEntries(
        Object.entries(fields).filter(([, v]) => {
          if (Array.isArray(v)) return v.length > 0;
          return v != null && v !== '';
        }),
      );
    },
    formatFieldValue(val) {
      if (Array.isArray(val)) return val.join(', ');
      if (typeof val === 'boolean') return String(val);
      if (typeof val === 'object' && val !== null) return JSON.stringify(val);
      return String(val ?? '');
    },
    rowMenuItems(policy) {
      return [
        {
          text: s__('SecurityOrchestration|Edit'),
          action: () => this.$emit('edit', policy),
        },
        {
          text: policy.enabled
            ? s__('SecurityOrchestration|Disable')
            : s__('SecurityOrchestration|Enable'),
          action: () => {},
        },
        {
          text: s__('SecurityOrchestration|Delete'),
          action: () => this.deletePolicy(policy),
          extraAttrs: { class: 'gl-text-danger' },
        },
      ];
    },
    async deletePolicy(policy) {
      this.deleteError = '';
      try {
        await this.$apollo.mutate({
          mutation: updatePolicyMutation,
          variables: {
            fullPath: this.namespacePath,
            mode: 'REMOVE',
            name: policy.name,
            policyYaml: policy.yaml,
          },
        });
        this.$apollo.queries.securityPolicies.refetch();
      } catch {
        this.deleteError = this.$options.i18n.deleteError;
      }
    },
  },
};
</script>

<template>
  <div class="gl-pt-6">
    <gl-alert v-if="fetchError" variant="danger" :dismissible="false" class="gl-mb-4">
      {{ fetchError }}
    </gl-alert>
    <gl-alert
      v-if="deleteError"
      variant="danger"
      dismissible
      class="gl-mb-4"
      @dismiss="deleteError = ''"
    >
      {{ deleteError }}
    </gl-alert>

    <div class="gl-mb-4 gl-flex gl-items-start gl-justify-between">
      <div>
        <h1 class="gl-heading-1 gl-mb-1">{{ $options.i18n.policies }}</h1>
        <p class="gl-mb-0 gl-text-secondary">{{ $options.i18n.subtitle }}</p>
      </div>
      <div class="gl-flex gl-gap-3">
        <gl-button :prepend-icon="'list-bulleted'" @click="() => {}">
          {{ $options.i18n.browseBundles }}
        </gl-button>
        <gl-button variant="confirm" @click="$emit('create')">
          {{ $options.i18n.newPolicy }}
        </gl-button>
      </div>
    </div>

    <gl-tabs v-model="activeTab">
      <gl-tab :title="$options.i18n.policies">
        <div class="gl-mt-4">
          <stats-bar
            :active-policies="statsData.activePolicies"
            :actions-this-week="statsData.actionsThisWeek"
            :catching="statsData.catching"
            :needs-attention="statsData.needsAttention"
            class="gl-mb-4"
          />

          <div class="gl-mb-4">
            <gl-search-box-by-type
              v-model="searchQuery"
              :placeholder="$options.i18n.filterPlaceholder"
              class="gl-w-64"
            />
          </div>

          <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-6" />

          <template v-else-if="filteredPolicies.length > 0">
            <div class="gl-border gl-overflow-hidden gl-rounded-base gl-border-default">
              <div
                v-for="policy in filteredPolicies"
                :key="policy.name"
                class="gl-border-b gl-border-default last:gl-border-b-0"
              >
                <!-- Clickable row header -->
                <div
                  data-testid="policy-row"
                  class="gl-flex gl-cursor-pointer gl-items-start gl-gap-3 gl-px-4 gl-py-3 hover:gl-bg-subtle"
                  @click="toggleExpand(policy)"
                >
                  <div class="gl-mt-px gl-shrink-0">
                    <gl-icon
                      :name="policy.enabled ? 'check-circle-filled' : 'circle'"
                      :class="policy.enabled ? 'gl-text-success' : 'gl-text-secondary'"
                      :size="16"
                    />
                  </div>

                  <div class="gl-min-w-0 gl-flex-1">
                    <div class="gl-mb-1 gl-flex gl-flex-wrap gl-items-center gl-gap-2">
                      <span class="gl-font-bold gl-text-blue-600">{{ policy.name }}</span>
                      <gl-badge :variant="statusVariant(policy)" size="sm">
                        {{ statusLabel(policy) }}
                      </gl-badge>
                      <gl-badge variant="info" size="sm">{{ formattedType(policy.type) }}</gl-badge>
                    </div>
                    <div
                      class="gl-flex gl-flex-wrap gl-items-center gl-gap-4 gl-text-sm gl-text-secondary"
                    >
                      <span v-if="policyRules(policy).length">
                        <gl-icon name="list-bulleted" :size="12" class="gl-mr-1" />
                        {{ policyRules(policy).length }}
                        {{ $options.i18n.rules.toLowerCase() }}
                      </span>
                      <span v-if="policyActions(policy).length">
                        <gl-icon name="play" :size="12" class="gl-mr-1" />
                        {{ policyActions(policy).length }}
                        {{ $options.i18n.actions.toLowerCase() }}
                      </span>
                      <time-ago-tooltip
                        v-if="policy.updatedAt"
                        :time="policy.updatedAt"
                        class="gl-text-sm"
                      />
                    </div>
                  </div>

                  <div class="gl-flex gl-shrink-0 gl-items-center gl-gap-1" @click.stop>
                    <gl-icon
                      :name="isExpanded(policy) ? 'chevron-up' : 'chevron-down'"
                      :size="16"
                      class="gl-text-secondary"
                    />
                    <gl-disclosure-dropdown
                      icon="ellipsis_v"
                      no-caret
                      :items="rowMenuItems(policy)"
                      placement="bottom-end"
                      @action="({ action }) => action()"
                    />
                  </div>
                </div>

                <!-- Inline expansion panel -->
                <div
                  v-if="isExpanded(policy)"
                  data-testid="policy-expansion-panel"
                  class="gl-border-t gl-border-default gl-bg-subtle gl-px-4 gl-pb-4 gl-pt-3"
                >
                  <!-- Rules -->
                  <div v-if="policyRules(policy).length" class="gl-mb-4">
                    <p class="gl-mb-2 gl-text-sm gl-font-bold">
                      {{ $options.i18n.rules }} ({{ policyRules(policy).length }})
                    </p>
                    <div class="gl-flex gl-flex-col gl-gap-2">
                      <div
                        v-for="(rule, i) in policyRules(policy)"
                        :key="i"
                        class="gl-border gl-rounded-base gl-border-default gl-bg-default gl-p-3"
                      >
                        <p class="gl-mb-1 gl-text-sm gl-font-bold">{{ ruleLabel(rule) }}</p>
                        <div class="gl-flex gl-flex-wrap gl-gap-x-5 gl-gap-y-1 gl-text-xs">
                          <span v-for="(val, key) in ruleFields(rule)" :key="key">
                            <span class="gl-text-secondary">{{ key }}:</span>
                            <span class="gl-ml-1 gl-font-bold">{{ formatFieldValue(val) }}</span>
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Actions -->
                  <div v-if="policyActions(policy).length" class="gl-mb-4">
                    <p class="gl-mb-2 gl-text-sm gl-font-bold">
                      {{ $options.i18n.actions }} ({{ policyActions(policy).length }})
                    </p>
                    <div class="gl-flex gl-flex-col gl-gap-2">
                      <div
                        v-for="(action, i) in policyActions(policy)"
                        :key="i"
                        class="gl-border gl-rounded-base gl-border-default gl-bg-default gl-p-3"
                      >
                        <p class="gl-mb-1 gl-text-sm gl-font-bold">{{ actionLabel(action) }}</p>
                        <div class="gl-flex gl-flex-wrap gl-gap-x-5 gl-gap-y-1 gl-text-xs">
                          <span v-for="(val, key) in actionFields(action)" :key="key">
                            <span class="gl-text-secondary">{{ key }}:</span>
                            <span class="gl-ml-1 gl-font-bold">{{ formatFieldValue(val) }}</span>
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="gl-flex gl-gap-3">
                    <gl-button size="small" @click="$emit('edit', policy)">
                      {{ $options.i18n.edit }}
                    </gl-button>
                    <gl-button
                      size="small"
                      variant="danger"
                      category="secondary"
                      @click="deletePolicy(policy)"
                    >
                      {{ $options.i18n.delete }}
                    </gl-button>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <gl-empty-state
            v-else
            :title="$options.i18n.noPoliciesFound"
            :description="$options.i18n.createFirstPolicy"
          >
            <template #actions>
              <gl-button variant="confirm" @click="$emit('create')">
                {{ $options.i18n.newPolicy }}
              </gl-button>
            </template>
          </gl-empty-state>
        </div>
      </gl-tab>

      <gl-tab :title="$options.i18n.bundles">
        <bundles-list class="gl-mt-4" />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
