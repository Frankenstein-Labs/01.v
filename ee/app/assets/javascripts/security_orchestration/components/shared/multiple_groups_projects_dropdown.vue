<script>
import { debounce, uniqBy } from 'lodash-es';
import { __ } from '~/locale';
import getSppLinkedPGroupsChildrenProjects from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups_children_projects.query.graphql';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  i18n: {
    groupDropdownHeader: __('Select groups'),
  },
  name: 'MultipleGroupsProjectsDropdown',
  components: {
    BaseItemsDropdown,
  },
  apollo: {
    projects: {
      query() {
        return getSppLinkedPGroupsChildrenProjects;
      },
      variables() {
        return {
          search: this.searchTerm,
          ids: this.groupIds,
        };
      },
      update(data) {
        const payload = data.groups.nodes.flatMap(({ projects = {} }) => projects.nodes);
        /**
         * It is important to preserve all projects that has benn loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        return uniqBy([...this.projects, ...payload], 'id');
      },
      result() {
        this.filterProjectsOfSelectedGroups(this.groupIds);
      },
      error() {
        this.$emit('projects-query-error');
      },
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupIds: {
      type: Array,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'bottom-start',
    },
    hasError: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
  },
  emits: ['projects-query-error', 'select'],
  data() {
    return {
      projects: [],
      searchTerm: '',
    };
  },
  computed: {
    category() {
      return this.hasError ? 'secondary' : 'primary';
    },
    loading() {
      return this.$apollo.queries.projects.loading;
    },
    variant() {
      return this.hasError ? 'danger' : 'default';
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    searching() {
      return this.loading && this.searchUsed;
    },
    listBoxItems() {
      const items = this.projects
        .filter((project) => this.groupIds.includes(project.group?.id))
        .map(({ id, fullPath, name }) => ({
          text: name,
          value: id,
          fullPath,
        }));

      return searchInItemsProperties({
        items,
        properties: ['text', 'fullPath'],
        searchQuery: this.searchTerm,
      });
    },
  },
  watch: {
    groupIds(newVal, oldVal) {
      /**
       * Edge case
       * User selects multiple groups
       * and then selects projects from different groups
       * After that user deselect one of the groups
       * Projects of the removed groups will be removed from a
       * dropdown and code below would trigger removal from yaml
       */
      const isDecreasing = newVal.length < oldVal.length;
      if (isDecreasing) {
        this.filterProjectsOfSelectedGroups(newVal);
      }
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const selectedItems = this.projects.filter(({ id }) => selected.includes(id));
      this.$emit('select', selectedItems);
    },
    filterProjectsOfSelectedGroups(groupIds) {
      const filteredProjects = this.projects
        .filter((project) => groupIds.includes(project.group?.id))
        .filter((project) => {
          return this.selected.includes(project.id);
        })
        .map((project) => project.id);

      this.selectItems(filteredProjects);
    },
  },
};
</script>

<template>
  <base-items-dropdown
    multiple
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :loading="loading"
    :header-text="$options.i18n.groupDropdownHeader"
    :items="listBoxItems"
    :searching="searching"
    :selected="selected"
    :placement="placement"
    :item-type-name="__('projects')"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems"
  />
</template>
