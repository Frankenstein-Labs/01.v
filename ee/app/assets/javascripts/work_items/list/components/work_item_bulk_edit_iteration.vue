<script>
import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { debounce, unionBy, uniqueId } from 'lodash-es';
import { groupOptionsByIterationCadences, getIterationPeriod } from 'ee/iterations/utils';
import { createAlert } from '~/alert';
import projectIterationsQuery from 'ee/work_items/graphql/project_iterations.query.graphql';
import groupIterationsQuery from 'ee/sidebar/queries/group_iterations.query.graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { STATUS_OPEN } from '~/issues/constants';
import { __, s__ } from '~/locale';
import { BULK_EDIT_NO_VALUE } from '~/work_items/constants';

export default {
  name: 'WorkItemBulkEditIteration',
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    value: {
      type: String,
      required: false,
      default: undefined,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  data() {
    return {
      iterationToggleId: uniqueId('wi-iteration-toggle-'),
      searchStarted: false,
      searchTerm: '',
      selectedId: this.value,
      iterations: [],
      iterationsCache: [],
    };
  },
  apollo: {
    iterations: {
      query() {
        return this.isGroup ? groupIterationsQuery : projectIterationsQuery;
      },
      variables() {
        const search = this.searchTerm ? `"${this.searchTerm}"` : '';
        return {
          fullPath: this.fullPath,
          title: search,
          state: STATUS_OPEN,
        };
      },
      skip() {
        return !this.searchStarted;
      },
      update(data) {
        return data.namespace?.attributes.nodes ?? [];
      },
      error(error) {
        createAlert({
          message: __('Failed to load iterations. Please try again.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.iterations.loading;
    },
    listboxItems() {
      if (!this.searchTerm.trim().length) {
        return [
          {
            text: s__('WorkItem|No iteration'),
            textSrOnly: true,
            options: [{ text: s__('WorkItem|No iteration'), value: BULK_EDIT_NO_VALUE }],
          },
          ...groupOptionsByIterationCadences(this.iterations),
        ];
      }

      return groupOptionsByIterationCadences(this.iterations);
    },
    selectedIteration() {
      return this.iterationsCache.find((iteration) => this.selectedId === iteration.id);
    },
    toggleText() {
      if (this.selectedIteration) {
        return getIterationPeriod(this.selectedIteration);
      }
      if (this.selectedId === BULK_EDIT_NO_VALUE) {
        return s__('WorkItem|No iteration');
      }
      return __('Select iteration');
    },
  },
  watch: {
    iterations(iterations) {
      this.updateIterationsCache(iterations);
    },
  },
  created() {
    this.setSearchTermDebounced = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    clearSearch() {
      this.searchTerm = '';
      this.$refs.listbox.$refs.searchBox.clearInput?.();
    },
    handleSelect(item) {
      this.selectedId = item;
      this.$emit('input', item);
      this.clearSearch();
    },
    handleShown() {
      this.searchTerm = '';
      this.searchStarted = true;
    },
    reset() {
      this.handleSelect(undefined);
      this.$refs.listbox.close();
    },
    setSearchTerm(searchTerm) {
      this.searchTerm = searchTerm;
    },
    updateIterationsCache(iterations) {
      // Need to store all iterations we encounter so we can show "Selected" iterations
      // even if they're not found in the apollo `iterations` list
      this.iterationsCache = unionBy(this.iterationsCache, iterations, 'id');
    },
  },
};
</script>

<template>
  <gl-form-group :label="__('Iteration')" :label-for="iterationToggleId">
    <gl-collapsible-listbox
      ref="listbox"
      block
      :header-text="__('Select iteration')"
      is-check-centered
      :items="listboxItems"
      :no-results-text="s__('WorkItem|No matching results')"
      :reset-button-label="__('Reset')"
      searchable
      :searching="isLoading"
      :selected="selectedId"
      :toggle-id="iterationToggleId"
      :toggle-text="toggleText"
      :disabled="disabled"
      @reset="reset"
      @search="setSearchTermDebounced"
      @select="handleSelect"
      @shown="handleShown"
    />
  </gl-form-group>
</template>
