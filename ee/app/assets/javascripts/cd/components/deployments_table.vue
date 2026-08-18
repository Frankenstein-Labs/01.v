<script>
import { GlBadge, GlTableLite, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import {
  TH_CLASS,
  TD_CLASS,
  ROW_SELECTED_CLASS,
  ROW_RECENT_CLASS,
  EMPTY_PLACEHOLDER,
  TIERS,
  UNKNOWN_LABEL,
} from '../constants';
import {
  rolloutStateVariant,
  rolloutStateLabel,
  rolloutStateDotClass,
  buildRowClass,
} from '../utils';

const ID_FIELD = {
  key: 'id',
  label: s__('ContinuousDeployment|ID'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const VERSION_FIELD = {
  key: 'release',
  label: s__('ContinuousDeployment|Version'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const RELEASE_FIELD = {
  key: 'release',
  label: s__('ContinuousDeployment|Release'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const STATUS_FIELD = {
  key: 'status',
  label: s__('ContinuousDeployment|Status'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const CREATED_FIELD = {
  key: 'createdAt',
  label: s__('ContinuousDeployment|Created'),
  tdClass: `${TD_CLASS} gl-whitespace-nowrap gl-text-right !gl-text-secondary`,
  thClass: `${TH_CLASS} gl-whitespace-nowrap gl-text-right`,
};

export default {
  name: 'DeploymentsTable',
  components: {
    GlBadge,
    GlTableLite,
    TimeAgo,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    deployments: {
      type: Array,
      required: true,
    },
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    full: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedId: {
      type: String,
      required: false,
      default: null,
    },
    recentId: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['select'],
  computed: {
    tiers() {
      const present = [...new Set(this.environments.map((environment) => environment.tier))].filter(
        Boolean,
      );
      const known = TIERS.filter(({ key }) => present.includes(key));
      const unknown = present
        .filter((key) => !TIERS.some((tier) => tier.key === key))
        .map((key) => ({ key, label: key }));

      return [...known, ...unknown];
    },
    tierFields() {
      return this.tiers.map(({ key, label }) => ({
        key,
        label,
        tdClass: TD_CLASS,
        thClass: TH_CLASS,
      }));
    },
    fields() {
      if (!this.full) {
        return [ID_FIELD, VERSION_FIELD, STATUS_FIELD];
      }

      return [ID_FIELD, RELEASE_FIELD, STATUS_FIELD, ...this.tierFields, CREATED_FIELD];
    },
    environmentsByTier() {
      return this.deployments.reduce((map, deployment) => {
        const byTier = {};
        (deployment.rolloutEnvironments?.nodes ?? []).forEach((rolloutEnvironment) => {
          const { environment } = rolloutEnvironment;
          if (!environment?.tier) {
            return;
          }
          byTier[environment.tier] = byTier[environment.tier] ?? [];
          byTier[environment.tier].push(rolloutEnvironment);
        });
        map.set(deployment.id, byTier);
        return map;
      }, new Map());
    },
  },
  methods: {
    releaseName(deployment) {
      return deployment.versionSet?.name ?? EMPTY_PLACEHOLDER;
    },
    rolloutStateVariant,
    rolloutStateLabel,
    rolloutStateDotClass,
    environmentsForTier(deployment, tier) {
      return this.environmentsByTier.get(deployment.id)?.[tier] ?? [];
    },
    environmentStateLabel(rolloutEnvironment) {
      return rolloutStateLabel(rolloutEnvironment.state) || UNKNOWN_LABEL;
    },
    tierSlotName(tier) {
      return `cell(${tier})`;
    },
    rowClass(item) {
      return buildRowClass(item?.id, [
        [this.selectedId, ROW_SELECTED_CLASS],
        [this.recentId, ROW_RECENT_CLASS],
      ]);
    },
  },
  EMPTY_PLACEHOLDER,
};
</script>

<template>
  <gl-table-lite
    :items="deployments"
    :fields="fields"
    stacked="sm"
    :tbody-tr-class="rowClass"
    borderless
    data-testid="deployments-table"
    @row-clicked="$emit('select', $event)"
  >
    <template #cell(id)="{ item }">#{{ item.iid }}</template>

    <template #cell(release)="{ item }">{{ releaseName(item) }}</template>

    <template #cell(status)="{ item }">
      <gl-badge v-if="rolloutStateLabel(item.state)" :variant="rolloutStateVariant(item.state)">
        {{ rolloutStateLabel(item.state) }}
      </gl-badge>
    </template>

    <template v-for="tier in tiers" #[tierSlotName(tier.key)]="{ item }">
      <div :key="tier.key" class="gl-flex gl-flex-col gl-items-start gl-gap-1 gl-text-sm">
        <span
          v-for="rolloutEnvironment in environmentsForTier(item, tier.key)"
          :key="rolloutEnvironment.id"
          v-gl-tooltip
          :title="environmentStateLabel(rolloutEnvironment)"
          class="gl-flex gl-items-center gl-gap-2"
          data-testid="tier-environment"
        >
          <span
            :class="rolloutStateDotClass(rolloutEnvironment.state)"
            class="gl-inline-block gl-h-2 gl-w-2 gl-shrink-0 gl-rounded-full"
            data-testid="state-dot"
          ></span>
          {{ rolloutEnvironment.environment.name }}
        </span>
        <span v-if="!environmentsForTier(item, tier.key).length" class="gl-text-subtle">
          {{ $options.EMPTY_PLACEHOLDER }}
        </span>
      </div>
    </template>

    <template v-if="full" #cell(createdAt)="{ item }">
      <time-ago v-if="item.createdAt" :time="item.createdAt" />
    </template>
  </gl-table-lite>
</template>
