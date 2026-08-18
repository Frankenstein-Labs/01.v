<script>
import { GlDaterangePicker } from '@gitlab/ui';
import { dateAtFirstDayOfMonth, getDateInPast } from '~/lib/utils/datetime_utility';
import { __, n__, sprintf } from '~/locale';
import { CURRENT_DATE, MAX_DATE_RANGE } from '../constants';
import DateRangeButtons from './date_range_buttons.vue';

export default {
  name: 'DateRangeField',
  components: {
    DateRangeButtons,
    GlDaterangePicker,
  },
  props: {
    startDate: {
      type: Date,
      required: false,
      default: null,
    },
    endDate: {
      type: Date,
      required: false,
      default: null,
    },
  },
  emits: ['selected'],
  computed: {
    defaultStartDate() {
      return this.startDate || dateAtFirstDayOfMonth(CURRENT_DATE);
    },
    defaultEndDate() {
      return this.endDate || CURRENT_DATE;
    },
    defaultDateRange() {
      return { startDate: this.defaultStartDate, endDate: this.defaultEndDate };
    },
  },
  methods: {
    onInput({ startDate, endDate }) {
      if (!startDate && endDate) {
        this.$emit('selected', { startDate: getDateInPast(endDate, 1), endDate });
      } else {
        this.$emit('selected', { startDate, endDate });
      }
    },
    daysSelectedMessage(daysSelected) {
      return n__('1 day selected', '%d days selected', daysSelected);
    },
  },
  CURRENT_DATE,
  MAX_DATE_RANGE,
  i18n: {
    dateRangeTooltip: sprintf(__('Date range limited to %{number} days'), {
      number: MAX_DATE_RANGE,
    }),
  },
};
</script>

<template>
  <div class="gl-mb-3 gl-flex gl-flex-col gl-gap-3 @md/panel:gl-flex-row">
    <date-range-buttons :date-range="defaultDateRange" @input="onInput" />
    <gl-daterange-picker
      class="daterange-picker @md/panel:gl-flex"
      :default-start-date="defaultStartDate"
      :default-end-date="defaultEndDate"
      :default-max-date="$options.CURRENT_DATE"
      :max-date-range="$options.MAX_DATE_RANGE"
      :same-day-selection="true"
      :tooltip="$options.i18n.dateRangeTooltip"
      start-picker-class="@md/panel:gl-flex @lg/panel:gl-items-end"
      end-picker-class="@md/panel:gl-flex @lg/panel:gl-items-end"
      date-range-indicator-class="gl-whitespace-nowrap"
      @input="onInput"
    >
      <template #default="{ daysSelected }">
        <template v-if="daysSelected > 0">
          {{ daysSelectedMessage(daysSelected) }}
        </template>
      </template>
    </gl-daterange-picker>
  </div>
</template>
