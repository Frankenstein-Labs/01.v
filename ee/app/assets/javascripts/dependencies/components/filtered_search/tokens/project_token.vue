<script>
import { debounce } from 'lodash-es';
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { extractGroupNamespace } from 'ee/dependencies/store/utils';
import getProjects from 'ee/dependencies/graphql/projects.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlIntersperse,
  },
  mixins: [glListenersMixin],
  inject: ['endpoint'],
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
  emits: ['input'],
  data() {
    return {
      searchTerm: '',
      projects: [],
      selectedProjects: [],
      isLoadingProjects: true,
    };
  },
  computed: {
    groupNamespace() {
      return extractGroupNamespace(this.endpoint);
    },
    selectedProjectNames() {
      return this.selectedProjects.map(({ name }) => name);
    },
    selectedProjectIds() {
      return this.selectedProjects.map(({ id }) => getIdFromGraphQLId(id));
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedProjectNames,
      };
    },
  },
  created() {
    this.fetchProjects();
  },
  methods: {
    async fetchProjects() {
      try {
        const { data } = await this.$apollo.query({
          query: getProjects,
          variables: {
            groupFullPath: this.groupNamespace,
            search: this.searchTerm,
            first: 50,
            includeSubgroups: true,
          },
        });

        this.projects = data.group.projects.nodes;
      } catch {
        createAlert({
          message: this.$options.i18n.fetchErrorMessage,
        });
      } finally {
        this.isLoadingProjects = false;
      }
    },
    isProjectSelected(project) {
      return this.selectedProjects.some((p) => p.id === project.id);
    },
    toggleSelectedProject(project) {
      if (this.isProjectSelected(project)) {
        this.selectedProjects = this.selectedProjects.filter((p) => p.id !== project.id);
      } else {
        this.selectedProjects.push(project);
      }
    },
    handleInput(token) {
      // the dropdown shows a list of project names but we need to emit the project ids for filtering
      this.$emit('input', { ...token, data: this.selectedProjectIds });
    },
    setSearchTerm: debounce(function debouncedSetSearchTerm({ data }) {
      // the data can be either a string or an array, in which case we don't want to perform the search
      if (typeof data === 'string') {
        this.searchTerm = data.length >= 3 ? data : '';

        // since apollo caches the results, we can trigger a fetch every time the search term changes
        // and requests will only be made if there is no existing data for the current term
        this.fetchProjects();
      }
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
  },
  i18n: {
    fetchErrorMessage: s__(
      'Dependencies|There was an error fetching the projects for this group. Please try again later.',
    ),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedProjectNames"
    :value="tokenValue"
    v-on="{ ...glListeners(), input: handleInput }"
    @select="toggleSelectedProject"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-intersperse data-testid="selected-projects">
        <span v-for="selectedProjectName in selectedProjectNames" :key="selectedProjectName">{{
          selectedProjectName
        }}</span>
      </gl-intersperse>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoadingProjects" size="sm" />
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="project in projects"
          :key="project.id"
          :value="project"
        >
          <div class="gl-flex gl-items-center">
            <gl-icon
              v-if="config.multiSelect"
              name="check"
              class="gl-mr-3 gl-shrink-0"
              :class="{ 'gl-invisible': !isProjectSelected(project) }"
              variant="subtle"
            />
            {{ project.name }}
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
