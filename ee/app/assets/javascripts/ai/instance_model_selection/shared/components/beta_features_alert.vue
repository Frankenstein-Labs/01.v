<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';

export default {
  name: 'BetaFeaturesAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
  },
  inject: ['duoConfigurationSettingsPath'],
  props: {
    message: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div class="gl-pb-4 gl-pt-2">
    <gl-alert variant="info" :dismissible="false">
      <gl-sprintf :message="message">
        <template #link="{ content }">
          <gl-link :href="duoConfigurationSettingsPath">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
  </div>
</template>
