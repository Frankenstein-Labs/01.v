<script>
import { uniqBy, get } from 'lodash-es';
import produce from 'immer';
import { __ } from '~/locale';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import BaseItemsDropdown from './base_items_dropdown.vue';
import ProjectsCountMessage from './projects_count_message.vue';
import {
  PROJECT_DROPDOWN_I18N,
  createDebouncedSearch,
  normalizeSearchTerm,
  projectsToListboxItems,
  getDropdownCategory,
  getDropdownVariant,
  getProjectsText,
  filterExistingSelectedIds,
  SHARED_DROPDOWN_PROPS,
} from './project_dropdown_utils';

const GROUP_PROJECTS_PATH = 'group.projects';

export default {
  i18n: PROJECT_DROPDOWN_I18N,
  name: 'GroupProjectsDropdown',
  components: {
    BaseItemsDropdown,
    ProjectsCountMessage,
  },
  apollo: {
    projects: {
      query: getGroupProjects,
      variables() {
        return this.reactiveVariables;
      },
      update(data) {
        /**
         * It is important to preserve all projects that have been loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        const nodes = get(data, `${GROUP_PROJECTS_PATH}.nodes`, []);
        return uniqBy([...this.projects, ...nodes], 'id');
      },
      result({ data }) {
        this.pageInfo = get(data, `${GROUP_PROJECTS_PATH}.pageInfo`, {});
        if (!this.allProjectsCountSaved) {
          this.allProjectsCount = get(data, `${GROUP_PROJECTS_PATH}.count`, 0);
        }

        if (this.selectedButNotLoadedProjectIds.length > 0) {
          this.fetchGroupProjectsByIds();
        }
      },
      error() {
        this.$emit('projects-query-error');
      },
    },
  },
  props: {
    ...SHARED_DROPDOWN_PROPS,
    groupFullPath: {
      type: String,
      required: true,
    },
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
    groupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['projects-query-error', 'select'],
  data() {
    return {
      pageInfo: {},
      searchTerm: '',
      projects: [],
      allProjectsCount: 0,
    };
  },
  computed: {
    allProjectsCountSaved() {
      return this.allProjectsCount > 0;
    },
    projectIds() {
      return this.filteredProjects?.map(({ id }) => id);
    },
    selectedButNotLoadedProjectIds() {
      const selected = this.multiple ? this.selected : [this.selected];
      return selected.filter((id) => !this.projectIds.includes(id));
    },
    showFooter() {
      return this.withProjectCount && !this.loading;
    },
    allProjectsLoaded() {
      return this.projects.length === this.allProjectsCount;
    },
    projectsText() {
      return getProjectsText(this.allProjectsCount);
    },
    filteredProjects() {
      if (this.groupIds.length === 0) {
        return this.projects;
      }

      return this.projects.filter(({ group = {} }) => this.groupIds.includes(group.id));
    },
    itemTypeName() {
      return this.isGroup ? __('groups') : __('projects');
    },
    existingFormattedSelectedIds() {
      if (this.multiple) {
        return filterExistingSelectedIds(this.selected, this.projectIds);
      }

      return this.selected;
    },
    loading() {
      return this.$apollo.queries.projects.loading;
    },
    searching() {
      return this.loading && this.searchUsed && !this.hasNextPage;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    listBoxItems() {
      return projectsToListboxItems(this.filteredProjects, this.searchTerm);
    },
    category() {
      return getDropdownCategory(this.state);
    },
    variant() {
      return getDropdownVariant(this.state);
    },
    pathVariable() {
      return { fullPath: this.groupFullPath, withCount: this.withProjectCount };
    },
    reactiveVariables() {
      if (this.allProjectsLoaded) {
        return this.pathVariable;
      }

      return {
        ...this.pathVariable,
        search: this.searchTerm,
      };
    },
  },
  created() {
    this.debouncedSearch = createDebouncedSearch(this.setSearchTerm);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchGroupProjectsByIds() {
      const variables = {
        after: this.pageInfo.endCursor,
        projectIds: this.selectedButNotLoadedProjectIds,
        ...this.pathVariable,
      };

      try {
        const { data } = await this.$apollo.query({
          query: getGroupProjects,
          variables,
        });
        const { projects: { nodes = [] } = {} } = data.group || {};
        this.projects = uniqBy([...this.projects, ...nodes], 'id');
      } catch {
        this.$emit('projects-query-error');
      }
    },
    fetchMoreItems() {
      const variables = {
        after: this.pageInfo.endCursor,
        ...this.pathVariable,
      };

      this.$apollo.queries.projects
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              const getPreviousNodes = get(previousResult, `${GROUP_PROJECTS_PATH}.nodes`, []);
              const getNewNodes = get(draftData, `${GROUP_PROJECTS_PATH}.nodes`, []);

              get(draftData, GROUP_PROJECTS_PATH).nodes = [...getPreviousNodes, ...getNewNodes];
            });
          },
        })
        .catch(() => {
          this.$emit('projects-query-error');
        });
    },
    setSearchTerm(searchTerm) {
      this.searchTerm = normalizeSearchTerm(searchTerm);
    },
    selectItems(selected) {
      const ids = this.multiple ? selected : [selected];
      const selectedItems = this.filteredProjects.filter(({ id }) => ids.includes(id));
      const payload = this.multiple ? selectedItems : selectedItems[0];
      this.$emit('select', payload);
    },
  },
};
</script>

<template>
  <base-items-dropdown
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :multiple="multiple"
    :loading="loading"
    :header-text="$options.i18n.projectDropdownHeader"
    :items="listBoxItems"
    :infinite-scroll="hasNextPage"
    :searching="searching"
    :selected="existingFormattedSelectedIds"
    :placement="placement"
    :item-type-name="itemTypeName"
    @bottom-reached="fetchMoreItems"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems"
  >
    <template v-if="showFooter" #footer>
      <div
        class="gl-border-t gl-flex gl-items-center gl-gap-3 gl-px-4 gl-py-3"
        data-testid="footer"
      >
        <projects-count-message
          :count="listBoxItems.length"
          :info-text="projectsText"
          :total-count="allProjectsCount"
          :show-info-icon="!allProjectsLoaded"
        />
      </div>
    </template>
  </base-items-dropdown>
</template>
