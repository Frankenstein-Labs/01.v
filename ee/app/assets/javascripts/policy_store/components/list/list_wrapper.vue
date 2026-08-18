<script>
import { GlBadge, GlButton, GlEmptyState, GlLink, GlLoadingIcon, GlTable } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { POLICY_STATUS_ACTIVE } from '../../constants';
import StatsBar from './stats_bar.vue';
import { modeLabel, modeVariant, statusLabel, statusVariant, scopeLabel } from './utils';

export default {
  name: 'ListWrapper',
  components: {
    GlBadge,
    GlButton,
    GlEmptyState,
    GlLink,
    GlLoadingIcon,
    GlTable,
    TimeAgoTooltip,
    StatsBar,
  },
  fields: [
    { key: 'name', label: __('Name'), sortable: true, tdClass: 'gl-font-bold gl-content-center' },
    { key: 'type', label: __('Type'), sortable: true, tdClass: 'gl-content-center' },
    { key: 'mode', label: s__('PolicyStore|Mode'), sortable: true, tdClass: 'gl-content-center' },
    { key: 'status', label: __('Status'), sortable: true, tdClass: 'gl-content-center' },
    {
      key: 'scopedProjectsCount',
      label: s__('PolicyStore|Scope'),
      sortable: true,
      tdClass: 'gl-content-center',
    },
    {
      key: 'updated_at',
      label: s__('PolicyStore|Last updated'),
      sortable: true,
      tdClass: 'gl-content-center',
    },
  ],
  i18n: {
    policies: s__('PolicyStore|Policies'),
    createNewPolicy: s__('PolicyStore|Create new policy'),
    emptyStateTitle: s__('PolicyStore|No policies found'),
    emptyStateDescription: s__(
      'PolicyStore|Create a policy to enforce rules for deployments across your organization.',
    ),
  },
  inject: ['emptyListSvgPath'],
  props: {
    policies: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    error: {
      type: Boolean,
      required: false,
      default: false,
    },
    evaluationsThisWeek: {
      type: Number,
      required: false,
      default: 0,
    },
    newPolicyPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    activePoliciesCount() {
      return this.policies.filter(({ status }) => status === POLICY_STATUS_ACTIVE).length;
    },
  },
  methods: {
    modeLabel,
    modeVariant,
    statusLabel,
    statusVariant,
    scopeLabel,
  },
};
</script>

<template>
  <div class="gl-pt-6">
    <stats-bar
      :active-policies="activePoliciesCount"
      :evaluations-this-week="evaluationsThisWeek"
      class="gl-mb-6"
    />

    <div class="gl-mb-4 gl-flex gl-items-center gl-justify-between">
      <h2 data-testid="policies-heading" class="gl-heading-2 gl-mb-0">
        {{ $options.i18n.policies }}
      </h2>
      <gl-button variant="confirm" :href="newPolicyPath">
        {{ $options.i18n.createNewPolicy }}
      </gl-button>
    </div>

    <gl-table
      v-if="!error"
      :items="policies"
      :fields="$options.fields"
      :busy="loading"
      hover
      stacked="md"
      show-empty
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-my-5" data-testid="policies-loading" />
      </template>

      <template #empty>
        <gl-empty-state
          :svg-path="emptyListSvgPath"
          :svg-height="150"
          :title="$options.i18n.emptyStateTitle"
          :description="$options.i18n.emptyStateDescription"
          data-testid="policies-empty-state"
        >
          <template #actions>
            <gl-button
              variant="confirm"
              :href="newPolicyPath"
              data-testid="empty-state-create-button"
            >
              {{ $options.i18n.createNewPolicy }}
            </gl-button>
          </template>
        </gl-empty-state>
      </template>

      <template #cell(name)="{ item }">
        <gl-link :href="item.detailPath">{{ item.name }}</gl-link>
      </template>

      <template #cell(type)="{ item }">
        <gl-badge variant="neutral">{{ item.type }}</gl-badge>
      </template>

      <template #cell(mode)="{ item }">
        <gl-badge :variant="modeVariant(item.mode)">{{ modeLabel(item.mode) }}</gl-badge>
      </template>

      <template #cell(status)="{ item }">
        <gl-badge :variant="statusVariant(item.status)">{{ statusLabel(item.status) }}</gl-badge>
      </template>

      <template #cell(scopedProjectsCount)="{ item }">
        {{ scopeLabel(item.scopedProjectsCount) }}
      </template>

      <template #cell(updated_at)="{ item }">
        <time-ago-tooltip v-if="item.updated_at" :time="item.updated_at" />
        <span v-else>—</span>
      </template>
    </gl-table>
  </div>
</template>
