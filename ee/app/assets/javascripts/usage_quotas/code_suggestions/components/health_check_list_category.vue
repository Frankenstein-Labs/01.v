<script>
import HealthCheckListProbe from './health_check_list_probe.vue';

export default {
  name: 'HealthCheckListCategory',
  components: {
    HealthCheckListProbe,
  },
  props: {
    category: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <article>
    <header class="gl-mb-2 gl-font-bold gl-text-subtle">
      {{ category.title }}
    </header>
    <p class="gl-mb-0 gl-text-subtle">
      {{ category.description }}
    </p>

    <health-check-list-probe
      v-for="(probe, index) in category.probes"
      :key="index"
      :probe="probe"
    />
  </article>
</template>
