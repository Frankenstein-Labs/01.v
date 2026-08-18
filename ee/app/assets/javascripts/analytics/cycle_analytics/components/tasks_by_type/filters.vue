<script>
import { GlCollapsibleListbox, GlSegmentedControl } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { difference } from 'lodash-es';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __, s__, n__, sprintf } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS, TASKS_BY_TYPE_MAX_LABELS } from '../../constants';
import getTasksByTypeLabels from '../../graphql/queries/get_tasks_by_type_labels.query.graphql';

export default {
  name: 'TasksByTypeFilters',
  components: {
    GlCollapsibleListbox,
    GlSegmentedControl,
  },
  props: {
    selectedLabelNames: {
      type: Array,
      required: true,
    },
    maxLabels: {
      type: Number,
      required: false,
      default: TASKS_BY_TYPE_MAX_LABELS,
    },
    subjectFilter: {
      type: String,
      required: true,
    },
  },
  emits: ['set-subject', 'toggle-label'],
  data() {
    return {
      labels: [],
      searchTerm: '',
      maxLabelsAlert: null,
    };
  },
  computed: {
    ...mapState(['groupPath']),
    subjectFilterOptions() {
      return Object.entries(TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS).map(([value, text]) => ({
        text,
        value,
      }));
    },
    selectedLabelsCount() {
      return this.selectedLabelNames.length;
    },
    maxLabelsSelected() {
      return this.selectedLabelNames.length >= this.maxLabels;
    },
    labelsSelectedText() {
      const { selectedLabelsCount, maxLabels } = this;
      return sprintf(
        n__(
          'CycleAnalytics|%{selectedLabelsCount} label selected (%{maxLabels} max)',
          'CycleAnalytics|%{selectedLabelsCount} labels selected (%{maxLabels} max)',
          selectedLabelsCount,
        ),
        { selectedLabelsCount, maxLabels },
      );
    },
    items() {
      return this.labels.map(({ title, color }) => ({ value: title, text: title, color }));
    },
    selected: {
      get() {
        return this.selectedLabelNames;
      },
      set(data) {
        const [addedLabel] = difference(data, this.selectedLabelNames);
        const [removedLabel] = difference(this.selectedLabelNames, data);
        this.toggleLabel(addedLabel || removedLabel);
      },
    },
    loading() {
      return this.$apollo.queries.labels.loading;
    },
  },
  apollo: {
    labels: {
      query: getTasksByTypeLabels,
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      variables() {
        return {
          fullPath: this.groupPath,
          searchTerm: this.searchTerm.trim(),
        };
      },
      update({
        group: {
          labels: { nodes },
        },
      }) {
        return nodes;
      },
      error() {
        createAlert({
          message: __('There was an error fetching label data for the selected group'),
        });
      },
    },
  },
  methods: {
    findLabel(title) {
      return this.labels.find((label) => label.title === title);
    },
    toggleLabel(title) {
      if (this.maxLabelsSelected && !this.selectedLabelNames.includes(title)) {
        this.createMaxLabelsSelectedAlert();
        return;
      }

      this.maxLabelsAlert?.dismiss();
      this.$emit('toggle-label', this.findLabel(title));
    },
    createMaxLabelsSelectedAlert() {
      const { maxLabels } = this;
      const message = sprintf(
        s__('CycleAnalytics|Only %{maxLabels} labels can be selected at this time'),
        { maxLabels },
      );
      this.maxLabelsAlert = createAlert({ message, variant: VARIANT_INFO });
    },
    setSearchTerm(value) {
      this.searchTerm = value;
    },
  },
};
</script>
<template>
  <div class="js-tasks-by-type-chart-filters">
    <gl-collapsible-listbox
      v-model="selected"
      :name="'test'"
      :header-text="s__('CycleAnalytics|Select labels')"
      :toggle-text="s__('CycleAnalytics|Select labels')"
      :items="items"
      :searching="loading"
      :no-results-text="__('No matching labels')"
      icon="settings"
      text-sr-only
      searchable
      multiple
      @search="setSearchTerm"
    >
      <template #list-item="{ item: { text, color } }">
        <span :style="{ backgroundColor: color }" class="dropdown-label-box gl-inline-block">
        </span>
        {{ text }}
      </template>
      <template #footer>
        <small
          v-if="selected.length > 0"
          data-testid="selected-labels-count"
          class="gl-border-t-1 gl-border-t-dropdown !gl-p-2 !gl-text-center gl-text-subtle gl-border-t-solid"
        >
          {{ labelsSelectedText }}
        </small>
        <div
          class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown !gl-p-4 !gl-pt-3 gl-border-t-solid"
        >
          <p class="!gl-mb-3 !gl-text-left !gl-font-bold">{{ s__('CycleAnalytics|Show') }}</p>

          <gl-segmented-control
            :value="subjectFilter"
            :options="subjectFilterOptions"
            data-testid="type-of-work-filters-subject"
            @input="(value) => $emit('set-subject', value)"
          />
        </div>
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
