<script>
import { VERIFICATION_TOKEN_INPUT_NAME } from 'ee/arkose_labs/constants';
import PhoneVerificationArkoseApp from 'ee/arkose_labs/components/phone_verification_arkose_app.vue';
import ReCaptcha from '~/captcha/captcha_modal.vue';

export default {
  name: 'IdentityVerificationCaptcha',
  components: {
    PhoneVerificationArkoseApp,
    ReCaptcha,
  },
  props: {
    showArkoseChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRecaptchaChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
    verificationAttempts: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: ['captcha-reset', 'captcha-shown', 'captcha-solved'],
  data() {
    return {
      arkose: { challengeSolved: false, token: '', reset: false },
      recaptcha: { challengeSolved: false, token: '', reset: false },
    };
  },
  computed: {
    renderCaptcha() {
      return this.showArkoseChallenge || this.showRecaptchaChallenge;
    },
    recaptchaSiteKey() {
      return gon.recaptcha_sitekey;
    },
  },
  watch: {
    verificationAttempts() {
      this.resetCaptcha();
    },
  },
  mounted() {
    if (this.renderCaptcha) {
      this.$emit('captcha-shown');
    }
  },
  methods: {
    onArkoseChallengeSolved(arkoseToken) {
      this.arkose = { challengeSolved: true, token: arkoseToken, reset: false };

      this.$emit('captcha-solved', { [VERIFICATION_TOKEN_INPUT_NAME]: arkoseToken });
    },
    onReCaptchaSolved(response) {
      this.recaptcha = { challengeSolved: true, token: response, reset: false };

      this.$emit('captcha-solved', { 'g-recaptcha-response': response });
    },
    resetCaptcha() {
      if (this.renderCaptcha) {
        this.arkose = { challengeSolved: false, token: '', reset: true };
        this.recaptcha = { challengeSolved: false, token: '', reset: true };

        this.$emit('captcha-reset');
      }
    },
  },
};
</script>
<template>
  <div>
    <div v-if="showRecaptchaChallenge" class="gl-mt-3 gl-text-center">
      <re-captcha
        :captcha-site-key="recaptchaSiteKey"
        :show-modal="false"
        :reset-session="recaptcha.reset"
        needs-captcha-response
        @received-captcha-response="onReCaptchaSolved"
      />
    </div>

    <phone-verification-arkose-app
      v-if="showArkoseChallenge"
      :reset-session="arkose.reset"
      class="gl-mt-5"
      @challenge-solved="onArkoseChallengeSolved"
    />
  </div>
</template>
