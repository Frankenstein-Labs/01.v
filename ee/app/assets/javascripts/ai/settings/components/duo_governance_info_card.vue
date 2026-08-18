<script>
import { GlButton, GlCard } from '@gitlab/ui';

export default {
  name: 'DuoGovernanceInfoCard',
  components: {
    GlButton,
    GlCard,
  },
  inject: {
    duoGovernancePath: {},
  },
};
</script>
<template>
  <gl-card header-class="gl-heading-scale-300" footer-class="gl-bg-transparent gl-border-none">
    <template #header>
      <h3 class="gl-m-0" data-testid="duo-governance-info-card-header">
        {{ s__('AiPowered|Governance') }}
      </h3>
    </template>
    <template #default>
      <p class="gl-mb-0" data-testid="duo-governance-info-card-description">
        {{ s__('AiPowered|Control how your AI-powered features are used.') }}
      </p>
    </template>
    <template #footer>
      <div data-testid="duo-governance-info-card-action">
        <gl-button category="primary" variant="default" :href="duoGovernancePath">
          {{ s__('AiPowered|Change governance') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
