<script>
import { defineComponent } from 'vue';
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';

export default defineComponent({
  name: 'OrbitAdminConfigureButton',
  compatConfig: { MODE: 3 },
  components: { GlButton },
  i18n: {
    configure: s__('Orbit|Configure'),
  },
  props: {
    adminConfigurationPath: {
      type: String,
      required: true,
    },
  },
});
</script>

<template>
  <gl-button
    size="small"
    icon="settings"
    category="tertiary"
    :href="adminConfigurationPath"
    data-testid="orbit-configure-admin-btn"
  >
    {{ $options.i18n.configure }}
  </gl-button>
</template>
