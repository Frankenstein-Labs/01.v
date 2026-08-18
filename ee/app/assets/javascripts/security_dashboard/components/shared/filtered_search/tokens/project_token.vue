<script>
import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { createAlert } from '~/alert';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import {
  DASHBOARD_TYPE_GROUP,
  DASHBOARD_TYPE_INSTANCE,
  DASHBOARD_TYPE_ORGANIZATION,
} from 'ee/security_dashboard/constants';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import groupProjectsQuery from 'ee/security_dashboard/graphql/queries/group_projects.query.graphql';
import instanceProjectsQuery from 'ee/security_dashboard/graphql/queries/instance_projects.query.graphql';
import organizationProjectsQuery from 'ee/security_dashboard/graphql/queries/organization_projects.query.graphql';
import SearchSuggestion from '../components/search_suggestion.vue';

const QUERIES = {
  [DASHBOARD_TYPE_GROUP]: groupProjectsQuery,
  [DASHBOARD_TYPE_INSTANCE]: instanceProjectsQuery,
  [DASHBOARD_TYPE_ORGANIZATION]: organizationProjectsQuery,
};

export default {
  components: {
    GlFilteredSearchToken,
    SearchSuggestion,
    GlLoadingIcon,
  },
  mixins: [glListenersMixin],
  inject: ['groupFullPath', 'dashboardType'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    const data = this.value?.data;
    let selectedProjectIds = [];

    if (Array.isArray(data)) {
      selectedProjectIds = data.map(Number);
    }

    return {
      projects: [],
      selectedProjectIds,
      isLoadingProjects: false,
      searchTerm: '',
    };
  },
  computed: {
    groupNamespace() {
      return this.groupFullPath;
    },
    selectedProjects() {
      return this.projects.filter(({ rawId }) => this.selectedProjectIds.includes(rawId));
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedProjectIds,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.projects.map((p) => ({ text: p.name, id: p.rawId })),
        selected: this.selectedProjectIds,
        maxOptionsShown: 1, // Project names can be long. Limit to 1.
      });
    },
  },
  created() {
    this.fetchProjects();
  },
  methods: {
    async fetchProjects() {
      try {
        this.isLoadingProjects = true;

        const { data } = await this.$apollo.query({
          query: QUERIES[this.dashboardType],
          variables: {
            fullPath: this.groupNamespace,
            search: this.searchTerm,
            pageSize: 100,
          },
        });

        this.projects = data[this.dashboardType].projects.edges.map(({ node }) => ({
          ...node,
          rawId: getIdFromGraphQLId(node.id),
        }));

        this.projects.sort((p1, p2) => p1.name.localeCompare(p2.name));
      } catch {
        createAlert({
          message: this.$options.i18n.fetchErrorMessage,
        });
      } finally {
        this.isLoadingProjects = false;
      }
    },
    resetSelected() {
      this.selectedProjectIds = [];
    },
    isProjectSelected(rawProjectId) {
      return this.selectedProjectIds.some((id) => id === rawProjectId);
    },
    toggleSelectedProject(rawProjectId) {
      if (this.isProjectSelected(rawProjectId)) {
        this.selectedProjectIds = this.selectedProjectIds.filter((id) => id !== rawProjectId);
      } else {
        this.selectedProjectIds.push(rawProjectId);
      }
    },
    setSearchTerm: debounce(function debouncedSetSearchTerm({ data }) {
      // when the user is doing a search, we receive a string. If they
      // click on dropdown items we receive an array. For this reason, we can
      // safely ignore non-string data.
      if (typeof data === 'string') {
        this.searchTerm = data.length >= 3 ? data : '';

        // since apollo caches the results, we can trigger a fetch every time the search term changes
        // and requests will only be made if there is no existing data for the current term
        this.fetchProjects();
      }
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
  },
  i18n: {
    label: __('Project'),
    fetchErrorMessage: s__(
      'SecurityReports|There was an error fetching the projects. Please try again later.',
    ),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedProjectIds"
    :value="tokenValue"
    v-on="glListeners()"
    @destroy="resetSelected"
    @select="toggleSelectedProject"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-loading-icon v-if="isLoadingProjects && !toggleText" size="sm" />
      {{ toggleText }}
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoadingProjects" size="sm" />
      <template v-else>
        <search-suggestion
          v-for="project in projects"
          :key="project.id"
          :value="project.rawId"
          :text="project.name"
          :selected="isProjectSelected(project.rawId)"
          :data-testid="`suggestion-${project.rawId}`"
        />
      </template>
    </template>
  </gl-filtered-search-token>
</template>
