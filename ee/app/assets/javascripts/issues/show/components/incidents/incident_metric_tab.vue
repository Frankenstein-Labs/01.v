<script>
import MetricImagesTab from '~/vue_shared/components/metric_images/metric_images_tab.vue';
import service from 'ee_component/issues/show/components/incidents/service';

export default {
  name: 'IncidentMetricTab',
  components: {
    MetricImagesTab,
  },
  provide: {
    metricImagesService: service,
  },
};
</script>

<template>
  <metric-images-tab />
</template>
