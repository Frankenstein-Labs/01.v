<script>
import { GlCard } from '@gitlab/ui';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';

export default {
  name: 'FormSection',
  components: {
    GlCard,
    SettingsSection,
  },
  props: {
    title: {
      type: String,
      required: false,
      default: null,
    },
    isDisplay: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <gl-card v-if="isDisplay">
    <template #header>
      <h3 class="gl-m-0 gl-text-base">{{ title }}</h3>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-5">
      <slot></slot>
    </div>
  </gl-card>
  <settings-section v-else :heading="title">
    <div class="gl-flex gl-flex-col gl-gap-5">
      <slot></slot>
    </div>
  </settings-section>
</template>
