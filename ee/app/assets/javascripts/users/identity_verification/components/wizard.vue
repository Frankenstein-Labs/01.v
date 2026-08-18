<script>
import { GlLoadingIcon } from '@gitlab/ui';
import GITLAB_LOGO_SVG_URL from '@gitlab/svgs/dist/illustrations/gitlab_logo.svg?url';
import { kebabCase } from 'lodash-es';
import { mergeUrlParams, visitUrl } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import { convertArrayToCamelCase, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { REDIRECT_TIMEOUT, I18N_GENERIC_ERROR } from '../constants';
import EmailVerification from './email_verification.vue';
import CreditCardVerification from './credit_card_verification.vue';
import PhoneVerification from './phone_verification.vue';
import VerificationStep from './verification_step.vue';

export default {
  name: 'IdentityVerificationWizard',
  components: {
    CreditCardVerification,
    PhoneVerification,
    EmailVerification,
    VerificationStep,
    GlLoadingIcon,
  },
  inject: [
    'verificationStatePath',
    'phoneExemptionPath',
    'successfulVerificationPath',
    'emailVerificationMessage',
    'unifiedRegistration',
  ],
  data() {
    return {
      steps: [],
      stepsVerifiedState: {},
      stepsRequiringChallenge: [],
      loading: true,
    };
  },
  computed: {
    activeStep() {
      const isIncomplete = (step) => !this.stepsVerifiedState[step];
      return this.orderedSteps.find(isIncomplete);
    },
    orderedSteps() {
      return [...this.steps].sort(
        (a, b) => this.stepsVerifiedState[b] - this.stepsVerifiedState[a],
      );
    },
    allStepsCompleted() {
      return !Object.entries(this.stepsVerifiedState).filter(([, completed]) => !completed).length;
    },
  },
  mounted() {
    this.fetchVerificationState();
  },
  methods: {
    async fetchVerificationState() {
      this.loading = true;
      try {
        // Always fetch a fresh copy of the user's identity verification
        // state. This avoids stale data, for example, when the user completes
        // the process, gets redirected to the success page and then uses the
        // browser's back button.
        const url = mergeUrlParams({ no_cache: 1 }, this.verificationStatePath);
        const { data } = await axios.get(url);
        this.setVerificationState(data);
      } catch (error) {
        createAlert({
          message: I18N_GENERIC_ERROR,
          captureError: true,
          error,
        });
      } finally {
        this.loading = false;
      }
    },
    setVerificationState({
      verification_methods,
      verification_state,
      methods_requiring_arkose_challenge: methodsRequiringChallenge,
    }) {
      this.steps = convertArrayToCamelCase(verification_methods);
      this.stepsVerifiedState = convertObjectPropsToCamelCase(verification_state);
      this.stepsRequiringChallenge = convertArrayToCamelCase(methodsRequiringChallenge || []);
    },
    onStepCompleted(step) {
      this.stepsVerifiedState[step] = true;
      if (this.allStepsCompleted) {
        setTimeout(() => visitUrl(this.successfulVerificationPath), REDIRECT_TIMEOUT);
      }
    },
    methodComponent(method) {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      return `${kebabCase(method)}-verification`;
    },
    challengeRequired(method) {
      return this.stepsRequiringChallenge.includes(method);
    },
    stepTitle(step) {
      const { ccStep, phoneStep, emailStep } = this.$options.i18n;
      const templates = {
        creditCard: ccStep,
        phone: phoneStep,
        email: emailStep,
      };
      return templates[step];
    },
    stepSubhead(step) {
      if (step === 'email') {
        return this.emailVerificationMessage;
      }
      return null;
    },
    exemptionRequested() {
      axios
        .patch(this.phoneExemptionPath)
        .then((response) => {
          this.setVerificationState(response.data);
        })
        .catch((error) => {
          createAlert({
            message: I18N_GENERIC_ERROR,
            captureError: true,
            error,
          });
        });
    },
  },
  i18n: {
    pageTitle: s__('IdentityVerification|Help us keep GitLab secure'),
    pageDescription: s__(
      "IdentityVerification|For added security, you'll need to verify your identity.",
    ),
    ccStep: s__('IdentityVerification|Credit card Verification'),
    phoneStep: s__('IdentityVerification|Phone Number Verification'),
    emailStep: s__('IdentityVerification|Email Verification'),
  },
  gitlabLogo: GITLAB_LOGO_SVG_URL,
  gitlabLogoAlt: __('GitLab logo'),
};
</script>
<template>
  <div :class="{ 'gl-flex gl-items-center gl-justify-center': !unifiedRegistration }">
    <div
      class="gl-mt-6 gl-max-w-xl"
      :class="{ 'gl-border gl-grow gl-rounded-lg gl-bg-subtle gl-p-8': !unifiedRegistration }"
    >
      <header :class="{ 'gl-text-center': !unifiedRegistration }">
        <img
          v-if="!unifiedRegistration"
          :src="$options.gitlabLogo"
          :alt="$options.gitlabLogoAlt"
          class="gl-h-9"
        />
        <h1>{{ $options.i18n.pageTitle }}</h1>
        <p class="gl-mb-0">
          {{ $options.i18n.pageDescription }}
        </p>
      </header>

      <gl-loading-icon v-if="loading" class="gl-mt-6" />
      <template v-for="(step, index) in orderedSteps" v-else>
        <verification-step
          :key="step"
          :title="stepTitle(step)"
          :subhead="stepSubhead(step)"
          :completed="stepsVerifiedState[step]"
          :is-active="step === activeStep"
          :total-steps="orderedSteps.length"
          :step-index="index"
        >
          <component
            :is="methodComponent(step)"
            :require-challenge="challengeRequired(step)"
            @completed="onStepCompleted(step)"
            @exemption-requested="exemptionRequested"
            @set-verification-state="setVerificationState"
          />
        </verification-step>
      </template>
    </div>
  </div>
</template>
