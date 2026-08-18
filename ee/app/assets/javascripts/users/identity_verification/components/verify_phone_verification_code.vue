<script>
import { GlForm, GlFormGroup, GlFormInput, GlIcon, GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import GlCountdown from '~/vue_shared/components/gl_countdown.vue';
import { s__, sprintf } from '~/locale';

import { createAlert, VARIANT_SUCCESS } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { PASSWORD_MANAGER_IGNORE_ATTRS } from '~/lib/utils/forms';
import { validateVerificationCode } from '../validations';
import { UNKNOWN_TELESIGN_ERROR, CONTACT_SUPPORT_URL } from '../constants';

export default {
  name: 'VerifyPhoneVerificationCode',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlSprintf,
    GlLink,
    GlButton,
    GlCountdown,
  },
  i18n: {
    verificationCode: s__('IdentityVerification|Verification code'),
    description: s__("IdentityVerification|We've sent a verification code to +%{phoneNumber}"),
    noCode: s__(
      'IdentityVerification|Having trouble? %{codeLinkStart}Send a new code%{codeLinkEnd}, %{phoneLinkStart}enter a new phone number%{phoneLinkEnd}, or %{supportLinkStart}contact support%{supportLinkEnd}.',
    ),
    resendCodeIn: s__(
      'IdentityVerification|Having trouble? Send a new code in %{timer}, %{phoneLinkStart}enter a new phone number%{phoneLinkEnd}, or %{supportLinkStart}contact support%{supportLinkEnd}.',
    ),
    resendSuccess: s__('IdentityVerification|We sent a new code to +%{phoneNumber}'),
    verifyButton: s__('IdentityVerification|Verify phone number'),
  },
  links: { contactSupportUrl: CONTACT_SUPPORT_URL },
  passwordManagerIgnoreAttrs: PASSWORD_MANAGER_IGNORE_ATTRS,
  inject: ['phoneSendCodePath', 'phoneVerifyCodePath'],
  props: {
    latestPhoneNumber: {
      type: Object,
      required: false,
      default: () => {},
    },
    disableSubmitButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    additionalRequestParams: {
      type: Object,
      required: false,
      default: () => {},
    },
    sendCodeAllowed: {
      type: Boolean,
      required: true,
    },
    sendCodeAllowedAfter: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['back', 'resent', 'timer-expired', 'verification-attempt', 'verified'],
  data() {
    return {
      form: {
        fields: {
          verificationCode: { value: '', state: null, feedback: '' },
        },
      },
      isLoading: false,
      alert: null,
    };
  },
  computed: {
    labelDescription() {
      return sprintf(this.$options.i18n.description, {
        phoneNumber: this.internationalPhoneNumber,
      });
    },
    internationalPhoneNumber() {
      return `${this.latestPhoneNumber.internationalDialCode}${this.latestPhoneNumber.number}`;
    },
    isSubmitButtonDisabled() {
      return this.disableSubmitButton || !this.form.fields.verificationCode.state;
    },
  },
  methods: {
    checkVerificationCode(value) {
      this.form.fields.verificationCode.value = value;
      const errorMessage = validateVerificationCode(this.form.fields.verificationCode.value);
      this.form.fields.verificationCode.feedback = errorMessage;
      this.form.fields.verificationCode.state = errorMessage.length <= 0;
    },
    verifyCode() {
      this.isLoading = true;
      this.alert?.dismiss();

      axios
        .post(this.phoneVerifyCodePath, {
          verification_code: this.form.fields.verificationCode.value,
          ...this.additionalRequestParams,
        })
        .then(this.handleVerifySuccessResponse)
        .catch(this.handleError)
        .finally(() => {
          this.isLoading = false;
        });
    },
    handleVerifySuccessResponse() {
      this.$emit('verified');
    },
    resendCode() {
      this.isLoading = true;
      this.alert?.dismiss();

      axios
        .post(this.phoneSendCodePath, {
          country: this.latestPhoneNumber.country,
          international_dial_code: this.latestPhoneNumber.internationalDialCode,
          phone_number: this.latestPhoneNumber.number,
          ...this.additionalRequestParams,
        })
        .then(this.handleResendCodeResponse)
        .catch(this.handleError)
        .finally(() => {
          this.isLoading = false;
        });
    },
    handleResendCodeResponse({ data }) {
      this.$emit('verification-attempt');
      this.$emit('resent', data?.send_allowed_after);

      this.alert = createAlert({
        message: sprintf(this.$options.i18n.resendSuccess, {
          phoneNumber: this.internationalPhoneNumber,
        }),
        variant: VARIANT_SUCCESS,
      });
    },
    handleError(error) {
      if (error.response?.data?.reason === UNKNOWN_TELESIGN_ERROR) {
        this.$emit('verified');
        return;
      }

      this.$emit('verification-attempt');

      this.alert = createAlert({
        message: error.response?.data?.message || this.$options.i18n.I18N_GENERIC_ERROR,
        captureError: true,
        error,
      });
    },
    goBack() {
      this.resetForm();
      this.$emit('verification-attempt');
      this.$emit('back');
    },
    resetForm() {
      this.form.fields.verificationCode = { value: '', state: null, feedback: '' };
    },
    onTimerExpired() {
      this.$emit('timer-expired');
    },
  },
};
</script>
<template>
  <gl-form @submit.prevent="verifyCode">
    <p class="gl-mb-6 gl-mt-3" data-testid="label-description">
      {{ labelDescription }}
    </p>
    <gl-form-group
      :label="$options.i18n.verificationCode"
      label-for="verification_code"
      :state="form.fields.verificationCode.state"
      :invalid-feedback="form.fields.verificationCode.feedback"
      data-testid="verification-code-form-group"
      class="gl-mb-2"
    >
      <gl-form-input
        id="verification_code"
        :value="form.fields.verificationCode.value"
        v-bind="$options.passwordManagerIgnoreAttrs"
        type="number"
        name="verification_code"
        :state="form.fields.verificationCode.state"
        trim
        autocomplete="one-time-code"
        data-testid="verification-code-form-input"
        class="gl-no-spin"
        @input="checkVerificationCode"
      />
    </gl-form-group>

    <div v-if="!disableSubmitButton" class="gl-mt-5 gl-text-sm gl-text-subtle">
      <gl-icon name="information-o" :size="16" class="gl-mt-2" variant="info" />
      <gl-sprintf v-if="sendCodeAllowed" :message="$options.i18n.noCode">
        <template #codeLink="{ content }">
          <gl-link data-testid="resend-code-link" @click="resendCode">{{ content }}</gl-link>
        </template>
        <template #phoneLink="{ content }">
          <gl-link data-testid="go-back-btn" @click="goBack">{{ content }}</gl-link>
        </template>
        <template #supportLink="{ content }">
          <gl-link
            :href="$options.links.contactSupportUrl"
            target="_blank"
            data-testid="contact-support-link"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
      <gl-sprintf v-else :message="$options.i18n.resendCodeIn">
        <template #timer>
          <gl-countdown :end-date-string="sendCodeAllowedAfter" @timer-expired="onTimerExpired" />
        </template>
        <template #phoneLink="{ content }">
          <gl-link @click="goBack">{{ content }}</gl-link>
        </template>
        <template #supportLink="{ content }">
          <gl-link
            :href="$options.links.contactSupportUrl"
            target="_blank"
            data-testid="contact-support-link"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
    </div>

    <slot name="captcha"></slot>

    <gl-button
      type="submit"
      variant="confirm"
      class="gl-mt-6 !gl-w-full"
      :disabled="isSubmitButtonDisabled"
      :loading="isLoading"
      data-testid="verify-btn"
    >
      {{ $options.i18n.verifyButton }}
    </gl-button>
  </gl-form>
</template>
