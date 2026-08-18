<script>
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import currentUserFrecentProjectsQueryWithDashboards from './graphql/current_user_frecent_projects_with_dashboards.query.graphql';
import DashboardItemsList from './dashboard_items_list.vue';
import { hasDashboard } from './utils';

export default {
  name: 'DashboardFrequentProjects',
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
    frecentProjects: {
      query: currentUserFrecentProjectsQueryWithDashboards,
      debounce: DEBOUNCE_DELAY,
    },
  },
  computed: {
    items() {
      return (
        this.frecentProjects?.filter((project) => hasDashboard(project, this.dashboardName)) || []
      );
    },
  },
};
</script>

<template>
  <dashboard-items-list
    :loading="$apollo.queries.frecentProjects.loading"
    :empty-state-text="s__('Dashboards|Projects you visit often will appear here.')"
    :group-name="s__('Dashboards|Frequently visited projects')"
    :items="items"
    :is-group="false"
    :dashboard-name="dashboardName"
  />
</template>
