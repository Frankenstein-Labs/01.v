<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'EditorLayoutCollapseHeader',
  components: {
    GlButton,
  },
  props: {
    header: {
      type: String,
      required: false,
      default: '',
    },
    collapsed: {
      type: Boolean,
      required: false,
      default: false,
    },
    isRight: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasResetButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['reset-size', 'toggle'],
  computed: {
    iconName() {
      return this.collapsed ? 'chevron-double-lg-right' : 'chevron-double-lg-left';
    },
    iconNameRightName() {
      return this.collapsed ? 'chevron-double-lg-left' : 'chevron-double-lg-right';
    },
    label() {
      return this.collapsed ? __('Expand') : __('Collapse');
    },
  },
};
</script>

<template>
  <div class="gl-gap-x gl-flex gl-items-center">
    <div class="gl-flex gl-flex-grow-2 gl-items-center gl-bg-strong gl-px-4 gl-py-3">
      <gl-button
        v-if="isRight"
        class="gl-mr-3 gl-hidden @lg/panel:gl-block"
        category="tertiary"
        size="small"
        :icon="iconNameRightName"
        :aria-label="label"
        @click="$emit('toggle', !collapsed)"
      />
      <div v-if="!collapsed">
        <h5 class="gl-m-0" data-testid="header">{{ header }}</h5>
      </div>
      <gl-button
        v-if="!isRight"
        class="gl-hidden @lg/panel:gl-block"
        :class="{ 'gl-ml-auto': !collapsed }"
        category="tertiary"
        size="small"
        :icon="iconName"
        :aria-label="label"
        @click="$emit('toggle', !collapsed)"
      />
    </div>
    <gl-button
      v-if="hasResetButton"
      data-testid="reset-button"
      class="security-policies-drag-thumbnail gl-ml-3 !gl-min-h-7 !gl-min-w-6 !gl-rounded-none !gl-border-0 !gl-bg-strong"
      icon="redo"
      size="small"
      :aria-label="__('Reset')"
      @click="$emit('reset-size')"
    />
  </div>
</template>
