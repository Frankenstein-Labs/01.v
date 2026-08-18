<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import produce from 'immer';
import { debounce, uniq } from 'lodash-es';
import { s__, __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import projectRunnerTags from './graphql/get_project_runner_tags.query.graphql';
import groupRunnerTags from './graphql/get_group_runner_tags.query.graphql';
import { NAMESPACE_TYPES } from './constants';
import { getUniqueTagListFromEdges } from './utils';

export default {
  i18n: {
    noRunnerTagsText: s__('RunnerTags|No tags exist'),
    runnerEmptyStateText: s__('RunnerTags|No matching results'),
    runnerSearchHeader: s__('RunnerTags|Select runner tags'),
    resetButtonLabel: __('Clear all'),
    selectAllButtonLabel: __('Select all'),
  },
  name: 'RunnerTagsDropdown',
  components: {
    GlCollapsibleListbox,
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    tagList: {
      query() {
        return this.tagListQuery;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          tagList: this.search,
        };
      },
      async update(data) {
        const {
          [this.namespaceType]: {
            runners: { nodes = [] },
          },
        } = data;
        this.tags = uniq([...this.tags, ...getUniqueTagListFromEdges(nodes)]);
        await this.selectExistingTags();
        this.sortTags();

        this.$emit('tags-loaded', this.tags);
      },
      error(error) {
        this.$emit('error', error);
      },
    },
  },
  props: {
    block: {
      type: Boolean,
      required: false,
      default: false,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    namespaceType: {
      type: String,
      required: false,
      default: NAMESPACE_TYPES.PROJECT,
    },
    namespacePath: {
      type: String,
      required: false,
      default: '',
    },
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
    headerText: {
      type: String,
      required: false,
      default: '',
    },
    emptyTagsListPlaceholder: {
      type: String,
      required: false,
      default: '',
    },
    toggleClass: {
      type: [String, Array, Object],
      required: false,
      default: null,
    },
  },
  emits: ['error', 'input', 'tags-loaded'],
  data() {
    return {
      hasRequestedExistingTags: false,
      search: '',
      selected: [],
      tags: [],
    };
  },
  computed: {
    items() {
      return this.tags
        .filter((tag) => tag.includes(this.search))
        .map((tag) => ({ text: tag, value: tag }));
    },
    isDropdownDisabled() {
      return this.disabled || (this.isTagListEmpty && !this.isSearching);
    },
    isProject() {
      return this.namespaceType === NAMESPACE_TYPES.PROJECT;
    },
    isSearching() {
      return this.search.length > 0;
    },
    isTagListEmpty() {
      return this.tags.length === 0;
    },
    loading() {
      return this.$apollo.queries.tagList?.loading || false;
    },
    runnerSearchHeader() {
      return this.headerText || this.$options.i18n.runnerSearchHeader;
    },
    text() {
      if (this.isTagListEmpty && !this.selected.length) {
        return this.emptyTagsListPlaceholder || this.$options.i18n.noRunnerTagsText;
      }

      return this.selected?.join(', ') || this.$options.i18n.runnerSearchHeader;
    },
    tagListQuery() {
      return this.isProject ? projectRunnerTags : groupRunnerTags;
    },
  },
  created() {
    this.debouncedSearchKeyUpdate = debounce(this.setSearchKey, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    doesTagExist(tag) {
      return this.tags.includes(tag) || this.selected.includes(tag);
    },
    isTagSelected(tag) {
      return this.selected?.includes(tag);
    },
    async getExistingTags(tagList) {
      this.hasRequestedExistingTags = true;

      try {
        await this.$apollo.queries.tagList.fetchMore({
          variables: { fullPath: this.namespacePath, tagList },
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              draftData[this.namespaceType].runners.nodes = [
                ...((previousResult[this.namespaceType] || {}).runners?.nodes || []),
                ...((draftData[this.namespaceType] || {}).runners?.nodes || []),
              ];
            });
          },
        });
      } catch {
        this.$emit('error');
        return;
      }

      // Check if any tags still don't exist after fetching
      const nonExistingTags = this.value.filter((tag) => !this.doesTagExist(tag));
      if (nonExistingTags.length > 0) {
        this.$emit('error');
      }
    },
    sortTags() {
      this.tags.sort((a) => (this.isTagSelected(a) ? -1 : 1));
    },
    setSearchKey(value) {
      this.search = value?.trim();
    },
    setSelection(tags) {
      this.selected = tags;
      this.$emit('input', this.selected);
    },
    async selectExistingTags() {
      if (this.value.length === 0) return;

      const nonExistingTags = this.value.filter((tag) => !this.doesTagExist(tag));

      if (nonExistingTags.length > 0) {
        if (this.hasRequestedExistingTags) {
          this.$emit('error');
        } else {
          // Try to specifically retrieve tags that weren't available
          await this.getExistingTags(nonExistingTags);
        }
      }

      this.selected = this.value;
      this.hasRequestedExistingTags = false;
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    multiple
    searchable
    :block="block"
    :disabled="isDropdownDisabled"
    :toggle-class="toggleClass"
    :items="items"
    :loading="loading"
    :header-text="runnerSearchHeader"
    :no-caret="isTagListEmpty"
    :no-results-text="$options.i18n.runnerEmptyStateText"
    :selected="selected"
    :reset-button-label="$options.i18n.resetButtonLabel"
    :show-select-all-button-label="$options.i18n.selectAllButtonLabel"
    :toggle-text="text"
    @hidden="sortTags"
    @reset="setSelection([])"
    @search="debouncedSearchKeyUpdate"
    @select="setSelection"
    @select-all="setSelection(tags)"
  />
</template>
