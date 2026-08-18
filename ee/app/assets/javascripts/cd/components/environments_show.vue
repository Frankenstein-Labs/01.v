<script>
import { sprintf, s__ } from '~/locale';

export default {
  name: 'EnvironmentsShow',
  computed: {
    environmentId() {
      return this.$route.params.id;
    },
    heading() {
      return sprintf(s__('ContinuousDeployment|Environment %{id}'), { id: this.environmentId });
    },
  },
};
</script>
<template>
  <h2>{{ heading }}</h2>
</template>
