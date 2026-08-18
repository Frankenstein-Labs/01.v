<script>
import { GlIcon, GlPopover, GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'FeatureItem',
  components: {
    GlIcon,
    GlPopover,
    GlButton,
  },
  mixins: [trackingMixin],
  props: {
    id: {
      type: String,
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: null,
    },
    link: {
      type: String,
      required: false,
      default: null,
    },
    openPopoverId: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['popover-toggle'],
  computed: {
    isPopoverOpen() {
      return this.openPopoverId === this.id;
    },
  },
  methods: {
    handleFeatureClick() {
      this.$emit('popover-toggle', this.id);
    },
    handlePopoverClose() {
      // Only emit if this popover is currently open
      // This prevents emitting when hidden due to another popover opening
      if (this.isPopoverOpen) {
        this.$emit('popover-toggle', this.id);
      }
    },
    popoverShow() {
      this.trackEvent('render_premium_feature_popover_discover', {
        property: this.id,
      });
    },
    popoverClick() {
      this.trackEvent('click_cta_premium_feature_popover_discover', {
        property: this.id,
      });
    },
  },
};
</script>

<template>
  <div class="gl-mb-4 gl-flex gl-items-center gl-gap-4">
    <gl-icon name="check" :size="16" class="gl-flex-shrink-0" />
    <div v-if="description" class="gl-flex-grow-1">
      <button
        :id="id"
        class="gl-cursor-pointer gl-border-0 gl-bg-transparent gl-p-0 gl-underline"
        :aria-expanded="String(isPopoverOpen)"
        :aria-controls="`popover-${id}`"
        @click="handleFeatureClick"
      >
        {{ text }}
      </button>
      <gl-popover
        :id="`popover-${id}`"
        placement="top"
        :target="id"
        triggers="manual"
        :show-close-button="true"
        :show="isPopoverOpen"
        @shown="popoverShow"
        @hidden="handlePopoverClose"
      >
        <template #title>
          {{ text }}
        </template>
        <p class="gl-mb-3 gl-text-subtle">{{ description }}</p>
        <gl-button
          v-if="link"
          :href="link"
          target="_blank"
          rel="noopener noreferrer"
          category="primary"
          variant="confirm"
          class="gl-w-full"
          @click="popoverClick"
        >
          {{ __('Learn more') }}
        </gl-button>
      </gl-popover>
    </div>
    <div v-else>
      {{ text }}
    </div>
  </div>
</template>
