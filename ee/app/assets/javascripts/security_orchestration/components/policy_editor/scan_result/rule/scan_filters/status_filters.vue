<script>
import { __, s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import StatusFilter from './status_filter.vue';
import { DEFAULT_VULNERABILITY_STATES, NEWLY_DETECTED, PREVIOUSLY_EXISTING } from './constants';

export default {
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  i18n: {
    secondFilterLabel: __('or'),
    firstFilterLabel: s__('ScanResultPolicy|Status is:'),
  },
  name: 'StatusFilters',
  components: {
    StatusFilter,
    SectionLayout,
  },
  props: {
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    selected: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['change-status-group', 'input', 'remove'],
  computed: {
    allFiltersSelected() {
      return this.filters[PREVIOUSLY_EXISTING] && this.filters[NEWLY_DETECTED];
    },
    selectionDisabled() {
      return Boolean(this.filters[NEWLY_DETECTED] && this.filters[PREVIOUSLY_EXISTING]);
    },
    secondFilterLabel() {
      return this.allFiltersSelected
        ? this.$options.i18n.secondFilterLabel
        : this.$options.i18n.firstFilterLabel;
    },
    secondFilterLabelClasses() {
      const baseClasses = '!gl-text-base !gl-w-12 !gl-pl-0';

      if (this.allFiltersSelected) {
        return baseClasses;
      }

      return `${baseClasses} !gl-font-bold`;
    },
  },
  methods: {
    isFilterSelected(filter) {
      return Boolean(this.filters[filter]);
    },
    setStatusFilter(filter) {
      const oppositeMap = {
        [NEWLY_DETECTED]: [PREVIOUSLY_EXISTING, DEFAULT_VULNERABILITY_STATES],
        [PREVIOUSLY_EXISTING]: [NEWLY_DETECTED, []],
      };

      const [oppositeKey, emittedValue] = oppositeMap[filter];

      this.$emit('change-status-group', {
        ...this.selected,
        [oppositeKey]: null,
        [filter]: emittedValue,
      });
    },
    removeFilter(filter) {
      this.$emit('remove', filter);
    },
    setStatuses(statuses, key) {
      this.$emit('input', {
        ...this.selected,
        [key]: statuses,
      });
    },
  },
};
</script>

<template>
  <section-layout
    :show-remove-button="false"
    class="gl-w-full gl-bg-default !gl-p-0"
    content-classes="!gl-gap-0"
  >
    <template #content>
      <status-filter
        v-if="isFilterSelected($options.NEWLY_DETECTED)"
        :disabled="selectionDisabled"
        :show-remove-button="selectionDisabled"
        :filter="$options.NEWLY_DETECTED"
        :selected="selected[$options.NEWLY_DETECTED]"
        :label="$options.i18n.firstFilterLabel"
        :class="{ 'gl-pb-3': allFiltersSelected }"
        label-classes="!gl-text-base !gl-w-10 @md/panel:!gl-w-12 !gl-pl-0 !gl-font-bold"
        class="gl-w-full gl-bg-default @md/panel:gl-items-center"
        @input="setStatuses($event, $options.NEWLY_DETECTED)"
        @change-group="setStatusFilter"
        @remove="removeFilter"
      />
      <status-filter
        v-if="isFilterSelected($options.PREVIOUSLY_EXISTING)"
        :disabled="selectionDisabled"
        :show-remove-button="selectionDisabled"
        :filter="$options.PREVIOUSLY_EXISTING"
        :label="secondFilterLabel"
        :selected="selected[$options.PREVIOUSLY_EXISTING]"
        :label-classes="secondFilterLabelClasses"
        class="gl-w-full @md/panel:gl-items-center"
        :class="{ 'gl-pt-2': allFiltersSelected }"
        @input="setStatuses($event, $options.PREVIOUSLY_EXISTING)"
        @change-group="setStatusFilter"
        @remove="removeFilter"
      />
    </template>
  </section-layout>
</template>
