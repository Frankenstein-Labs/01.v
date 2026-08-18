<script>
import { GlProgressBar, GlButton } from '@gitlab/ui';
import { snakeCase } from 'lodash-es';
import { sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import UserGroupCalloutDismisser from '~/vue_shared/components/user_group_callout_dismisser.vue';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import {
  TRIAL_WIDGET_REMAINING_DAYS,
  TRIAL_WIDGET_SEE_UPGRADE_OPTIONS,
  TRIAL_WIDGET_DISMISS,
  TRIAL_WIDGET_CONTAINER_ID,
  TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  TRIAL_WIDGET_CLICK_DISMISS,
  TRIAL_TYPES_CONFIG,
} from './constants';
import TrialWidgetButtons from './trial_widget_buttons.vue';

export default {
  name: 'TrialWidget',
  components: {
    GlProgressBar,
    GlButton,
    TrialWidgetButtons,
    UserGroupCalloutDismisser,
    UserCalloutDismisser,
  },

  mixins: [InternalEvents.mixin()],

  inject: {
    trialType: { default: '' },
    daysRemaining: { default: 0 },
    percentageComplete: { default: 0 },
    groupId: { default: '' },
    featureId: { default: '' },
  },

  trialWidget: {
    containerId: TRIAL_WIDGET_CONTAINER_ID,
    dismissLabel: TRIAL_WIDGET_DISMISS,
    upgradeOptionsText: TRIAL_WIDGET_SEE_UPGRADE_OPTIONS,
    upgradeThresholdDays: TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  },

  computed: {
    currentTrialType() {
      return TRIAL_TYPES_CONFIG[this.trialType];
    },
    widgetRemainingDays() {
      return sprintf(TRIAL_WIDGET_REMAINING_DAYS, {
        daysLeft: this.daysRemaining,
      });
    },
    widgetTitle() {
      return this.currentTrialType.widgetTitle;
    },
    expiredWidgetTitleText() {
      return this.currentTrialType.widgetTitleExpiredTrial;
    },
    isTrialActive() {
      return this.daysRemaining > 0;
    },
    isDismissable() {
      return this.featureId;
    },
    trackingLabel() {
      return snakeCase(this.currentTrialType.name.toLowerCase());
    },
    dismisserComponent() {
      return this.groupId ? 'user-group-callout-dismisser' : 'user-callout-dismisser';
    },
    dismisserAttrs() {
      return {
        'feature-name': this.featureId,
        'skip-query': true,
        ...(this.groupId && { 'group-id': this.groupId }),
      };
    },
  },

  methods: {
    handleDismiss(dismissFn) {
      dismissFn();

      this.trackEvent(TRIAL_WIDGET_CLICK_DISMISS, {
        label: this.trackingLabel,
      });
    },
  },
};
</script>

<template>
  <component :is="dismisserComponent" v-bind="dismisserAttrs">
    <template #default="{ dismiss, shouldShowCallout }">
      <div
        v-if="shouldShowCallout"
        :id="$options.trialWidget.containerId"
        class="gl-relative gl-m-2 gl-bg-default gl-p-4 gl-shadow"
        data-testid="trial-widget-root-element"
      >
        <div data-testid="trial-widget-menu" class="gl-flex gl-w-full gl-flex-col gl-items-stretch">
          <div v-if="isTrialActive">
            <div class="gl-flex-column gl-w-full">
              <div data-testid="widget-title" class="gl-mb-4 gl-font-bold gl-text-heading">
                {{ widgetTitle }}
              </div>
              <gl-progress-bar
                :value="percentageComplete"
                class="custom-gradient-progress gl-mb-3 gl-bg-status-brand"
                aria-hidden="true"
              />
              <p class="gl-mb-4 gl-text-subtle">
                {{ widgetRemainingDays }}
              </p>
              <trial-widget-buttons data-testid="widget-cta" />
            </div>
          </div>
          <div v-else class="gl-flex gl-w-full gl-flex-col gl-items-stretch">
            <div class="gl-w-full">
              <div data-testid="widget-title" class="gl-mb-4 gl-font-bold gl-text-heading">
                {{ expiredWidgetTitleText }}
              </div>
              <div class="gl-mb-4">
                <gl-progress-bar
                  :value="100"
                  class="custom-gradient-progress gl-mb-3"
                  aria-hidden="true"
                />
              </div>
              <trial-widget-buttons data-testid="widget-cta" />
            </div>
          </div>
        </div>
        <gl-button
          v-if="isDismissable && !isTrialActive"
          class="gl-absolute gl-right-0 gl-top-0 gl-mr-2 gl-mt-2"
          size="small"
          icon="close"
          category="tertiary"
          data-testid="dismiss-btn"
          :aria-label="$options.trialWidget.dismissLabel"
          @click="handleDismiss(dismiss)"
        />
      </div>
    </template>
  </component>
</template>
