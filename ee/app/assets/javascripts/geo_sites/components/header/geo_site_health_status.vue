<script>
import { GlBadge } from '@gitlab/ui';
import { HEALTH_STATUS_UI } from 'ee/geo_sites/constants';

export default {
  name: 'GeoSiteHealthStatus',
  components: {
    GlBadge,
  },
  props: {
    status: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    statusUi() {
      return this.status ? HEALTH_STATUS_UI[this.status.toLowerCase()] : HEALTH_STATUS_UI.unknown;
    },
  },
};
</script>

<template>
  <gl-badge :variant="statusUi.variant" :icon="statusUi.icon" class="!gl-font-bold">
    {{ statusUi.text }}
  </gl-badge>
</template>
