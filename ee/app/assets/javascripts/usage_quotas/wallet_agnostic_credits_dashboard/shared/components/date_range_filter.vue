<script>
import { GlCollapsibleListbox, GlDaterangePicker } from '@gitlab/ui';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat } from '~/lib/utils/datetime/date_format_utility';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { CUSTOM } from './constants';

export default {
  name: 'DateRangeFilterEE',
  components: {
    GlCollapsibleListbox,
    GlDaterangePicker,
    HumanTimeframe,
  },
  props: {
    value: {
      type: Object,
      required: true,
    },
    options: {
      type: Array,
      required: true,
    },
    customDateRangeLimit: {
      type: Number,
      required: false,
      default: 0,
    },
    customDateRangeMaxDate: {
      type: Date,
      required: false,
      default: null,
    },
  },
  emits: ['input'],
  computed: {
    selectedOption() {
      return this.findOption(this.selectedValue) ?? this.options[0];
    },
    selectedValue() {
      return this.value.value;
    },
    isCustom() {
      return this.selectedValue === CUSTOM.value;
    },
    toggleText() {
      return this.selectedOption.text;
    },
    customStartDate() {
      if (this.isCustom && this.value.startDate) {
        return newDate(this.value.startDate);
      }
      return null;
    },
    customEndDate() {
      if (this.isCustom && this.value.endDate) {
        return newDate(this.value.endDate);
      }
      return null;
    },
  },
  methods: {
    findOption(optionValue) {
      return this.options.find((o) => o.value === optionValue);
    },
    onSelect(optionValue) {
      const option = this.findOption(optionValue);
      if (optionValue === CUSTOM.value) {
        this.$emit('input', {
          value: CUSTOM.value,
          startDate: this.value.startDate,
          endDate: this.value.endDate,
        });
      } else {
        this.$emit('input', {
          value: optionValue,
          startDate: option.startDate ?? null,
          endDate: option.endDate ?? null,
        });
      }
    },
    onCustomRangeSelected({ startDate, endDate }) {
      this.$emit('input', {
        value: CUSTOM.value,
        startDate: toISODateFormat(startDate),
        endDate: toISODateFormat(endDate),
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
    <gl-collapsible-listbox
      :selected="value.value"
      :items="options"
      :toggle-text="toggleText"
      :header-text="s__('DateRangeFilter|Date ranges')"
      @select="onSelect"
    />
    <!-- NOTE: without `gl-relative` wrapper, date selector on the range picker may be misplaced -->
    <div class="gl-relative">
      <gl-daterange-picker
        v-if="isCustom"
        class="gl-pl-3"
        :default-start-date="customStartDate"
        :default-end-date="customEndDate"
        :default-max-date="customDateRangeMaxDate"
        :max-date-range="customDateRangeLimit"
        same-day-selection
        :to-label="s__('DateRangeFilter|To')"
        :from-label="s__('DateRangeFilter|From')"
        @input="onCustomRangeSelected"
      />
      <human-timeframe
        v-else
        class="gl-text-sm gl-text-subtle"
        :from="value.startDate"
        :till="value.endDate"
      />
    </div>
  </div>
</template>
