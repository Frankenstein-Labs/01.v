<script>
import { GlBadge } from '@gitlab/ui';
import { TIERS } from '../constants';
import { healthVariant, healthLabel } from '../utils';

export default {
  name: 'EnvironmentBreakdown',
  components: {
    GlBadge,
  },
  props: {
    environments: {
      type: Array,
      required: true,
    },
  },
  computed: {
    groupedByTier() {
      const groups = this.environments.reduce((acc, env) => {
        const tier = env.tier ?? 'UNKNOWN';
        if (!acc[tier]) {
          acc[tier] = [];
        }
        acc[tier].push(env);
        return acc;
      }, {});
      const knownTiers = TIERS.filter(({ key }) => groups[key]?.length > 0).map(
        ({ key, label }) => ({
          tier: key,
          label,
          environments: groups[key],
        }),
      );
      const remainingTiers = Object.keys(groups)
        .filter((tier) => !TIERS.some((tierDef) => tierDef.key === tier))
        .map((tier) => ({ tier, label: tier, environments: groups[tier] }));
      return [...knownTiers, ...remainingTiers];
    },
  },
  methods: {
    healthVariant,
    healthLabel,
  },
};
</script>

<template>
  <div v-if="groupedByTier.length > 0" data-testid="environment-breakdown">
    <div
      v-for="group in groupedByTier"
      :key="group.tier"
      class="gl-mb-4"
      :data-testid="`tier-group-${group.tier}`"
    >
      <h4
        class="gl-mb-3 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary"
        data-testid="tier-heading"
      >
        {{ group.label }}
      </h4>
      <div class="gl-overflow-hidden gl-rounded-lg gl-border-1 gl-border-solid gl-border-default">
        <div
          v-for="(env, index) in group.environments"
          :key="env.id"
          class="gl-flex gl-items-center gl-gap-3 gl-px-4 gl-py-3 gl-text-sm"
          :class="{
            'gl-border-b-1 gl-border-default gl-border-b-solid':
              index < group.environments.length - 1,
          }"
          :data-testid="`env-row-${env.name}`"
        >
          <span class="gl-font-bold" data-testid="env-name">{{ env.name }}</span>
          <div class="gl-ml-auto gl-flex gl-items-center gl-gap-3">
            <span
              v-if="env.version"
              class="gl-font-monospace gl-text-subtle"
              data-testid="env-version"
            >
              {{ env.version }}
            </span>
            <gl-badge :variant="healthVariant(env.health)" size="sm" data-testid="env-health-badge">
              {{ healthLabel(env.health) }}
            </gl-badge>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
