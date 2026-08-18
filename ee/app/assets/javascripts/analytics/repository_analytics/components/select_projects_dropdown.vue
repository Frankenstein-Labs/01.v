<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import produce from 'immer';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, n__ } from '~/locale';
import getGroupProjects from '../graphql/queries/get_group_projects.query.graphql';

export default {
  i18n: {
    selectAllLabel: __('Select all'),
    clearAllLabel: __('Clear all'),
    projectDropdownHeader: __('Projects'),
    projectDropdownAllProjects: __('All projects'),
  },
  name: 'SelectProjectsDropdown',
  components: {
    GlCollapsibleListbox,
  },
  inject: {
    groupFullPath: {
      default: '',
    },
  },
  apollo: {
    groupProjects: {
      query: getGroupProjects,
      variables() {
        return {
          groupFullPath: this.groupFullPath,
        };
      },
      update(data) {
        return (
          data.group?.projects?.nodes?.map((project) => ({
            ...project,
            parsedId: getIdFromGraphQLId(project.id),
            isSelected: false,
          })) || []
        );
      },
      result({ data }) {
        this.projectsPageInfo = data?.group?.projects?.pageInfo || {};
        this.selectedProjectsIds = data?.group?.projects?.nodes?.map(({ id }) => id) || [];
      },
      error() {
        this.handleError();
      },
    },
  },
  props: {
    placement: {
      type: String,
      required: false,
      default: 'bottom-start',
    },
  },
  emits: ['projects-query-error', 'reset-all-projects', 'select-all-projects', 'select-project'],
  data() {
    return {
      groupProjects: [],
      projectsPageInfo: {},
      projectSearchTerm: '',
      selectedProjectsIds: [],
    };
  },
  computed: {
    filteredProjects() {
      return this.groupProjects.filter((project) =>
        project.name.toLowerCase().includes(this.projectSearchTerm.toLowerCase()),
      );
    },
    dropdownPlaceholder() {
      if (this.selectedProjectsIds.length === this.groupProjects.length) {
        return __('All projects selected');
      }
      if (this.selectedProjectsIds.length) {
        return n__('%d project selected', '%d projects selected', this.selectedProjectsIds.length);
      }
      return __('Select projects');
    },
    groupProjectsIds() {
      return this.groupProjects.map(({ id }) => id);
    },
    listBoxItems() {
      return this.filteredProjects.map((project) => ({
        value: project.id,
        text: project.name,
        ...project,
      }));
    },
    loading() {
      return this.$apollo.queries.groupProjects.loading;
    },
  },
  methods: {
    clickDropdownProject(ids) {
      this.selectedProjectsIds = ids;
      this.$emit('select-project', ids);
    },
    clickSelectAllProjects() {
      this.selectedProjectsIds = this.groupProjectsIds;

      this.$emit('select-all-projects', this.selectedProjectsIds);
    },
    resetAllProjects() {
      this.selectedProjectsIds = [];
      this.$emit('reset-all-projects', []);
    },
    handleError() {
      this.$emit('projects-query-error');
    },
    loadMoreProjects() {
      this.$apollo.queries.groupProjects
        .fetchMore({
          variables: {
            groupFullPath: this.groupFullPath,
            after: this.projectsPageInfo.endCursor,
          },
          updateQuery(previousResult, { fetchMoreResult }) {
            const results = produce(fetchMoreResult, (draftData) => {
              draftData.group.projects.nodes = [
                ...previousResult.group.projects.nodes,
                ...draftData.group.projects.nodes,
              ];
            });
            return results;
          },
        })
        .catch(() => {
          this.handleError();
        });
    },
    setProjectSearchTerm(term = '') {
      this.projectSearchTerm = term.trim();
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    multiple
    searchable
    is-check-centered
    :placement="placement"
    :header-text="$options.i18n.projectDropdownHeader"
    :items="listBoxItems"
    :infinite-scroll="projectsPageInfo.hasNextPage"
    :infinite-scroll-loading="loading"
    :loading="loading"
    :selected="selectedProjectsIds"
    :show-select-all-button-label="$options.i18n.selectAllLabel"
    :reset-button-label="$options.i18n.clearAllLabel"
    :toggle-text="dropdownPlaceholder"
    @bottom-reached="loadMoreProjects"
    @reset="resetAllProjects"
    @search="setProjectSearchTerm"
    @select="clickDropdownProject"
    @select-all="clickSelectAllProjects"
  />
</template>
