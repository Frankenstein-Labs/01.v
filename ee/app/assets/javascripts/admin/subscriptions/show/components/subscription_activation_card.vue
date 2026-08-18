<script>
import { GlCard, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  activateSubscription,
  howToActivateSubscription,
  SUBSCRIPTION_ACTIVATION_FAILURE_EVENT,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
} from '../constants';
import SubscriptionActivationErrors from './subscription_activation_errors.vue';
import SubscriptionActivationForm from './subscription_activation_form.vue';

export const activateSubscriptionUrl = helpPagePath('administration/license', {
  anchor: 'activate-gitlab-ee',
});

export default {
  name: 'SubscriptionActivationCard',
  i18n: {
    activateSubscription,
    howToActivateSubscription,
  },
  components: {
    GlCard,
    GlLink,
    GlSprintf,
    SubscriptionActivationErrors,
    SubscriptionActivationForm,
  },
  links: {
    activateSubscriptionUrl,
  },
  emits: [SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT],
  data() {
    return {
      error: null,
    };
  },
  computed: {
    activationListeners() {
      return {
        [SUBSCRIPTION_ACTIVATION_FAILURE_EVENT]: this.handleActivationFailure,
        [SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT]: this.handleActivationSuccess,
      };
    },
  },
  methods: {
    handleActivationFailure(error) {
      this.error = error;
    },
    handleActivationSuccess(license) {
      // Pass on event to parent listeners
      this.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, license);
    },
  },
};
</script>

<template>
  <gl-card body-class="gl-p-0 gl-bg-subtle">
    <template #header>
      <h5 class="gl-my-0 gl-font-bold">
        {{ $options.i18n.activateSubscription }}
      </h5>
    </template>
    <div v-if="error" class="gl-border-b-1 gl-border-default gl-p-5 gl-border-b-solid">
      <subscription-activation-errors class="!gl-mb-6" :error="error" />
    </div>
    <p class="gl-mb-0 gl-px-5 gl-pt-5">
      <gl-sprintf :message="$options.i18n.howToActivateSubscription">
        <template #link="{ content }">
          <gl-link :href="$options.links.activateSubscriptionUrl" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <subscription-activation-form class="gl-p-5" v-on="activationListeners" />
  </gl-card>
</template>
