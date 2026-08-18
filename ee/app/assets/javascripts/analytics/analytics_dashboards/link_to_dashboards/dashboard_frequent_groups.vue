<script>
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import currentUserFrecentGroupsQueryWithDashboards from './graphql/current_user_frecent_groups_with_dashboards.query.graphql';
import DashboardItemsList from './dashboard_items_list.vue';
import { hasDashboard } from './utils';

export default {
  name: 'DashboardFrequentGroups',
  components: {
    DashboardItemsList,
  },
  props: {
    dashboardName: {
      type: String,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    frecentGroups: {
      query: currentUserFrecentGroupsQueryWithDashboards,
      debounce: DEBOUNCE_DELAY,
    },
  },
  computed: {
    items() {
      return this.frecentGroups?.filter((group) => hasDashboard(group, this.dashboardName)) || [];
    },
  },
};
</script>

<template>
  <dashboard-items-list
    :loading="$apollo.queries.frecentGroups.loading"
    :empty-state-text="s__('Dashboards|Groups you visit often will appear here.')"
    :group-name="s__('Dashboards|Frequently visited groups')"
    :items="items"
    is-group
    :dashboard-name="dashboardName"
  />
</template>
