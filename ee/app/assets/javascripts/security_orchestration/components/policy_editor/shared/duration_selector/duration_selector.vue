<script>
import { GlFormInput, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { isNumeric } from '~/lib/utils/number_utils';
import {
  DEFAULT_TIME_PER_UNIT,
  DEFAULT_TIME_WINDOW,
  MINIMUM_SECONDS,
  TIME_UNITS,
  TIME_UNIT_OPTIONS,
} from './constants';
import {
  determineTimeUnit,
  getMinimumSecondsInMinutes,
  getValueWithinLimits,
  secondsToValue,
  timeUnitToSeconds,
} from './utils';

export default {
  TIME_UNIT_OPTIONS,
  name: 'DurationSelector',
  components: {
    GlCollapsibleListbox,
    GlFormInput,
  },
  props: {
    hasError: {
      type: Boolean,
      required: false,
      default: false,
    },
    timeWindowRequired: {
      type: Boolean,
      required: false,
      default: false,
    },
    minimumSeconds: {
      type: Number,
      required: false,
      default: MINIMUM_SECONDS,
    },
    timeWindow: {
      type: Object,
      required: false,
      default: () => DEFAULT_TIME_WINDOW,
    },
  },
  emits: ['changed'],
  data() {
    const seconds = this.timeWindow?.value || TIME_UNITS.HOUR;
    return {
      selectedTimeUnit: determineTimeUnit(seconds),
    };
  },
  computed: {
    durationValue() {
      const seconds = this.timeWindow?.value || 0;
      // The time_window property is required for PEP, but not for SEP
      const shouldCalculateDuration = this.timeWindowRequired || seconds > 0;

      if (!shouldCalculateDuration) {
        return 0;
      }

      const convertedDuration = Math.floor(secondsToValue(seconds, this.selectedTimeUnit));
      return convertedDuration || getMinimumSecondsInMinutes(this.minimumSeconds);
    },
  },
  created() {
    this.handleUpdateDuration = debounce(
      this.updateDurationValue,
      DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
    );
  },
  destroyed() {
    this.handleUpdateDuration.cancel();
  },
  methods: {
    updateDurationValue(value) {
      if (value && isNumeric(value)) {
        const valueInSeconds = timeUnitToSeconds(parseInt(value, 10), this.selectedTimeUnit);
        // SEP has a min seconds of 3600 while PEP has a min seconds of 600
        const seconds = getValueWithinLimits(valueInSeconds, this.minimumSeconds);
        this.updateTimeWindow(seconds);
      }
    },
    updateDurationUnit(unit) {
      this.selectedTimeUnit = unit;
      // SEP has a min seconds of 3600 while PEP has a min seconds of 600
      this.updateTimeWindow(Math.max(DEFAULT_TIME_PER_UNIT[unit], this.minimumSeconds));
    },
    updateTimeWindow(seconds) {
      const timeWindow = { ...this.timeWindow, value: seconds };
      this.$emit('changed', timeWindow);
    },
  },
};
</script>

<template>
  <div class="duration-selector gl-flex gl-gap-3">
    <gl-form-input
      class="gl-inline-block gl-w-12"
      min="1"
      type="number"
      :aria-label="__('Duration')"
      :placeholder="__('Enter duration')"
      :state="hasError ? false : null"
      :value="durationValue"
      @input="handleUpdateDuration"
    />
    <gl-collapsible-listbox
      :aria-label="__('Time unit')"
      :items="$options.TIME_UNIT_OPTIONS"
      :selected="selectedTimeUnit"
      @select="updateDurationUnit"
    />
  </div>
</template>
