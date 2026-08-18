<script>
import { GlToggle } from '@gitlab/ui';

export default {
  name: 'RoadmapToggleLabels',
  components: {
    GlToggle,
  },
  props: {
    isShowingLabels: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['set-labels-visibility'],
  tracking: {
    label: 'roadmap_settings_labels',
    property: 'toggle_labels',
  },
};
</script>

<template>
  <div data-testid="roadmap-labels-settings">
    <gl-toggle
      :value="isShowingLabels"
      :label="__('Show labels')"
      label-position="top"
      aria-describedby="roadmap-labels-toggle-text"
      data-track-action="click_toggle"
      :data-track-label="$options.tracking.label"
      :data-track-property="$options.tracking.property"
      @change="$emit('set-labels-visibility', { isShowingLabels: !isShowingLabels })"
    />
  </div>
</template>
