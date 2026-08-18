<script>
import { debounce, uniqBy } from 'lodash-es';
import Api, { DEFAULT_PER_PAGE } from '~/api';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  name: 'InstanceProjectsDropdown',
  components: {
    BaseItemsDropdown,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['projects-query-error', 'select'],
  data() {
    return {
      searchTerm: '',
      projects: [],
      loading: false,
      currentPage: 1,
      totalPages: 1,
      hasNextPage: false,
    };
  },
  computed: {
    projectIds() {
      return this.projects?.map(({ id }) => id);
    },
    notLoadedSelectedProjectIds() {
      return this.selected.filter((id) => !this.projectIds.includes(id));
    },
    existingSelectedProjectIds() {
      return this.selected.filter((id) => this.projectIds.includes(id));
    },
    searching() {
      return this.loading && !this.hasNextPage;
    },
    listBoxItems() {
      const items = this.projects.map(({ id, path_with_namespace: fullPath, name }) => ({
        id,
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
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
  },
  watch: {
    async searchTerm() {
      this.currentPage = 1;
      this.projects = [];
      this.hasNextPage = false;
      await this.fetchProjects();
    },
  },
  async created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);

    // Load initial projects
    await this.fetchProjects();

    // Load selected projects that aren't already loaded
    if (this.notLoadedSelectedProjectIds.length > 0) {
      await this.fetchProjectsByIds();
    }
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchProjects() {
      if (this.loading) return;

      this.loading = true;

      try {
        const { data, headers } = await Api.projects(this.searchTerm, {
          simple: true,
          page: this.currentPage,
          per_page: DEFAULT_PER_PAGE,
        });

        if (this.currentPage === 1) {
          this.projects = data;
        } else {
          this.mergeInNewProjects(data);
        }

        // Parse pagination info from headers
        const { total } = parseIntPagination(normalizeHeaders(headers));
        this.totalPages = total;
        this.hasNextPage = this.currentPage < this.totalPages;
      } catch (error) {
        Sentry.captureException(error);
        this.$emit('projects-query-error');
      } finally {
        this.loading = false;
      }
    },
    async fetchProjectsByIds() {
      if (this.notLoadedSelectedProjectIds.length === 0) return;

      try {
        const projectPromises = this.notLoadedSelectedProjectIds.map((id) =>
          Api.project(id).catch(() => this.$emit('projects-query-error')),
        );

        const projectResponses = await Promise.all(projectPromises);
        const validProjects = projectResponses
          .filter((response) => response?.data)
          .map(({ data }) => data);

        this.mergeInNewProjects(validProjects);
      } catch (error) {
        Sentry.captureException(error);
        this.$emit('projects-query-error');
      }
    },
    async fetchMoreItems() {
      if (!this.hasNextPage || this.loading) return;

      this.currentPage += 1;
      await this.fetchProjects();
    },
    mergeInNewProjects(projectData) {
      // Merge in new projects ensuring uniqueness based on ID
      this.projects = uniqBy([...this.projects, ...projectData], 'id');
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const selectedItems = this.projects.filter(({ id }) => selected.includes(id));
      this.$emit('select', selectedItems);
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
    :header-text="__('Select projects')"
    :items="listBoxItems"
    :infinite-scroll="hasNextPage"
    :searching="searching"
    :selected="existingSelectedProjectIds"
    @bottom-reached="fetchMoreItems"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems"
  />
</template>
