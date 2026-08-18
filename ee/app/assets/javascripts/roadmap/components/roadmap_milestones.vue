<script>
import { GlFormGroup, GlFormRadioGroup, GlToggle } from '@gitlab/ui';

import { __ } from '~/locale';
import { MILESTONES_OPTIONS } from '../constants';

export default {
  name: 'RoadmapMilestones',
  components: {
    GlFormGroup,
    GlFormRadioGroup,
    GlToggle,
  },
  props: {
    milestonesType: {
      type: String,
      required: true,
    },
    isShowingMilestones: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['set-milestones-settings'],
  methods: {
    handleMilestonesChange(option) {
      if (option !== this.milestonesType) {
        this.$emit('set-milestones-settings', { milestonesType: option });
      }
    },
  },
  i18n: {
    header: __('Milestones'),
    toggleLabel: __('Display milestones'),
  },
  MILESTONES_OPTIONS,
  tracking: {
    label: 'roadmap_settings_milestones',
    property: 'toggle_milestones',
  },
};
</script>

<template>
  <div>
    <gl-form-group
      class="gl-mb-0"
      :label="$options.i18n.header"
      data-testid="roadmap-milestones-settings"
    >
      <gl-toggle
        :value="isShowingMilestones"
        :label="$options.i18n.toggleLabel"
        label-position="hidden"
        data-track-action="click_toggle"
        :data-track-label="$options.tracking.label"
        :data-track-property="$options.tracking.property"
        @change="$emit('set-milestones-settings', { isShowingMilestones: !isShowingMilestones })"
      />
      <gl-form-radio-group
        v-if="isShowingMilestones"
        :checked="milestonesType"
        stacked
        :options="$options.MILESTONES_OPTIONS"
        class="gl-mt-3"
        data-track-action="click_radio"
        :data-track-label="$options.tracking.label"
        :data-track-property="$options.tracking.property"
        @change="handleMilestonesChange"
      />
    </gl-form-group>
  </div>
</template>
