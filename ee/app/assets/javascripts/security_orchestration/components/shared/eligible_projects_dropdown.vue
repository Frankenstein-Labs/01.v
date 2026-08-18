<script>
import { uniqBy, get } from 'lodash-es';
import produce from 'immer';
import getSppEligibleProjects from 'ee/security_orchestration/graphql/queries/get_spp_eligible_projects.query.graphql';
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

const ELIGIBLE_PROJECTS_PATH = 'project.securityPolicyEligibleProjects';

export default {
  i18n: PROJECT_DROPDOWN_I18N,
  name: 'EligibleProjectsDropdown',
  components: {
    BaseItemsDropdown,
    ProjectsCountMessage,
  },
  inject: {
    assignedPolicyProject: { default: null },
  },
  props: {
    ...SHARED_DROPDOWN_PROPS,
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['projects-query-error', 'select'],
  apollo: {
    projects: {
      query: getSppEligibleProjects,
      variables() {
        return {
          fullPath: this.assignedPolicyProjectPath,
          search: this.searchTerm,
        };
      },
      skip() {
        return !this.assignedPolicyProjectPath;
      },
      update(data) {
        const nodes = get(data, `${ELIGIBLE_PROJECTS_PATH}.nodes`, []);
        return uniqBy([...this.projects, ...nodes], 'id');
      },
      result({ data }) {
        this.pageInfo = get(data, `${ELIGIBLE_PROJECTS_PATH}.pageInfo`, {});

        if (this.selectedButNotLoadedProjectIds.length > 0) {
          this.fetchProjectsByIds();
        }
      },
      error() {
        this.$emit('projects-query-error');
      },
    },
  },
  data() {
    return {
      pageInfo: {},
      searchTerm: '',
      projects: [],
    };
  },
  computed: {
    assignedPolicyProjectPath() {
      return this.assignedPolicyProject?.fullPath || '';
    },
    projectIds() {
      return this.projects?.map(({ id }) => id);
    },
    selectedButNotLoadedProjectIds() {
      const selected = this.multiple ? this.selected : [this.selected];
      return selected.filter((id) => !this.projectIds.includes(id));
    },
    showFooter() {
      return this.withProjectCount && !this.loading && !this.searchUsed;
    },
    allProjectsLoaded() {
      return !this.hasNextPage;
    },
    projectsText() {
      return getProjectsText(this.projects.length);
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
      return this.loading && this.searchUsed;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    listBoxItems() {
      return projectsToListboxItems(this.projects, this.searchTerm);
    },
    category() {
      return getDropdownCategory(this.state);
    },
    variant() {
      return getDropdownVariant(this.state);
    },
    pathVariable() {
      return { fullPath: this.assignedPolicyProjectPath };
    },
  },
  created() {
    this.debouncedSearch = createDebouncedSearch(this.setSearchTerm);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchProjectsByIds() {
      try {
        const { data } = await this.$apollo.query({
          query: getSppEligibleProjects,
          variables: {
            ...this.pathVariable,
            ids: this.selectedButNotLoadedProjectIds,
          },
        });
        const newProjects = get(data, `${ELIGIBLE_PROJECTS_PATH}.nodes`, []);
        this.projects = uniqBy([...this.projects, ...newProjects], 'id');
      } catch {
        this.$emit('projects-query-error');
      }
    },
    fetchMoreItems() {
      this.$apollo.queries.projects
        .fetchMore({
          variables: {
            ...this.pathVariable,
            search: this.searchTerm,
            after: this.pageInfo.endCursor,
          },
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              const previousNodes = get(previousResult, `${ELIGIBLE_PROJECTS_PATH}.nodes`, []);
              const newNodes = get(draftData, `${ELIGIBLE_PROJECTS_PATH}.nodes`, []);

              draftData.project.securityPolicyEligibleProjects.nodes = [
                ...previousNodes,
                ...newNodes,
              ];
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
      const selectedItems = this.projects.filter(({ id }) => ids.includes(id));
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
    :item-type-name="__('projects')"
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
          :total-count="projects.length"
          :show-info-icon="!allProjectsLoaded"
        />
      </div>
    </template>
  </base-items-dropdown>
</template>
