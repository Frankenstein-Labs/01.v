<script>
import { GlAvatar, GlCollapsibleListbox, GlTruncate, GlTooltipDirective } from '@gitlab/ui';
import produce from 'immer';
import { __ } from '~/locale';
import { PAGE_SIZE } from 'ee/security_orchestration/constants';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';
import { isProject } from 'ee/security_orchestration/components/utils';
import getProjectSPPSuggestions from '../../graphql/queries/get_project_spp_suggestions.query.graphql';
import getGroupSPPSuggestions from '../../graphql/queries/get_group_spp_suggestions.query.graphql';

const defaultPageInfo = { endCursor: '', hasNextPage: false };

export default {
  name: 'SppSelector',
  AVATAR_SHAPE_OPTION_RECT,
  MINIMUM_QUERY_LENGTH: 3,
  SEARCH_ERROR: 'SEARCH_ERROR',
  QUERY_TOO_SHORT_ERROR: 'QUERY_TOO_SHORT_ERROR',
  NO_RESULTS_ERROR: 'NO_RESULTS_ERROR',
  i18n: {
    searchPlaceholder: __('Search by full path'),
    defaultPlaceholder: __('Choose a project'),
    errorNetworkMessage: __('Something went wrong, unable to search projects'),
    noResultsText: __('Sorry, no projects matched your search'),
    searchText: __('Enter at least three characters to search'),
  },
  apollo: {
    projects: {
      query() {
        return isProject(this.namespaceType) ? getProjectSPPSuggestions : getGroupSPPSuggestions;
      },
      variables() {
        return {
          search: this.searchQuery,
          first: PAGE_SIZE,
          fullPath: this.namespacePath,
          onlyLinked: this.onlyLinked,
        };
      },
      update(data = {}) {
        return data[this.namespaceType]?.securityPolicyProjectSuggestions?.nodes || [];
      },
      result({ data = {} }) {
        const projects = data[this.namespaceType]?.securityPolicyProjectSuggestions || {};

        this.pageInfo = projects.pageInfo || defaultPageInfo;

        if (projects.nodes?.length === 0) {
          this.setErrorType(this.$options.NO_RESULTS_ERROR);
        }

        this.searching = false;
      },
      error() {
        this.fetchProjectsError();
      },
      skip() {
        return this.isSearchQueryTooShort;
      },
    },
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatar,
    GlCollapsibleListbox,
    GlTruncate,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    headerText: {
      type: String,
      required: false,
      default: __('Select a project'),
    },
    onlyLinked: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedProject: {
      type: Object,
      required: false,
      default: null,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['project-clicked'],
  data() {
    return {
      errorType: null,
      projects: [],
      searchQuery: '',
      pageInfo: defaultPageInfo,
      searching: false,
    };
  },
  computed: {
    isLoadingProjects() {
      return this.$apollo.queries.projects.loading;
    },
    isLoadingMoreProjects() {
      return this.isLoadingProjects && this.projects.length > 0;
    },
    isSearchQueryTooShort() {
      return this.searchQuery.length < this.$options.MINIMUM_QUERY_LENGTH;
    },
    selected() {
      return this.selectedProject?.id || '';
    },
    toggleText() {
      return this.selectedProject?.name || this.$options.i18n.defaultPlaceholder;
    },
    listBoxItems() {
      return this.projects.map(({ id, name, ...project }) => ({
        ...project,
        value: id,
        text: name,
      }));
    },
    searchSuggestionText() {
      return this.isSearchQueryTooShort
        ? this.$options.i18n.searchText
        : this.$options.i18n.noResultsText;
    },
  },
  methods: {
    cancelSearch() {
      this.projects = [];
      this.pageInfo = defaultPageInfo;
      this.setErrorType(this.$options.QUERY_TOO_SHORT_ERROR);
    },
    fetchNextPage() {
      if (this.pageInfo.hasNextPage) {
        this.$apollo.queries.projects.fetchMore({
          variables: { after: this.pageInfo.endCursor },
          // Transform the previous result with new data
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              draftData[this.namespaceType].securityPolicyProjectSuggestions.nodes = [
                ...previousResult[this.namespaceType].securityPolicyProjectSuggestions.nodes,
                ...draftData[this.namespaceType].securityPolicyProjectSuggestions.nodes,
              ];
            });
          },
        });
      }
    },
    fetchProjects(query) {
      this.searchQuery = query;

      if (this.isSearchQueryTooShort) {
        this.cancelSearch();
      } else {
        this.searching = true;
        this.errorType = null;
        this.pageInfo = defaultPageInfo;
        this.projects = [];
      }
    },
    fetchProjectsError() {
      this.projects = [];
      this.setErrorType(this.$options.SEARCH_ERROR);
    },
    isErrorOfType(type) {
      return this.errorType === type;
    },
    setErrorType(errorType) {
      this.errorType = errorType;
    },
    selectProject(projectId) {
      const project = this.projects.find(({ id }) => projectId === id);
      this.$emit('project-clicked', project);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    fluid-width
    searchable
    infinite-scroll
    is-check-centered
    :disabled="disabled"
    :header-text="headerText"
    :loading="isLoadingProjects"
    :no-results-text="searchSuggestionText"
    :searching="searching"
    :infinite-scroll-loading="isLoadingMoreProjects"
    :selected="selected"
    :items="listBoxItems"
    :toggle-text="toggleText"
    :search-placeholder="$options.i18n.searchPlaceholder"
    @bottom-reached="fetchNextPage"
    @search="fetchProjects"
    @select="selectProject"
  >
    <template #list-item="{ item }">
      <div class="gl-flex gl-min-w-0 gl-items-center gl-gap-3">
        <gl-avatar
          fallback-on-error
          :shape="$options.AVATAR_SHAPE_OPTION_RECT"
          :entity-name="item.text"
          :alt="item.text"
          :src="item.text[0]"
          :size="32"
        />
        <div class="gl-min-w-0 gl-flex-1">
          <div class="gl-truncate">{{ item.text }}</div>
          <gl-truncate
            class="gl-text-sm gl-text-subtle"
            :text="item.nameWithNamespace"
            position="middle"
            with-tooltip
          />
        </div>
      </div>
    </template>
    <template #footer>
      <div
        v-if="isErrorOfType($options.SEARCH_ERROR)"
        data-testid="error-message"
        class="js-search-error-message gl-pb-3 gl-pl-7 gl-pr-3 gl-text-danger"
      >
        {{ $options.i18n.errorNetworkMessage }}
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
