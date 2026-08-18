<script>
import IssuesDashboardApp from '~/issues/dashboard/components/issues_dashboard_app.vue';
import {
  OPERATORS_IS,
  TOKEN_TITLE_STATUS,
  TOKEN_TYPE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

const WorkItemStatusToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue');

export default {
  name: 'IssuesDashboardAppEE',
  components: {
    IssuesDashboardApp,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['hasStatusFeature'],
  computed: {
    searchTokens() {
      const tokens = [];

      if (this.glFeatures.workItemStatusOnDashboard && this.hasStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_STATUS,
          title: TOKEN_TITLE_STATUS,
          icon: 'status',
          token: WorkItemStatusToken,
          unique: true,
          operators: OPERATORS_IS,
          fetchAllStatuses: true,
        });
      }

      return tokens;
    },
  },
};
</script>

<template>
  <issues-dashboard-app :ee-search-tokens="searchTokens" />
</template>
