<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import searchProjectsQueryWithDashboards from './graphql/search_projects_with_dashboards.query.graphql';
import searchGroupsQueryWithDashboards from './graphql/search_groups_with_dashboards.query.graphql';
import DashboardItemsList from './dashboard_items_list.vue';
import { hasDashboard } from './utils';

export default {
  name: 'DashboardSearchResults',
  components: {
    GlLoadingIcon,
    DashboardItemsList,
  },
  props: {
    searchTerm: {
      type: String,
      required: true,
    },
    dashboardName: {
      type: String,
      required: true,
    },
  },
  apollo: {
    projects: {
      debounce: DEBOUNCE_DELAY,
      query: searchProjectsQueryWithDashboards,
      variables() {
        return {
          search: this.searchTerm,
        };
      },
      skip() {
        return !this.searchTerm || this.notEnoughCharacters;
      },
      update(data) {
        return (
          data?.projects?.nodes?.filter((project) => hasDashboard(project, this.dashboardName)) ||
          []
        );
      },
    },
    groups: {
      debounce: DEBOUNCE_DELAY,
      query: searchGroupsQueryWithDashboards,
      variables() {
        return {
          search: this.searchTerm,
        };
      },
      skip() {
        return !this.searchTerm || this.notEnoughCharacters;
      },
      update(data) {
        return (
          data?.currentUser?.groups?.nodes?.filter((group) =>
            hasDashboard(group, this.dashboardName),
          ) || []
        );
      },
    },
  },
  data() {
    return {
      projects: [],
      groups: [],
    };
  },
  computed: {
    notEnoughCharacters() {
      return this.searchTerm.length < 2;
    },
    loading() {
      return this.$apollo.queries.projects.loading || this.$apollo.queries.groups.loading;
    },
    formattedProjects() {
      return this.projects.map((project) => ({
        id: project.id,
        name: project.name,
        namespace: project.nameWithNamespace,
        avatarUrl: project.avatarUrl,
        fullPath: project.fullPath,
      }));
    },
    formattedGroups() {
      return this.groups.map((group) => ({
        id: group.id,
        name: group.name,
        namespace: group.fullName,
        avatarUrl: group.avatarUrl,
        fullPath: group.fullPath,
      }));
    },
    hasResults() {
      return this.projects.length > 0 || this.groups.length > 0;
    },
    showNoResults() {
      return !this.loading && !this.hasResults && this.searchTerm.length >= 2;
    },
    searchStatus() {
      if (this.loading) {
        return s__('Dashboards|Searching for groups and projects');
      }

      if (this.notEnoughCharacters) {
        return this.$options.i18n.minCharacters;
      }

      if (this.showNoResults) {
        return this.$options.i18n.noResults;
      }

      if (this.formattedProjects.length || this.formattedGroups.length) {
        return sprintf(s__('Dashboards|Search found %{groups} groups and %{projects} projects'), {
          groups: this.formattedGroups.length,
          projects: this.formattedProjects.length,
        });
      }
      return '';
    },
  },
  i18n: {
    noResults: s__('Dashboards|No projects or groups found'),
    minCharacters: s__('Dashboards|Type at least 2 characters to search'),
  },
};
</script>

<template>
  <div>
    <div role="status" aria-atomic="true" class="gl-sr-only">
      {{ searchStatus }}
    </div>
    <gl-loading-icon v-if="loading" size="lg" class="gl-my-6" />
    <div v-else-if="notEnoughCharacters" class="gl-p-4 gl-text-center gl-text-subtle">
      {{ $options.i18n.minCharacters }}
    </div>
    <div v-else-if="showNoResults" class="gl-p-4 gl-text-center gl-text-subtle">
      {{ $options.i18n.noResults }}
    </div>
    <ul v-else class="gl-m-0 gl-list-none gl-p-0 gl-pt-2">
      <dashboard-items-list
        v-if="formattedProjects.length > 0"
        :empty-state-text="s__('Dashboards|No projects found')"
        :group-name="s__(`Dashboards|Projects I'm a member of`)"
        :items="formattedProjects"
        :is-group="false"
        :dashboard-name="dashboardName"
      />
      <dashboard-items-list
        v-if="formattedGroups.length > 0"
        :empty-state-text="s__('Dashboards|No groups found')"
        :group-name="s__(`Dashboards|Groups I'm a member of`)"
        :items="formattedGroups"
        is-group
        :dashboard-name="dashboardName"
        bordered
        class="gl-mt-3"
      />
    </ul>
  </div>
</template>
