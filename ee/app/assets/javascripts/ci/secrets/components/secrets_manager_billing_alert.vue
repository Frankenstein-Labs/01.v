<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { helpPagePath } from '~/helpers/help_page_helper';
import { I18N_BILLING_ALERT, I18N_OPEN_BETA_ALERT } from 'ee/ci/secrets/constants';

export default {
  name: 'SecretsManagerBillingAlert',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    entitlement: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    showPaidExperience() {
      return this.glFeatures.secretsManagerPaidExperience;
    },
    billingAlertTitle() {
      const { billingAlert } = this.$options.i18n;

      return this.entitlement?.onDemandEnabled
        ? billingAlert.onDemandEnabled.title
        : billingAlert.onDemandDisabled.title;
    },
  },
  GITLAB_CREDITS_DOCS_LINK: helpPagePath('subscriptions/gitlab_credits'),
  i18n: {
    openBetaAlert: I18N_OPEN_BETA_ALERT,
    billingAlert: I18N_BILLING_ALERT,
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <gl-alert
      v-if="showPaidExperience && entitlement"
      variant="info"
      data-testid="billing-alert"
      :dismissible="false"
      :title="billingAlertTitle"
    >
      {{ $options.i18n.billingAlert.description }}
      <gl-link class="gl-inline-block" :href="$options.GITLAB_CREDITS_DOCS_LINK" target="_blank">
        {{ $options.i18n.billingAlert.linkText }}
      </gl-link>
    </gl-alert>
    <gl-alert
      v-else-if="!showPaidExperience"
      variant="warning"
      data-testid="open-beta-billing-alert"
      :dismissible="false"
      :title="$options.i18n.openBetaAlert.title"
    >
      <gl-sprintf :message="$options.i18n.openBetaAlert.description">
        <template #link="{ content }">
          <gl-link
            class="gl-inline-block"
            :href="$options.GITLAB_CREDITS_DOCS_LINK"
            target="_blank"
          >
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
  </div>
</template>
