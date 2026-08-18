<script>
import { GlCard, GlTable, GlBadge, GlSprintf, GlIcon, GlSkeletonLoader } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { s__, __ } from '~/locale';
import {
  MODE_ENFORCE,
  ICON_BLOCKED,
  ICON_WARNED,
  RULE_TYPE_LABELS,
  RULE_TYPE_UNKNOWN_LABEL,
} from '../constants';

export default {
  name: 'RuleActivityTable',
  components: {
    GlCard,
    GlTable,
    GlBadge,
    GlSprintf,
    GlIcon,
    GlSkeletonLoader,
    TimeAgoTooltip,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  fields: [
    { key: 'rule', label: s__('DependencyFirewall|Rule') },
    { key: 'mode', label: s__('DependencyFirewall|Mode') },
    { key: 'status', label: __('Status') },
    { key: 'activity', label: s__('DependencyFirewall|Activity') },
    { key: 'lastModified', label: s__('DependencyFirewall|Last modified') },
  ],
  methods: {
    isEnforce(rule) {
      return rule.mode === MODE_ENFORCE;
    },
    activityIcon(rule) {
      return this.isEnforce(rule) ? ICON_BLOCKED : ICON_WARNED;
    },
    activityIconClass(rule) {
      return this.isEnforce(rule) ? 'gl-text-danger' : 'gl-text-warning';
    },
    ruleTypeLabel(type) {
      return RULE_TYPE_LABELS[type] || RULE_TYPE_UNKNOWN_LABEL;
    },
  },
};
</script>

<template>
  <gl-card body-class="gl-px-5 gl-pt-5 gl-pb-2">
    <template #header>
      <h2 class="gl-m-0 gl-text-base gl-font-bold">{{ s__('DependencyFirewall|Policies') }}</h2>
    </template>

    <gl-table
      :items="items"
      :fields="$options.fields"
      :empty-text="s__('DependencyFirewall|No active dependency firewall rules.')"
      :busy="loading"
      show-empty
      stacked="md"
      borderless
      class="gl-border-t-1 gl-border-default gl-border-t-solid"
      data-testid="dependency-firewall-rules-table"
    >
      <template #table-busy>
        <gl-skeleton-loader />
      </template>

      <template #cell(rule)="{ item }">
        <span class="gl-font-bold">{{ item.policyName }}</span>
        <div class="gl-text-subtle">{{ ruleTypeLabel(item.ruleType) }}</div>
      </template>

      <template #cell(mode)="{ item }">
        <gl-badge :variant="isEnforce(item) ? 'danger' : 'warning'">
          {{ isEnforce(item) ? s__('DependencyFirewall|Enforce') : s__('DependencyFirewall|Warn') }}
        </gl-badge>
      </template>

      <template #cell(status)="{ item }">
        <gl-badge :variant="item.enabled ? 'success' : 'neutral'">
          {{ item.enabled ? __('Enabled') : __('Disabled') }}
        </gl-badge>
      </template>

      <template #cell(activity)="{ item }">
        <span class="gl-inline-flex gl-items-center gl-gap-2">
          <gl-icon :name="activityIcon(item)" :class="activityIconClass(item)" />
          {{ item.activityCount }}
        </span>
      </template>

      <template #cell(lastModified)="{ item }">
        <template v-if="item.lastModified && item.lastModified.at">
          <time-ago-tooltip :time="item.lastModified.at" />
          <div v-if="item.lastModified.by" class="gl-text-subtle">
            <gl-sprintf :message="s__('DependencyFirewall|By %{name}')">
              <template #name>{{ item.lastModified.by.name }}</template>
            </gl-sprintf>
          </div>
        </template>
      </template>
    </gl-table>
  </gl-card>
</template>
