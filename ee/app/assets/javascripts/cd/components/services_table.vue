<script>
import { GlBadge, GlTableLite, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { TH_CLASS, TD_CLASS, EMPTY_PLACEHOLDER, TIERS, ROW_SELECTED_CLASS } from '../constants';
import {
  healthVariant,
  healthLabel,
  healthDotClass,
  worstServiceHealth,
  buildRowClass,
} from '../utils';

const NAME_FIELD = {
  key: 'name',
  label: s__('ContinuousDeployment|Service'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const STATUS_FIELD = {
  key: 'health',
  label: s__('ContinuousDeployment|Status'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const DEPLOYED_FIELD = {
  key: 'lastDeployedAt',
  label: s__('ContinuousDeployment|Deployed'),
  tdClass: `${TD_CLASS} gl-whitespace-nowrap gl-text-right !gl-text-secondary`,
  thClass: `${TH_CLASS} gl-whitespace-nowrap gl-text-right`,
};

export default {
  name: 'ServicesTable',
  components: {
    GlBadge,
    GlTableLite,
    TimeAgo,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    services: {
      type: Array,
      required: true,
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
  },
  emits: ['select'],
  computed: {
    serviceRows() {
      return this.services.map((service) => ({
        id: service.id,
        name: service.name,
        lastDeployedAt: service.lastDeployedAt,
        worstHealth: worstServiceHealth(service),
      }));
    },
    tiers() {
      const present = new Set();
      this.services.forEach((service) => {
        (service.serviceEnvironmentHealths?.nodes ?? []).forEach(({ environment }) => {
          if (environment?.tier) {
            present.add(environment.tier);
          }
        });
      });
      const known = TIERS.filter(({ key }) => present.has(key));
      const unknown = [...present]
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
        return [NAME_FIELD, DEPLOYED_FIELD];
      }

      return [NAME_FIELD, STATUS_FIELD, ...this.tierFields, DEPLOYED_FIELD];
    },
    environmentsByTier() {
      return this.services.reduce((map, service) => {
        const byTier = {};
        (service.serviceEnvironmentHealths?.nodes ?? []).forEach((node) => {
          const tier = node.environment?.tier;
          if (!tier) {
            return;
          }
          byTier[tier] = byTier[tier] ?? [];
          byTier[tier].push({
            id: node.id,
            name: node.environment?.name,
            health: node.health,
            version: node.deployedVersions?.nodes?.[0]?.name ?? null,
          });
        });
        map.set(service.id, byTier);
        return map;
      }, new Map());
    },
  },
  methods: {
    healthVariant,
    healthLabel,
    healthDotClass,
    rowClass(item) {
      return buildRowClass(item?.id, [[this.selectedId, ROW_SELECTED_CLASS]]);
    },
    environmentsForTier(service, tier) {
      return this.environmentsByTier.get(service.id)?.[tier] ?? [];
    },
    tierSlotName(tier) {
      return `cell(${tier})`;
    },
  },
  EMPTY_PLACEHOLDER,
};
</script>

<template>
  <gl-table-lite
    :items="serviceRows"
    :fields="fields"
    :tbody-tr-class="rowClass"
    stacked="sm"
    borderless
    data-testid="services-table"
    @row-clicked="$emit('select', $event)"
  >
    <template #cell(name)="{ item }">
      <span
        v-gl-tooltip
        :title="healthLabel(item.worstHealth)"
        class="gl-flex gl-items-center gl-gap-2"
        data-testid="service-name"
      >
        <span
          :class="healthDotClass(item.worstHealth)"
          class="gl-inline-block gl-h-2 gl-w-2 gl-shrink-0 gl-rounded-full"
          data-testid="health-dot"
        ></span>
        {{ item.name }}
      </span>
    </template>
    <template #cell(health)="{ item }">
      <gl-badge :variant="healthVariant(item.worstHealth)" data-testid="health-badge">{{
        healthLabel(item.worstHealth)
      }}</gl-badge>
    </template>
    <template v-for="tier in tiers" #[tierSlotName(tier.key)]="{ item }">
      <div :key="tier.key" class="gl-flex gl-flex-col gl-items-start gl-gap-1 gl-text-sm">
        <span
          v-for="environment in environmentsForTier(item, tier.key)"
          :key="environment.id"
          v-gl-tooltip
          :title="healthLabel(environment.health)"
          class="gl-flex gl-items-center gl-gap-2 gl-whitespace-nowrap"
          data-testid="tier-environment"
        >
          <span
            :class="healthDotClass(environment.health)"
            class="gl-inline-block gl-h-2 gl-w-2 gl-shrink-0 gl-rounded-full"
            data-testid="tier-health-dot"
          ></span>
          {{ environment.name }}
          <span v-if="environment.version" class="gl-text-subtle">{{ environment.version }}</span>
        </span>
        <span
          v-if="!environmentsForTier(item, tier.key).length"
          class="gl-text-subtle"
          data-testid="tier-empty"
        >
          {{ $options.EMPTY_PLACEHOLDER }}
        </span>
      </div>
    </template>
    <template #cell(lastDeployedAt)="{ item }">
      <time-ago v-if="item.lastDeployedAt" :time="item.lastDeployedAt" />
    </template>
  </gl-table-lite>
</template>
