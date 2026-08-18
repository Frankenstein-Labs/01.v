<script>
import { GlCollapsibleListbox, GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';

import { __, s__ } from '~/locale';

import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';
import {
  getPresetTypeForTimeframeRangeType,
  getTimeframeForRangeType,
  mapLocalSettings,
} from '../utils/roadmap_utils';
import { PRESET_TYPES, DATE_RANGES } from '../constants';

export default {
  name: 'RoadmapDaterange',
  availableDateRanges: [
    { text: s__('GroupRoadmap|This quarter'), value: DATE_RANGES.CURRENT_QUARTER },
    { text: s__('GroupRoadmap|This year'), value: DATE_RANGES.CURRENT_YEAR },
    { text: s__('GroupRoadmap|Within 3 years'), value: DATE_RANGES.THREE_YEARS },
  ],
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormRadioGroup,
  },
  emits: ['set-date-range'],
  data() {
    return {
      initialSelectedDaterange: null,
      selectedDaterange: null,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
      result({ data }) {
        this.selectedDaterange = data.localRoadmapSettings.timeframeRangeType;
      },
    },
  },
  computed: {
    ...mapLocalSettings(['presetType']),
    availablePresets() {
      const quarters = { text: __('By quarter'), value: PRESET_TYPES.QUARTERS };
      const months = { text: __('By month'), value: PRESET_TYPES.MONTHS };
      const weeks = { text: __('By week'), value: PRESET_TYPES.WEEKS };

      if (this.selectedDaterange === DATE_RANGES.CURRENT_YEAR) {
        return [months, weeks];
      }
      if (this.selectedDaterange === DATE_RANGES.THREE_YEARS) {
        return [quarters, months, weeks];
      }
      return [];
    },
  },
  methods: {
    handleDaterangeDropdownOpen() {
      this.initialSelectedDaterange = this.selectedDaterange;
    },
    handleDaterangeDropdownClose() {
      if (this.initialSelectedDaterange !== this.selectedDaterange) {
        this.setDaterange({
          timeframeRangeType: this.selectedDaterange,
          presetType: getPresetTypeForTimeframeRangeType(this.selectedDaterange),
        });
      }
    },
    handleRoadmapLayoutChange(presetType) {
      if (presetType !== this.presetType) {
        this.setDaterange({ timeframeRangeType: this.selectedDaterange, presetType });
      }
    },
    setDaterange({ timeframeRangeType, presetType }) {
      const timeframe = getTimeframeForRangeType({
        timeframeRangeType,
        presetType,
      });
      this.$emit('set-date-range', { timeframeRangeType, presetType, timeframe });
    },
  },
  i18n: {
    header: __('Date range'),
  },
};
</script>

<template>
  <div>
    <label for="roadmap-daterange" class="gl-block">{{ $options.i18n.header }}</label>
    <gl-collapsible-listbox
      id="roadmap-daterange"
      v-model="selectedDaterange"
      icon="calendar"
      class="roadmap-daterange-dropdown"
      data-testid="daterange-dropdown"
      :items="$options.availableDateRanges"
      @shown="handleDaterangeDropdownOpen"
      @hidden="handleDaterangeDropdownClose"
    />
    <gl-form-group v-if="availablePresets.length" class="gl-mb-0 gl-mt-3">
      <gl-form-radio-group
        data-testid="daterange-presets"
        :checked="presetType"
        stacked
        :options="availablePresets"
        @input="handleRoadmapLayoutChange"
      />
    </gl-form-group>
  </div>
</template>
