<script>
import { GlButton } from '@gitlab/ui';
import ExploreAnalyticsDashboardDetails from '~/explore/analytics_dashboards/pages/details.vue';

export default {
  name: 'ExploreAnalyticsDashboardDetailsEE',
  components: {
    ExploreAnalyticsDashboardDetails,
    GlButton,
  },
  computed: {
    editPath() {
      return { name: 'dashboard-edit', params: { slug: this.$route.params.slug } };
    },
  },
};
</script>
<template>
  <explore-analytics-dashboard-details>
    <template #actions="{ isSystemDashboard }">
      <gl-button
        v-if="!isSystemDashboard"
        icon="pencil"
        :to="editPath"
        data-testid="dashboard-edit-button"
      >
        {{ __('Edit') }}
      </gl-button>
    </template>
  </explore-analytics-dashboard-details>
</template>
