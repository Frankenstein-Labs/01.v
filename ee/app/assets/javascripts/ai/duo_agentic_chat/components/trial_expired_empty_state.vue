<script>
import { GlButton } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from '../../constants';

export default {
  name: 'TrialExpiredEmptyState',
  components: {
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    canBuyAddon: {
      type: Boolean,
      required: true,
    },
    buyAddonPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    showUpgradeCta() {
      return Boolean(this.canBuyAddon && this.buyAddonPath);
    },
  },
  mounted() {
    this.trackEvent(DUO_PANEL_EMPTY_STATE_EVENTS.VIEW_TRIAL_EXPIRED);
  },
  methods: {
    onUpgradeClick() {
      this.trackEvent(DUO_PANEL_EMPTY_STATE_EVENTS.CLICK_TRIAL_EXPIRED_UPGRADE);
    },
    onLearnMoreClick() {
      this.trackEvent(DUO_PANEL_EMPTY_STATE_EVENTS.CLICK_TRIAL_EXPIRED_LEARN_MORE);
    },
  },
  tanukiAiSvgUrl,
  dapDocs: helpPagePath('/user/duo_agent_platform/_index.md'),
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4">
    <img
      :src="$options.tanukiAiSvgUrl"
      class="gl-h-10 gl-w-10"
      :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
    />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|Your GitLab Duo Agent Platform trial has ended') }}
    </h2>
    <p class="gl-m-0 gl-text-subtle" data-testid="empty-state-text">
      {{
        s__(
          'DuoAgenticChat|Your trial has ended. Repurchase to resume using GitLab Duo Agent Platform.',
        )
      }}
    </p>
    <div class="gl-flex gl-gap-3">
      <gl-button
        v-if="showUpgradeCta"
        variant="confirm"
        category="primary"
        :href="buyAddonPath"
        data-testid="upgrade-button"
        @click="onUpgradeClick"
      >
        {{ s__('DuoAgenticChat|Upgrade to Premium') }}
      </gl-button>
      <gl-button
        :href="$options.dapDocs"
        target="_blank"
        data-testid="learn-more-button"
        @click="onLearnMoreClick"
      >
        {{ __('Learn more') }}
      </gl-button>
    </div>
  </div>
</template>
