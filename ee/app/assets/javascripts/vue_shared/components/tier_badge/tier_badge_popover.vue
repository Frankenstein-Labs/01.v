<script>
import { GlPopover, GlButton } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import Tracking from '~/tracking';

export default {
  name: 'TierBadgePopover',
  components: {
    GlPopover,
    GlButton,
  },
  mixins: [Tracking.mixin({ label: 'tier_badge' })],
  inject: ['primaryCtaLink', 'secondaryCtaLink', 'isProject', 'trialDuration'],
  props: {
    target: {
      type: HTMLElement,
      required: true,
    },
    tier: {
      type: String,
      required: true,
    },
  },
  computed: {
    copyText() {
      const { groupCopyStart, projectCopyStart, copyEnd } = this.$options.i18n;
      const copyStart = this.isProject ? projectCopyStart : groupCopyStart;

      return sprintf(copyStart, { tier: this.tier, copyEnd: copyEnd(this.trialDuration) });
    },
  },
  methods: {
    trackPrimaryCta() {
      this.track('click_start_trial_button');
    },
    trackSecondaryCta() {
      this.track('click_compare_plans_button');
    },
  },
  i18n: {
    title: s__('TierBadgePopover|Enhance team productivity'),
    groupCopyStart: s__(
      `TierBadgePopover|This group and all its related projects use the %{tier} GitLab tier. %{copyEnd}`,
    ),
    projectCopyStart: s__(`TierBadgePopover|This project uses the %{tier} GitLab tier. %{copyEnd}`),
    copyEnd: (duration) =>
      sprintf(
        s__(
          'TierBadgePopover|Want to enhance team productivity and access advanced features like Merge Approvals, Push rules, Epics, Code Review Analytics, and Container Scanning? Try all GitLab has to offer for free for %{duration} days. No credit card required.',
        ),
        { duration },
      ),
    primaryCtaText: s__('TierBadgePopover|Start a free trial'),
    secondaryCtaText: s__('TierBadgePopover|Explore paid plans'),
  },
};
</script>

<template>
  <gl-popover :title="$options.i18n.title" :target="target" placement="bottom">
    <div class="gl-mb-3">
      {{ copyText }}
    </div>

    <gl-button
      :href="primaryCtaLink"
      class="gl-my-2 gl-w-full"
      variant="confirm"
      data-testid="tier-badge-popover-primary-cta"
      @click="trackPrimaryCta"
      >{{ $options.i18n.primaryCtaText }}</gl-button
    >
    <gl-button
      :href="secondaryCtaLink"
      class="gl-my-2 gl-w-full"
      variant="confirm"
      category="secondary"
      data-testid="tier-badge-popover-secondary-cta"
      @click="trackSecondaryCta"
      >{{ $options.i18n.secondaryCtaText }}</gl-button
    >
  </gl-popover>
</template>
