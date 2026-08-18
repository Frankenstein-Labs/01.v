<script>
import { GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import TierBadgePopover from './tier_badge_popover.vue';

export default {
  name: 'TierBadge',
  components: {
    GlBadge,
    TierBadgePopover,
  },
  mixins: [Tracking.mixin({ label: 'tier_badge' })],
  props: {
    tier: {
      type: String,
      required: false,
      default: s__('TierBadge|Free'),
    },
  },
  data: () => ({ target: undefined }),
  mounted() {
    this.trackRender();
    this.target = this.$refs.badge?.$el;
  },
  methods: {
    trackRender() {
      this.track('render_badge');
    },
    trackHover() {
      this.track('render_flyout');
    },
  },
};
</script>
<template>
  <span class="gl-ml-2 gl-flex gl-items-center" @mouseover="trackHover">
    <gl-badge ref="badge" data-testid="tier-badge" variant="tier">
      {{ tier }}
    </gl-badge>
    <tier-badge-popover v-if="target" :target="target" triggers="hover focus manual" :tier="tier" />
  </span>
</template>
