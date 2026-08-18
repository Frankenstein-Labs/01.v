<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getMonthsBetweenDates, getMonthNames } from '~/lib/utils/datetime_utility';

// TODO Get the usage start date from API https://gitlab.com/gitlab-org/opstrace/opstrace/-/issues/2879
const START_DATE = new Date('2024-06-01');

export default {
  name: 'ObservabilityUsagePeriodSelector',
  components: { GlCollapsibleListbox },
  i18n: {
    labelText: s__('Observability|Filter data by month:'),
  },
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  emits: ['input'],
  computed: {
    periods() {
      const monthNames = getMonthNames();

      return getMonthsBetweenDates(START_DATE, new Date())
        .map((period) => ({
          text: `${monthNames[period.month]} ${period.year}`,
          value: JSON.stringify(period),
          valueObj: period,
        }))
        .reverse();
    },
    selectedPeriod() {
      const valueAsStr = JSON.stringify(this.value);
      if (this.findPeriodFromStr(valueAsStr)) {
        return valueAsStr;
      }
      return this.periods[0]?.value;
    },
  },
  methods: {
    onSelect(valueAsStr) {
      const value = this.findPeriodFromStr(valueAsStr);

      if (value) {
        this.$emit('input', value);
      }
    },
    findPeriodFromStr(periodAsStr) {
      return this.periods.find((x) => x.value === periodAsStr)?.valueObj;
    },
  },
};
</script>

<template>
  <div v-if="periods.length">
    <h2 class="gl-heading-4 gl-inline">
      {{ $options.i18n.labelText }}
    </h2>
    <gl-collapsible-listbox :selected="selectedPeriod" :items="periods" @select="onSelect" />
  </div>
</template>
