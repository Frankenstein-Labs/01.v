<script>
import { GlModal, GlSprintf, GlPopover, GlIcon, GlButton, GlLink } from '@gitlab/ui';
import GITLAB_LOGO_SVG_URL from '@gitlab/svgs/dist/illustrations/gitlab_logo.svg?url';
import UserGroupCalloutDismisser from '~/vue_shared/components/user_group_callout_dismisser.vue';
import {
  DUO_CHAT_FEATURE_ID,
  getTrialActiveFeatureHighlights,
} from 'ee/vue_shared/subscription/components/constants';
import { InternalEvents } from '~/tracking';
import { s__, __ } from '~/locale';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'EndOfTrialModal',
  components: {
    GlModal,
    GlSprintf,
    GlPopover,
    GlIcon,
    GlButton,
    GlLink,
    UserGroupCalloutDismisser,
  },
  mixins: [trackingMixin],
  props: {
    featureName: {
      type: String,
      required: true,
    },
    groupId: {
      type: Number,
      required: true,
    },
    groupName: {
      type: String,
      required: true,
    },
    explorePlansPath: {
      type: String,
      required: true,
    },
    upgradeUrl: {
      type: String,
      required: true,
    },
    purchaseCreditsUrl: {
      type: String,
      required: true,
    },
    hasMonthlyCreditCommitment: {
      type: Boolean,
      required: false,
      default: false,
    },
    creditsGeneralizationUi: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    title: s__('EndOfTrialModal|Your trial has ended'),
    body: s__(
      'EndOfTrialModal|Upgrade %{name} to Premium to maintain access to advanced features and keep your workflow running smoothly.',
    ),
    bodyGeneralized: s__(
      'EndOfTrialModal|Upgrade %{name} to Premium for advanced features, or purchase GitLab Credits to power your usage.',
    ),
    explorePlansPrompt: s__(
      'EndOfTrialModal|Not sure which plan is right for you? %{explorePlansLink}.',
    ),
    explorePlans: s__('EndOfTrialModal|Explore plans'),
  },
  gitlabLogoUrl: GITLAB_LOGO_SVG_URL,
  DUO_CHAT_FEATURE_ID,
  computed: {
    bodyMessage() {
      return this.creditsGeneralizationUi
        ? this.$options.i18n.bodyGeneralized
        : this.$options.i18n.body;
    },
    features() {
      const { features } = getTrialActiveFeatureHighlights({
        usePurchaseCreditsCopy: !this.hasMonthlyCreditCommitment,
        purchaseCreditsUrl: this.purchaseCreditsUrl,
        hasMonthlyCreditCommitment: this.hasMonthlyCreditCommitment,
        creditsGeneralizationUi: this.creditsGeneralizationUi,
      });

      return features;
    },
    actionPrimary() {
      return {
        text: __('Upgrade to Premium'),
        attributes: {
          variant: 'confirm',
          href: this.upgradeUrl,
        },
      };
    },
    actionCancel() {
      if (this.hasMonthlyCreditCommitment) {
        return {
          text: s__('EndOfTrialModal|Explore plans'),
          attributes: {
            category: 'secondary',
            variant: 'confirm',
            href: this.explorePlansPath,
          },
        };
      }

      return {
        text: s__('EndOfTrialModal|Purchase GitLab Credits'),
        attributes: {
          category: 'secondary',
          variant: 'confirm',
          href: this.purchaseCreditsUrl,
        },
      };
    },
  },
  methods: {
    isDuoChatFeature(feature) {
      return feature.id === this.$options.DUO_CHAT_FEATURE_ID;
    },
    featureId(id) {
      return `${id}EndOfTrialModal`;
    },
    primary() {
      this.trackEvent('click_upgrade_end_of_trial_modal');
    },
    cancel() {
      if (this.hasMonthlyCreditCommitment) {
        this.trackEvent('click_explore_plans_end_of_trial_modal');
      } else {
        this.trackPurchaseCreditsClick();
      }
    },
    close() {
      this.trackEvent('dismiss_end_of_trial_modal');
    },
    show() {
      this.trackEvent('render_end_of_trial_modal');
    },
    hide(event, dismissFn) {
      if (event.trigger === 'backdrop') {
        this.trackEvent('dismiss_outside_end_of_trial_modal');
      } else if (event.trigger === 'esc') {
        this.trackEvent('dismiss_esc_end_of_trial_modal');
      }

      dismissFn();
    },
    popoverShow(id) {
      this.trackEvent('render_premium_feature_popover_end_of_trial_modal', {
        property: id,
      });
    },
    popoverClick(id) {
      this.trackEvent('click_cta_premium_feature_popover_end_of_trial_modal', {
        property: id,
      });
      if (id === DUO_CHAT_FEATURE_ID && !this.creditsGeneralizationUi) {
        this.trackPurchaseCreditsClick();
      }
    },
    trackPurchaseCreditsClick() {
      this.trackEvent('click_purchase_credits_cta_active_trial', {
        property: 'end_of_trial_modal',
      });
    },
  },
};
</script>

