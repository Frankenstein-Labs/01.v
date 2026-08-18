<script>
import { uniqBy, get } from 'lodash-es';
import produce from 'immer';
import getSppLinkedGroupsProjects from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups_projects.query.graphql';
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

const LINKED_GROUPS_PATH = 'project.securityPolicyProjectLinkedGroups';

export default {
  i18n: PROJECT_DROPDOWN_I18N,
  name: 'LinkedGroupsProjectsDropdown',
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
    groupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['projects-query-error', 'select'],
  apollo: {
    projects: {
      query: getSppLinkedGroupsProjects,
      variables() {
        return this.reactiveVariables;
      },
      skip() {
        return !this.assignedPolicyProjectPath;
      },
      update(data) {
        const linkedGroups = get(data, `${LINKED_GROUPS_PATH}.nodes`, []);
        const newProjects = linkedGroups.flatMap((group) =>
          get(group, 'projects.nodes', []).map((project) => ({
            ...project,
            group: { id: group.id },
          })),
        );
        return uniqBy([...this.projects, ...newProjects], 'id');
      },
      result({ data }) {
        this.pageInfo = get(data, `${LINKED_GROUPS_PATH}.pageInfo`, {});
        const hasMore = get(data, `${LINKED_GROUPS_PATH}.nodes`, []).some((group) =>
          get(group, 'projects.pageInfo.hasNextPage', false),
        );
        // A search returning <20 results doesn't mean the full dataset has ≤20 projects.
        // Only downgrade hasMoreProjectsInGroups when not searching; upgrade it always.
        if (!this.searchUsed || hasMore) {
          this.hasMoreProjectsInGroups = hasMore;
        }

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
      hasMoreProjectsInGroups: false,
      searchTerm: '',
      projects: [],
    };
  },
  computed: {
    assignedPolicyProjectPath() {
      return this.assignedPolicyProject?.fullPath || '';
    },
    projectIds() {
      return this.filteredProjects?.map(({ id }) => id);
    },
    selectedButNotLoadedProjectIds() {
      const selected = this.multiple ? this.selected : [this.selected];
      return selected.filter((id) => !this.projectIds.includes(id));
    },
    showFooter() {
      return this.withProjectCount && !this.loading && !this.searchUsed;
    },
    allProjectsLoaded() {
      return !this.hasNextPage && !this.hasMoreProjectsInGroups;
    },
    projectsText() {
      return getProjectsText(this.projects.length);
    },
    filteredProjects() {
      if (this.groupIds.length === 0) {
        return this.projects;
      }

      return this.projects.filter(({ group = {} }) => this.groupIds.includes(group.id));
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
      return projectsToListboxItems(this.filteredProjects, this.searchTerm);
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
    reactiveVariables() {
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
    async fetchProjectsByIds() {
      const variables = {
        projectIds: this.selectedButNotLoadedProjectIds,
        ...this.pathVariable,
      };

      try {
        const { data } = await this.$apollo.query({
          query: getSppLinkedGroupsProjects,
          variables,
        });
        const linkedGroups = get(data, `${LINKED_GROUPS_PATH}.nodes`, []);
        const newProjects = linkedGroups.flatMap((group) =>
          get(group, 'projects.nodes', []).map((project) => ({
            ...project,
            group: { id: group.id },
          })),
        );
        this.projects = uniqBy([...this.projects, ...newProjects], 'id');
      } catch {
        this.$emit('projects-query-error');
      }
    },
    fetchMoreItems() {
      const variables = {
        after: this.pageInfo.endCursor,
        ...this.pathVariable,
        search: this.searchTerm,
      };

      this.$apollo.queries.projects
        .fetchMore({
          variables,
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              const previousGroups = get(previousResult, `${LINKED_GROUPS_PATH}.nodes`, []);
              const newGroups = get(draftData, `${LINKED_GROUPS_PATH}.nodes`, []);

              draftData.project.securityPolicyProjectLinkedGroups.nodes = [
                ...previousGroups,
                ...newGroups,
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
