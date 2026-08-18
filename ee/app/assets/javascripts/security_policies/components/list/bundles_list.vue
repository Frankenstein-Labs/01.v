<script>
import { GlBadge, GlIcon, GlSearchBoxByType, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
const MOCK_BUNDLES = [
  {
    id: '1',
    name: s__('SecurityOrchestration|Vulnerability SLA Management'),
    description: s__('SecurityOrchestration|Security baseline'),
    icon: 'shield',
    policyCount: 2,
    scope: { label: s__('SecurityOrchestration|All projects'), count: '1,247 projects' },
    status: 'active',
    activity: { blocked: 50, warned: 0 },
    source: 'GitLab',
    lastModified: { time: s__('SecurityOrchestration|5 weeks ago'), by: 'Priya Patel' },
  },
  {
    id: '2',
    name: s__('SecurityOrchestration|Security Baseline'),
    description: s__('SecurityOrchestration|Security baseline'),
    icon: 'shield',
    policyCount: 4,
    scope: { label: s__('SecurityOrchestration|All projects'), count: '1,247 projects' },
    status: 'active',
    activity: { blocked: 33, warned: 17 },
    source: 'GitLab',
    lastModified: { time: s__('SecurityOrchestration|3 weeks ago'), by: 'Sarah Chen' },
  },
  {
    id: '3',
    name: s__('SecurityOrchestration|Code Quality & Test Governance'),
    description: s__('SecurityOrchestration|Code review & branches'),
    icon: 'code',
    policyCount: 2,
    scope: { label: s__('SecurityOrchestration|All projects'), count: '1,247 projects' },
    status: 'active',
    activity: { blocked: 26, warned: 0 },
    source: 'GitLab',
    lastModified: { time: s__('SecurityOrchestration|2 weeks ago'), by: 'Sarah Chen' },
  },
  {
    id: '4',
    name: s__('SecurityOrchestration|Duo Code Review Governance'),
    description: s__('SecurityOrchestration|Code review & branches'),
    icon: 'tanuki-ai',
    policyCount: 2,
    scope: { label: s__('SecurityOrchestration|All projects'), count: '1,247 projects' },
    status: 'active',
    activity: { blocked: 12, warned: 31 },
    source: 'GitLab',
    lastModified: { time: s__('SecurityOrchestration|11 days ago'), by: 'Marcus Johnson' },
  },
  {
    id: '5',
    name: s__('SecurityOrchestration|Dependency Firewall'),
    description: s__('SecurityOrchestration|Supply chain security'),
    icon: 'shield',
    policyCount: 5,
    scope: { label: s__('SecurityOrchestration|2 groups'), count: '95 projects' },
    status: 'active',
    activity: { blocked: 21, warned: 11 },
    source: 'GitLab',
    lastModified: { time: s__('SecurityOrchestration|1 day ago'), by: 'Marcus Johnson' },
  },
];
/* eslint-enable @gitlab/require-i18n-strings */

export default {
  name: 'BundlesList',
  components: { GlBadge, GlIcon, GlSearchBoxByType, GlTableLite },
  TABLE_FIELDS: [
    { key: 'bundle', label: s__('SecurityOrchestration|Bundle') },
    { key: 'policies', label: s__('SecurityOrchestration|Policies'), thClass: 'gl-w-20' },
    { key: 'scope', label: s__('SecurityOrchestration|Scope'), thClass: 'gl-w-40' },
    { key: 'status', label: s__('SecurityOrchestration|Status'), thClass: 'gl-w-20' },
    { key: 'activity', label: s__('SecurityOrchestration|Activity (7d)'), thClass: 'gl-w-28' },
    { key: 'source', label: s__('SecurityOrchestration|Source'), thClass: 'gl-w-24' },
    { key: 'lastModified', label: s__('SecurityOrchestration|Last modified'), thClass: 'gl-w-36' },
    { key: 'actions', label: '', thClass: 'gl-w-10' },
  ],
  i18n: {
    filterPlaceholder: s__('SecurityOrchestration|Filter bundles…'),
    appliedBundles: s__('SecurityOrchestration|Applied bundles'),
    policiesUnderManagement: s__('SecurityOrchestration|Policies under management'),
    frameworksCovered: s__('SecurityOrchestration|Frameworks covered'),
    needsAttention: s__('SecurityOrchestration|Needs attention'),
    by: s__('SecurityOrchestration|by'),
  },
  data() {
    return {
      bundles: MOCK_BUNDLES,
      searchQuery: '',
      frameworksCoveredCount: 4,
      needsAttentionCount: 0,
    };
  },
  computed: {
    filteredBundles() {
      if (!this.searchQuery) return this.bundles;
      const q = this.searchQuery.toLowerCase();
      return this.bundles.filter((b) => b.name.toLowerCase().includes(q));
    },
    totalPolicies() {
      return this.bundles.reduce((sum, b) => sum + b.policyCount, 0);
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-4 gl-flex gl-gap-3">
      <div class="gl-border gl-flex-1 gl-rounded-base gl-border-default gl-p-4">
        <p class="gl-mb-1 gl-text-sm gl-text-secondary">{{ $options.i18n.appliedBundles }}</p>
        <p class="gl-text-2xl gl-mb-0 gl-font-bold">{{ bundles.length }}</p>
        <p class="gl-mb-0 gl-text-sm gl-text-secondary">
          {{ bundles.length }} {{ s__('SecurityOrchestration|bundles active') }}
        </p>
      </div>
      <div class="gl-border gl-flex-1 gl-rounded-base gl-border-default gl-p-4">
        <p class="gl-mb-1 gl-text-sm gl-text-secondary">
          {{ $options.i18n.policiesUnderManagement }}
        </p>
        <p class="gl-text-2xl gl-mb-0 gl-font-bold">{{ totalPolicies }}</p>
        <p class="gl-mb-0 gl-text-sm gl-text-secondary">
          {{ s__('SecurityOrchestration|managed by bundles') }}
        </p>
      </div>
      <div class="gl-border gl-flex-1 gl-rounded-base gl-border-default gl-p-4">
        <p class="gl-mb-1 gl-text-sm gl-text-secondary">{{ $options.i18n.frameworksCovered }}</p>
        <p class="gl-text-2xl gl-mb-0 gl-font-bold">{{ frameworksCoveredCount }}</p>
        <p class="gl-mb-0 gl-text-sm gl-text-secondary">
          {{ s__('SecurityOrchestration|compliance frameworks') }}
        </p>
      </div>
      <div class="gl-border gl-flex-1 gl-rounded-base gl-border-default gl-p-4">
        <p class="gl-mb-1 gl-text-sm gl-text-secondary">{{ $options.i18n.needsAttention }}</p>
        <p class="gl-text-2xl gl-mb-0 gl-font-bold">{{ needsAttentionCount }}</p>
        <p class="gl-mb-0 gl-text-sm gl-text-secondary">
          {{ s__('SecurityOrchestration|bundles with inactive policies') }}
        </p>
      </div>
    </div>

    <div class="gl-mb-4">
      <gl-search-box-by-type
        v-model="searchQuery"
        :placeholder="$options.i18n.filterPlaceholder"
        class="gl-w-64"
      />
    </div>

    <gl-table-lite
      :fields="$options.TABLE_FIELDS"
      :items="filteredBundles"
      hover
      tbody-tr-class="gl-cursor-pointer"
    >
      <template #cell(bundle)="{ item }">
        <div class="gl-flex gl-items-center gl-gap-3">
          <div
            class="gl-flex gl-h-8 gl-w-8 gl-items-center gl-justify-center gl-rounded-base gl-bg-subtle"
          >
            <gl-icon :name="item.icon" :size="16" class="gl-text-secondary" />
          </div>
          <div>
            <p class="gl-mb-0 gl-font-bold">{{ item.name }}</p>
            <p class="gl-mb-0 gl-text-xs gl-text-secondary">{{ item.description }}</p>
          </div>
        </div>
      </template>

      <template #cell(policies)="{ item }">
        <span class="gl-text-sm gl-font-bold">{{ item.policyCount }}</span>
      </template>

      <template #cell(scope)="{ item }">
        <div>
          <p class="gl-mb-0 gl-text-sm">{{ item.scope.label }}</p>
          <p class="gl-mb-0 gl-text-xs gl-text-secondary">{{ item.scope.count }}</p>
        </div>
      </template>

      <template #cell(status)="{ item }">
        <gl-badge variant="success" size="sm">{{ item.status }}</gl-badge>
      </template>

      <template #cell(activity)="{ item }">
        <div class="gl-flex gl-flex-col gl-gap-1">
          <span v-if="item.activity.blocked" class="gl-flex gl-items-center gl-gap-1">
            <gl-icon name="dash-circle" :size="12" class="gl-text-red-500" />
            <span class="gl-text-sm">{{ item.activity.blocked }}</span>
          </span>
          <span v-if="item.activity.warned" class="gl-flex gl-items-center gl-gap-1">
            <gl-icon name="warning" :size="12" class="gl-text-orange-500" />
            <span class="gl-text-sm">{{ item.activity.warned }}</span>
          </span>
        </div>
      </template>

      <template #cell(source)="{ item }">
        <gl-badge variant="info" size="sm">{{ item.source }}</gl-badge>
      </template>

      <template #cell(lastModified)="{ item }">
        <div>
          <p class="gl-mb-0 gl-text-sm">{{ item.lastModified.time }}</p>
          <p class="gl-mb-0 gl-text-xs gl-text-secondary">
            {{ $options.i18n.by }} {{ item.lastModified.by }}
          </p>
        </div>
      </template>

      <template #cell(actions)>
        <gl-icon name="ellipsis_v" class="gl-cursor-pointer gl-text-secondary" />
      </template>
    </gl-table-lite>
  </div>
</template>
