<script>
import { GlButton } from '@gitlab/ui';
import { createAlert, VARIANT_INFO } from '~/alert';
import Poll from '~/lib/utils/poll';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import { calculateRemainingMilliseconds, isValidDateString } from '~/lib/utils/datetime_utility';
import { I18N_PHONE_NUMBER_VERIFICATION_UNAVAILABLE } from '../constants';
import InternationalPhoneInput from './international_phone_input.vue';
import VerifyPhoneVerificationCode from './verify_phone_verification_code.vue';
import Captcha from './identity_verification_captcha.vue';

export default {
  name: 'PhoneVerification',
  components: {
    GlButton,
    InternationalPhoneInput,
    VerifyPhoneVerificationCode,
    Captcha,
  },
  inject: ['verificationStatePath', 'phoneNumber', 'offerPhoneNumberExemption'],
  props: {
    requireChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['completed', 'exemption-requested', 'set-verification-state'],
  data() {
    return {
      stepIndex: 1,
      latestPhoneNumber: {},
      sendAllowedAfter: null,
      verificationAttempts: 0,
      disableSubmitButton: false,
      captchaData: {},
      poll: null,
    };
  },
  computed: {
    sendCodeAllowed() {
      if (!this.sendAllowedAfter) return true;

      return calculateRemainingMilliseconds(new Date(this.sendAllowedAfter).getTime()) < 1;
    },
  },
  mounted() {
    this.setSendAllowedOn(this.phoneNumber?.sendAllowedAfter);
  },
  beforeDestroy() {
    this.stopPolling();
  },
  methods: {
    fetchVerificationState() {
      return axios.get(this.verificationStatePath);
    },
    goToStepTwo({ sendAllowedAfter, ...phoneNumber }) {
      this.stepIndex = 2;
      this.latestPhoneNumber = phoneNumber;
      this.setSendAllowedOn(sendAllowedAfter);
      this.startPolling();
    },
    goToStepOne() {
      this.stepIndex = 1;
    },
    setVerified() {
      this.$emit('completed');
    },
    increaseVerificationAttempts() {
      this.verificationAttempts += 1;
    },
    onCaptchaShown() {
      this.disableSubmitButton = true;
    },
    onCaptchaSolved(data) {
      this.disableSubmitButton = false;
      this.captchaData = data;
    },
    onCaptchaReset() {
      this.disableSubmitButton = true;
      this.captchaData = {};
    },
    setSendAllowedOn(sendAllowedAfter) {
      this.sendAllowedAfter = isValidDateString(sendAllowedAfter) ? sendAllowedAfter : null;
    },
    resetTimer() {
      this.setSendAllowedOn(null);
    },
    startPolling() {
      // Poll for possible change in required verification methods for the user.
      // Specifically, if the user is from a country blocked by Telesign, we
      // auto-request a phone number verification exemption for them. When this
      // happens 'phone' is removed from the `verification_methods` array.
      this.poll = new Poll({
        resource: {
          fetchData: () => this.fetchVerificationState(),
        },
        method: 'fetchData',
        successCallback: ({ data }) => {
          if (!data.verification_methods.includes('phone')) {
            createAlert({
              message: I18N_PHONE_NUMBER_VERIFICATION_UNAVAILABLE,
              variant: VARIANT_INFO,
            });

            this.stopPolling();
            this.$emit('set-verification-state', data);
          }
        },
        errorCallback: () => {
          this.stopPolling();
        },
      });

      // Wait five seconds before first poll request to take into account the
      // delay of receiving SMS delivery notification callback request.
      this.poll.makeDelayedRequest(5000);
    },
    stopPolling() {
      this.poll?.stop();
      this.poll = null;
    },
  },
  i18n: {
    verifyWithCreditCard: s__('IdentityVerification|Verify with a credit card instead?'),
  },
};
</script>
<template>
  <div>
    <international-phone-input
      v-if="stepIndex == 1"
      :disable-submit-button="disableSubmitButton"
      :additional-request-params="captchaData"
      :send-code-allowed="sendCodeAllowed"
      :send-code-allowed-after="sendAllowedAfter"
      @timer-expired="resetTimer"
      @next="goToStepTwo"
      @verification-attempt="increaseVerificationAttempts"
      @skip-verification="setVerified"
    >
      <template #captcha>
        <captcha
          :verification-attempts="verificationAttempts"
          :show-arkose-challenge="requireChallenge"
          @captcha-shown="onCaptchaShown"
          @captcha-solved="onCaptchaSolved"
          @captcha-reset="onCaptchaReset"
        />
      </template>
    </international-phone-input>

    <verify-phone-verification-code
      v-if="stepIndex == 2"
      :latest-phone-number="latestPhoneNumber"
      :disable-submit-button="disableSubmitButton"
      :additional-request-params="captchaData"
      :send-code-allowed="sendCodeAllowed"
      :send-code-allowed-after="sendAllowedAfter"
      @timer-expired="resetTimer"
      @resent="setSendAllowedOn"
      @back="goToStepOne"
      @verified="setVerified"
    />

    <gl-button
      v-if="offerPhoneNumberExemption"
      block
      variant="link"
      class="gl-mt-5 gl-text-sm"
      data-testid="verify-with-card-btn"
      @click="$emit('exemption-requested')"
      >{{ $options.i18n.verifyWithCreditCard }}</gl-button
    >
  </div>
</template>
