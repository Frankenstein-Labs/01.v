<script>
import { GlButton, GlCard, GlIcon, GlLink, GlPopover } from '@gitlab/ui';
import TrialIllustrationSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-secrets-md.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import { I18N_BILLING_ALERT, I18N_SECRETS_EMPTY_STATE } from 'ee/ci/secrets/constants';

export default {
  name: 'SecretsTrialEmptyState',
  components: {
    GlButton,
    GlCard,
    GlIcon,
    GlLink,
    GlPopover,
  },
  inject: ['entitlement', 'isOpenbaoHealthy', 'isSaas', 'isTrialOnboarding'],
  emits: ['start-trial'],
  computed: {
    showConfigureOpenbaoLink() {
      return !this.isOpenbaoHealthy && !this.isSaas;
    },
    billingInfoTitle() {
      return this.entitlement?.onDemandEnabled
        ? this.$options.billingAlert.onDemandEnabled.title
        : this.$options.billingAlert.onDemandDisabled.title;
    },
  },
  TrialIllustrationSvg,
  CONFIGURE_OPENBAO_LINK: helpPagePath('administration/secrets_manager/_index'),
  GITLAB_CREDITS_DOCS_LINK: helpPagePath('subscriptions/gitlab_credits'),
  billingAlert: I18N_BILLING_ALERT,
  i18n: {
    ...I18N_SECRETS_EMPTY_STATE,
    enablingTrialTitle: s__('SecretsManager|Enabling GitLab Secrets Manager trial'),
    enablingTrialDescription: s__(
      'SecretsManager|Do not close this page until Secrets Manager is finished setting up.',
    ),
  },
};
</script>
<template>
  <gl-card body-class="gl-flex gl-flex-col gl-items-center gl-text-center gl-py-8">
    <template #header>
      <strong>{{ s__('SecretsManager|Secrets') }}</strong>
      <p data-testid="group-subheader" class="gl-mb-0 gl-text-subtle">
        {{ $options.i18n.groupSubheader }}
      </p>
    </template>
    <!-- eslint-disable-next-line @gitlab/vue-require-i18n-attribute-strings -->
    <img :src="$options.TrialIllustrationSvg" alt="" class="gl-mb-4" />
    <h2 class="gl-text-size-h2">
      {{ $options.i18n.title }}
    </h2>
    <p class="gl-mx-auto gl-mb-5 gl-max-w-75">
      {{ $options.i18n.description }}
    </p>
    <gl-button
      v-if="showConfigureOpenbaoLink"
      :href="$options.CONFIGURE_OPENBAO_LINK"
      target="_blank"
      rel="noopener noreferrer"
      data-testid="configure-openbao-link"
    >
      {{ s__('SecretsManager|Configure OpenBao') }}
    </gl-button>
    <gl-button
      v-if="isOpenbaoHealthy"
      ref="startTrialButton"
      variant="confirm"
      category="secondary"
      :loading="isTrialOnboarding"
      data-testid="start-trial-button"
      @click="$emit('start-trial')"
    >
      {{ __('Start 30-day trial') }}
    </gl-button>
    <gl-popover
      :target="() => $refs.startTrialButton"
      :show="isTrialOnboarding"
      :title="$options.i18n.enablingTrialTitle"
      placement="bottom"
      triggers="manual"
    >
      {{ $options.i18n.enablingTrialDescription }}
    </gl-popover>
    <div data-testid="billing-info" class="gl-mt-8">
      <p class="gl-mb-2 gl-font-bold" data-testid="billing-info-title">
        <gl-icon name="information-o" variant="info" class="gl-mr-2" />
        {{ billingInfoTitle }}
      </p>
      <p class="gl-mx-auto gl-max-w-75">
        {{ $options.billingAlert.description }}
      </p>
      <p class="gl-mt-3">
        <gl-link :href="$options.GITLAB_CREDITS_DOCS_LINK" target="_blank">
          {{ $options.billingAlert.linkText }}
        </gl-link>
      </p>
    </div>
  </gl-card>
</template>