<template>
  <user-group-callout-dismisser :feature-name="featureName" :group-id="groupId" skip-query>
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-modal
        size="sm"
        no-focus-on-show
        modal-id="end-of-trial-modal"
        data-testid="end-of-trial-modal"
        :title="$options.i18n.title"
        :visible="shouldShowCallout"
        :action-primary="actionPrimary"
        :action-cancel="actionCancel"
        @primary="primary"
        @cancel="cancel"
        @close="close"
        @show="show"
        @hide="hide($event, dismiss)"
      >
        <template #modal-header>
          <div class="gl-m-auto">
            <img
              :alt="__('GitLab logo')"
              :src="$options.gitlabLogoUrl"
              class="gl-ml-7 gl-h-9 gl-w-9"
            />
          </div>
        </template>
        <div class="gl-text-center">
          <div class="gl-heading-1-fixed">{{ $options.i18n.title }}</div>

          <gl-sprintf :message="bodyMessage">
            <template #name>
              <span class="gl-font-bold">{{ groupName }}</span>
            </template>
          </gl-sprintf>
          <gl-sprintf
            v-if="!hasMonthlyCreditCommitment"
            :message="$options.i18n.explorePlansPrompt"
          >
            <template #explorePlansLink>
              <gl-link :href="explorePlansPath">{{ $options.i18n.explorePlans }}</gl-link>
            </template>
          </gl-sprintf>
        </div>

        <div class="gl-flex gl-px-3 gl-pb-4 gl-pt-6">
          <div class="gl-mt-1 gl-flex gl-basis-3/5 gl-flex-col">
            <div class="gl-h-9"></div>

            <div class="gl-border-t gl-flex gl-h-12 gl-items-center sm:gl-h-9">
              <span class="gl-ml-5">{{
                s__('EndOfTrialModal|Source Code Management & CI/CD')
              }}</span>
            </div>

            <template v-for="feature in features">
              <div
                :key="featureId(feature.id)"
                class="gl-border-t gl-flex gl-h-11 gl-items-center sm:gl-h-9"
              >
                <span :id="featureId(feature.id)" class="gl-ml-5 gl-underline">{{
                  feature.title
                }}</span>

                <gl-popover
                  :target="featureId(feature.id)"
                  :title="feature.title"
                  show-close-button
                  @shown="popoverShow(feature.id)"
                >
                  <gl-sprintf
                    v-if="feature.descriptionWithCreditsLink"
                    :message="feature.descriptionWithCreditsLink"
                  >
                    <template #creditsLink="{ content }">
                      <gl-link :href="feature.docsLink" target="_blank">{{ content }}</gl-link>
                    </template>
                  </gl-sprintf>
                  <template v-else>
                    {{ feature.descriptionWithoutCredits || feature.description }}
                  </template>

                  <gl-button
                    v-if="!feature.hideButton"
                    target="_blank"
                    data-testid="end-of-trial-modal-popover-buttons"
                    class="gl-mt-3 gl-w-full"
                    :href="feature.purchaseCreditsUrl || feature.docsLink"
                    variant="confirm"
                    @click="popoverClick(feature.id)"
                  >
                    {{ feature.buttonText || __('Learn more') }}
                  </gl-button>
                </gl-popover>
              </div>
            </template>
          </div>

          <div class="gl-mt-1 gl-flex gl-basis-1/5 gl-flex-col gl-text-center">
            <div class="gl-flex gl-h-9 gl-items-center gl-justify-center gl-font-bold">
              {{ __('Free') }}
            </div>

            <div class="gl-border-t gl-flex gl-h-12 gl-items-center gl-justify-center sm:gl-h-9">
              <gl-icon name="check" />
            </div>

            <template v-for="feature in features">
              <div
                :key="featureId(feature.id)"
                class="gl-border-t gl-flex gl-h-11 gl-items-center gl-justify-center sm:gl-h-9"
              >
                <gl-icon
                  :name="
                    hasMonthlyCreditCommitment && isDuoChatFeature(feature) ? 'check' : 'close'
                  "
                />
              </div>
            </template>
          </div>

          <div class="gradient-border gl-border gl-flex gl-basis-1/5 gl-flex-col gl-text-center">
            <div class="gl-mx-3 gl-flex gl-h-9 gl-items-center gl-justify-center gl-font-bold">
              {{ __('Premium') }}
            </div>

            <div class="gl-border-t gl-flex gl-h-12 gl-items-center gl-justify-center sm:gl-h-9">
              <gl-icon name="check" />
            </div>

            <template v-for="feature in features">
              <div
                :key="featureId(feature.id)"
                class="gl-border-t gl-flex gl-h-11 gl-items-center gl-justify-center sm:gl-h-9"
              >
                <gl-icon name="check" />
              </div>
            </template>
          </div>
        </div>
      </gl-modal>
    </template>
  </user-group-callout-dismisser>
</template>

<style>
.gradient-border {
  border: 2px solid transparent;
  border-radius: 0.5rem;
  background-origin: border-box;
  background-clip: content-box, border-box;
  background-image:
    linear-gradient(var(--gl-background-color-overlap)),
    linear-gradient(to bottom, #ff31e0, #c80043);
}
</style>
