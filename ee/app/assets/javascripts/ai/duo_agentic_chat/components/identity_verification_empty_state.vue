<script>
import { GlButton, GlCard, GlIcon } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from '../../constants';

export default {
  name: 'IdentityVerificationEmptyState',
  components: {
    GlButton,
    GlCard,
    GlIcon,
    TanukiAiIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    identityVerificationPath: {
      type: String,
      required: true,
    },
  },
  mounted() {
    this.trackEvent(DUO_PANEL_EMPTY_STATE_EVENTS.VIEW_IDENTITY_VERIFICATION);
  },
  trackingEvents: DUO_PANEL_EMPTY_STATE_EVENTS,
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4">
    <tanuki-ai-icon />

    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgentsPlatform|Identity Verification required') }}
    </h2>
    <p class="gl-m-0 gl-text-subtle" data-testid="empty-state-text">
      {{
        s__(
          'DuoAgentsPlatform|Before you can use GitLab Duo Agent Platform, we need to verify your account.',
        )
      }}
    </p>
    <gl-card class="gl-mt-3 gl-w-full">
      <template #header>
        <span class="gl-font-bold">{{ s__('DuoAgentsPlatform|Get access to GitLab Duo') }}</span>
      </template>
      <div class="gl-flex gl-flex-col gl-gap-4">
        <div class="gl-flex gl-gap-x-2">
          <div><gl-icon name="user" /></div>
          <div>
            <div class="gl-font-bold gl-text-strong">
              {{ s__('DuoAgentsPlatform|We need to verify your account') }}
            </div>
            <div class="gl-text-subtle">
              {{
                s__(
                  `DuoAgentsPlatform|We won't ask you for this information again. It will never be used for marketing purposes.`,
                )
              }}
            </div>
            <gl-button
              variant="confirm"
              category="primary"
              class="gl-mt-3"
              :href="identityVerificationPath"
              data-event-tracking="click_link"
              :data-event-label="$options.trackingEvents.CLICK_VERIFY_ACCOUNT"
              data-testid="verify-account-link"
            >
              {{ s__('DuoAgentsPlatform|Verify my account') }}
            </gl-button>
          </div>
        </div>
      </div>
    </gl-card>
  </div>
</template>
