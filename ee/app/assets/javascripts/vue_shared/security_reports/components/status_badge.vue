<script>
import { GlBadge, GlLoadingIcon } from '@gitlab/ui';

import { VULNERABILITY_STATES } from 'ee/vulnerabilities/constants';

export const VARIANTS = {
  confirmed: 'danger',
  resolved: 'success',
  detected: 'warning',
  dismissed: 'neutral',
};

export default {
  name: 'StatusBadge',
  components: {
    GlBadge,
    GlLoadingIcon,
  },
  props: {
    state: {
      type: String,
      required: true,
      validator: (state) => Object.keys(VARIANTS).includes(state),
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    stateName() {
      return VULNERABILITY_STATES[this.state];
    },
    stateVariant() {
      return VARIANTS[this.state];
    },
  },
};
</script>

<template>
  <gl-badge :variant="stateVariant">
    <gl-loading-icon v-if="loading" size="sm" class="gl-mx-5" />
    <template v-else>{{ stateName }}</template>
  </gl-badge>
</template>
