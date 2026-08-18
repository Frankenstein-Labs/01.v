<script>
import { GlButtonGroup, GlButton } from '@gitlab/ui';
import { datesMatch, getDateInPast } from '~/lib/utils/datetime_utility';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import { n__ } from '~/locale';
import { CURRENT_DATE, SAME_DAY_OFFSET } from '../constants';

const DATE_RANGE_OPTIONS = [
  {
    text: n__('Last %d day', 'Last %d days', 7),
    startDate: getDateInPast(CURRENT_DATE, 7 - SAME_DAY_OFFSET),
    endDate: CURRENT_DATE,
  },
  {
    text: n__('Last %d day', 'Last %d days', 14),
    startDate: getDateInPast(CURRENT_DATE, 14 - SAME_DAY_OFFSET),
    endDate: CURRENT_DATE,
  },
  {
    text: n__('Last %d day', 'Last %d days', 30),
    startDate: getDateInPast(CURRENT_DATE, 30 - SAME_DAY_OFFSET),
    endDate: CURRENT_DATE,
  },
];

export default {
  name: 'DateRangeButtons',
  components: {
    GlButton,
    GlButtonGroup,
  },
  props: {
    dateRange: {
      type: Object,
      required: true,
    },
  },
  emits: ['input'],
  methods: {
    onDateRangeClicked({ startDate, endDate }) {
      this.$emit('input', { startDate, endDate });
    },
    isCurrentDateRange({ startDate, endDate }) {
      const { dateRange } = this;
      return datesMatch(startDate, dateRange.startDate) && datesMatch(endDate, dateRange.endDate);
    },
    trackingLabel({ text }) {
      return `date_range_button_${convertToSnakeCase(text)}`;
    },
  },
  DATE_RANGE_OPTIONS,
};
</script>

<template>
  <gl-button-group>
    <gl-button
      v-for="(dateRangeOption, idx) in $options.DATE_RANGE_OPTIONS"
      :key="idx"
      :data-testid="trackingLabel(dateRangeOption)"
      :selected="isCurrentDateRange(dateRangeOption)"
      data-track-action="click_date_range_button"
      :data-track-label="trackingLabel(dateRangeOption)"
      @click="onDateRangeClicked(dateRangeOption)"
      >{{ dateRangeOption.text }}</gl-button
    >
  </gl-button-group>
</template>
