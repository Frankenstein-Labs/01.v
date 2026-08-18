<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'GoBack',
  components: {
    GlButton,
  },
  methods: {
    goBack() {
      this.$router.go(-1);
    },
  },
};
</script>

<template>
  <gl-button variant="confirm" class="gl-w-full" @click="goBack">
    {{ __('Go back') }}
  </gl-button>
</template>
