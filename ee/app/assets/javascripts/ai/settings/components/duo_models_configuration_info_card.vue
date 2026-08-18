<script>
import { GlButton, GlCard } from '@gitlab/ui';

export default {
  name: 'DuoModelsConfigurationInfoCard',
  components: {
    GlButton,
    GlCard,
  },
  props: {
    duoModelsConfigurationProps: {
      type: Object,
      required: true,
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-heading-scale-300"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
  >
    <template #header>
      <h3 class="gl-m-0">{{ duoModelsConfigurationProps.header }}</h3>
    </template>
    <template #default>
      <p data-testid="model-configuration-card-description" class="gl-mb-0">
        {{ duoModelsConfigurationProps.description }}
      </p>
    </template>
    <template #footer>
      <div>
        <gl-button :to="duoModelsConfigurationProps.path" category="primary">
          {{ duoModelsConfigurationProps.buttonText }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
