import Vue from 'vue';
import TierBadge from 'ee/vue_shared/components/tier_badge/tier_badge.vue';
import { parseBoolean } from '~/lib/utils/common_utils';

export default function initTierBadgeTrigger() {
  const el = document.querySelector('.js-tier-badge-trigger');

  if (!el) {
    return false;
  }

  const { primaryCtaLink, secondaryCtaLink, trialDuration, isProject } = el.dataset;

  return new Vue({
    el,
    name: 'TierBadgeTriggerRoot',
    components: {
      TierBadge,
    },
    provide: {
      primaryCtaLink,
      secondaryCtaLink,
      trialDuration,
      isProject: parseBoolean(isProject),
    },
    render(createElement) {
      return createElement(TierBadge, { attrs: { 'data-testid': 'group-tier-badge' } });
    },
  });
}
