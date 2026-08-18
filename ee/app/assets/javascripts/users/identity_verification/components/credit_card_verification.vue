<script>
import { GlButton, GlIcon, GlSprintf, GlLink } from '@gitlab/ui';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import Zuora from 'ee/billings/components/zuora_simple.vue';
import { I18N_GENERIC_ERROR, RELATED_TO_BANNED_USER, CONTACT_SUPPORT_URL } from '../constants';
import Captcha from './identity_verification_captcha.vue';

export const EVENT_CATEGORY = 'IdentityVerification::CreditCard';
export const EVENT_FAILED = 'failed_attempt';
export const EVENT_SUCCESS = 'success';

export default {
  name: 'CreditCardVerification',
  components: {
    GlButton,
    GlIcon,
    GlLink,
    GlSprintf,
    Zuora,
    Captcha,
  },
  mixins: [Tracking.mixin({ category: EVENT_CATEGORY })],
  inject: [
    'creditCardVerifyPath',
    'creditCardVerifyCaptchaPath',
    'creditCard',
    'offerPhoneNumberExemption',
  ],
  props: {
    requireChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['completed', 'exemption-requested'],
  data() {
    return {
      currentUserId: this.creditCard.userId,
      formId: this.creditCard.formId,
      hasLoadError: false,
      isFormLoading: true,
      errorMessage: undefined,
      isRelatedToBannedUser: false,
      disableSubmitButton: false,
      isLoading: false,
      verificationAttempts: 0,
      captchaData: {},
    };
  },
  computed: {
    isSubmitButtonDisabled() {
      return (
        this.disableSubmitButton ||
        this.isFormLoading ||
        this.hasLoadError ||
        this.isRelatedToBannedUser
      );
    },
  },
  methods: {
    handleCheckForReuseResponse() {
      this.$emit('completed');
      this.track(EVENT_SUCCESS);
    },
    handleCheckForReuseError(error) {
      if (error.response.data?.message) {
        this.errorMessage = error.response.data.message;
        this.isRelatedToBannedUser = error.response.data?.reason === RELATED_TO_BANNED_USER;
      } else {
        createAlert({
          message: I18N_GENERIC_ERROR,
          captureError: true,
          error,
        });
      }
    },
    handleFormLoading(isFormLoading) {
      this.isFormLoading = isFormLoading;

      if (!isFormLoading && this.errorMessage) {
        this.alert = createAlert({ message: this.errorMessage });
        this.errorMessage = undefined;
      }
    },
    handleFormLoadError() {
      this.hasLoadError = true;
    },
    handleValidationError({ message }) {
      this.track(EVENT_FAILED, { property: message });
    },
    handleValidationSuccess() {
      this.isLoading = true;

      axios
        .get(this.creditCardVerifyPath)
        .then(this.handleCheckForReuseResponse)
        .catch(this.handleCheckForReuseError)
        .finally(() => {
          this.isLoading = false;
        });
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
    submit() {
      this.isLoading = true;

      axios
        .post(this.creditCardVerifyCaptchaPath, this.captchaData)
        .then(() => {
          this.alert?.dismiss();
          this.$refs.zuora.submit();
        })
        .catch((error) => {
          createAlert({ message: error.response?.data?.message || I18N_GENERIC_ERROR });
        })
        .finally(() => {
          this.increaseVerificationAttempts();
          this.isLoading = false;
        });
    },
  },
  i18n: {
    formInfo: s__(
      'IdentityVerification|GitLab does not make any charges or store the details of your credit or debit card. Verification is not connected to any billing information for your groups.',
    ),
    contactSupport: s__(
      'IdentityVerification|Having trouble? %{supportLinkStart}Contact support%{supportLinkEnd}.',
    ),
    formSubmit: s__('IdentityVerification|Verify credit card'),
    verifyWithPhone: s__('IdentityVerification|Verify with a phone number instead?'),
  },
  links: { contactSupportUrl: CONTACT_SUPPORT_URL },
  zuoraFormHeight: 328,
};
</script>
<template>
  <div class="gl-mt-6 gl-flex gl-flex-col">
    <zuora
      ref="zuora"
      :current-user-id="currentUserId"
      :initial-height="$options.zuoraFormHeight"
      :payment-form-id="formId"
      @loading="handleFormLoading"
      @load-error="handleFormLoadError"
      @client-validation-error="handleValidationError"
      @server-validation-error="handleValidationError"
      @success="handleValidationSuccess"
    />

    <div class="gl-mx-4 gl-mt-4 gl-flex gl-text-sm gl-text-subtle">
      <gl-icon class="gl-mr-2 gl-mt-2 gl-shrink-0" name="information-o" :size="16" variant="info" />

      <div>
        <p class="gl-mb-2">{{ $options.i18n.formInfo }}</p>

        <p class="gl-mb-2">
          <gl-sprintf :message="$options.i18n.contactSupport">
            <template #supportLink="{ content }">
              <gl-link :href="$options.links.contactSupportUrl" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
      </div>
    </div>

    <captcha
      :show-arkose-challenge="requireChallenge"
      :verification-attempts="verificationAttempts"
      @captcha-shown="onCaptchaShown"
      @captcha-solved="onCaptchaSolved"
      @captcha-reset="onCaptchaReset"
    />

    <gl-button
      class="gl-mt-6"
      variant="confirm"
      type="submit"
      :disabled="isSubmitButtonDisabled"
      :loading="isLoading"
      @click="submit"
    >
      {{ $options.i18n.formSubmit }}
    </gl-button>
    <gl-button
      v-if="offerPhoneNumberExemption"
      block
      variant="link"
      class="gl-mt-5 gl-text-sm"
      data-testid="verify-with-phone-btn"
      @click="$emit('exemption-requested')"
      >{{ $options.i18n.verifyWithPhone }}</gl-button
    >
  </div>
</template>
