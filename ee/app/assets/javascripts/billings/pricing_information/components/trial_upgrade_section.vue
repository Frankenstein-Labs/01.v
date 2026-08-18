<script>
import { GlIcon, GlButton, GlLink, GlPopover } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { focusDuoChatInput } from 'ee/ai/utils';
import {
  DUO_CHAT_FEATURE_ID,
  getTrialActiveFeatureHighlights,
} from 'ee/vue_shared/subscription/components/constants';

export default {
  name: 'TrialUpgradeSection',
  components: {
    GlIcon,
    GlButton,
    GlPopover,
    GlLink,
  },
  mixins: [InternalEvents.mixin()],
  DUO_CHAT_FEATURE_ID,
  props: {
    groupId: {
      type: Number,
      required: true,
    },
    groupBillingHref: {
      type: String,
      required: true,
    },
    canAccessDuoChat: {
      type: Boolean,
      required: true,
    },
    exploreLinks: {
      type: Object,
      required: true,
    },
  },
  computed: {
    trialActiveFeatureHighlights() {
      return getTrialActiveFeatureHighlights();
    },
  },
  methods: {
    isDuoChatFeature(feature) {
      return feature.id === this.$options.DUO_CHAT_FEATURE_ID;
    },
    handleExploreLinkClick(id) {
      if (id === this.$options.DUO_CHAT_FEATURE_ID && this.canAccessDuoChat) {
        focusDuoChatInput();
      }

      this.trackEvent('click_cta_premium_feature_popover_on_billings', {
        property: id,
      });
    },
    handlePopoverHover(id) {
      this.trackEvent('render_premium_feature_popover_on_billings', {
        property: id,
      });
    },
    featureButtonText(feature) {
      return (
        feature.buttonText ||
        sprintf(s__('BillingPlans|Explore %{feature}'), { feature: feature.title })
      );
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-y-5">
    <h3 class="gl-heading-3 gl-m-0 gl-text-default">
      {{ trialActiveFeatureHighlights.header }}
    </h3>
    <p class="gl-font-weight-semibold gl-m-0 gl-text-subtle">
      {{ trialActiveFeatureHighlights.subheader }}
    </p>

    <div>
      <ul class="gl-mb-4 gl-flex gl-list-none gl-flex-col gl-gap-y-4 gl-p-0">
        <li
          v-for="feature in trialActiveFeatureHighlights.features"
          :key="feature.id"
          class="gl-flex gl-items-center gl-gap-3"
          data-testid="feature-highlight"
        >
          <div :id="feature.id">
            <gl-icon :name="feature.iconName" class="gl-mr-2 gl-mt-1" :variant="feature.variant" />
            <span class="gl-text-base gl-underline">{{ feature.title }}</span>
          </div>

          <gl-popover
            :target="feature.id"
            :title="feature.title"
            show-close-button
            @shown="handlePopoverHover(feature.id)"
          >
            {{ feature.description }}

            <gl-link :href="feature.docsLink" target="_blank">
              {{ s__('BillingPlans|Learn more.') }}
            </gl-link>

            <gl-button
              v-if="exploreLinks[feature.id] || isDuoChatFeature(feature)"
              class="gl-mt-3 gl-w-full"
              :href="feature.buttonText ? feature.docsLink : exploreLinks[feature.id]"
              variant="confirm"
              @click="handleExploreLinkClick(feature.id)"
            >
              {{ featureButtonText(feature) }}
            </gl-button>
          </gl-popover>
        </li>
      </ul>
      <gl-link
        :href="groupBillingHref"
        data-event-tracking="click_link_compare_plans"
        :data-event-property="groupId"
        data-testid="compare-plans-link"
      >
        {{ s__('Billings|See all features and compare plans') }}
      </gl-link>
    </div>

    <p class="gl-m-0 gl-text-subtle">
      {{
        s__('Billings|Upgrade before your trial ends to maintain access to these Premium features.')
      }}
    </p>
  </div>
</template>
