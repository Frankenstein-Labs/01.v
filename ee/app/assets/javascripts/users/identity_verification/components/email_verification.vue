<script>
import { GlForm, GlFormGroup, GlFormInput, GlIcon, GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { PASSWORD_MANAGER_IGNORE_ATTRS } from '~/lib/utils/forms';
import {
  I18N_EMAIL_EMPTY_CODE,
  I18N_EMAIL_INVALID_CODE,
  I18N_GENERIC_ERROR,
  I18N_EMAIL_RESEND_SUCCESS,
  CONTACT_SUPPORT_URL,
} from '../constants';

const SUCCESS_RESPONSE = 'success';
const FAILURE_RESPONSE = 'failure';

export default {
  name: 'EmailVerification',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlLink,
    GlSprintf,
    GlButton,
  },
  inject: ['email'],
  emits: ['completed'],
  data() {
    return {
      verificationCode: '',
      submitted: false,
      verifyError: '',
    };
  },
  computed: {
    isValidInput() {
      return this.submitted ? !this.invalidFeedback : true;
    },
    invalidFeedback() {
      if (!this.submitted) {
        return '';
      }

      if (!this.verificationCode) {
        return I18N_EMAIL_EMPTY_CODE;
      }

      if (!this.verificationCode.match(/\d{6}/)) {
        return I18N_EMAIL_INVALID_CODE;
      }

      return this.verifyError;
    },
  },
  watch: {
    verificationCode() {
      this.verifyError = '';
    },
  },
  methods: {
    verify() {
      this.submitted = true;

      if (!this.isValidInput) return;

      axios
        .post(this.email.verifyPath, { code: this.verificationCode })
        .then(this.handleVerificationResponse)
        .catch(this.handleError);
    },
    resend() {
      axios
        .post(this.email.resendPath)
        .then(this.handleResendResponse)
        .catch(this.handleError)
        .finally(this.resetForm);
    },
    handleVerificationResponse(response) {
      if (response.data.status === undefined) {
        this.handleError();
      } else if (response.data.status === SUCCESS_RESPONSE) {
        this.$emit('completed');
      } else if (response.data.status === FAILURE_RESPONSE) {
        this.verifyError = response.data.message;
      }
    },
    handleResendResponse(response) {
      if (response.data.status === undefined) {
        this.handleError();
      } else if (response.data.status === SUCCESS_RESPONSE) {
        createAlert({
          message: I18N_EMAIL_RESEND_SUCCESS,
          variant: VARIANT_SUCCESS,
        });
      } else if (response.data.status === FAILURE_RESPONSE) {
        createAlert({ message: response.data.message });
      }
    },
    handleError(error) {
      createAlert({
        message: I18N_GENERIC_ERROR,
        captureError: true,
        error,
      });
    },
    resetForm() {
      this.verificationCode = '';
      this.submitted = false;
    },
  },
  i18n: {
    headerStandalone: s__(
      "IdentityVerification|For added security, you'll need to verify your identity.",
    ),
    header: s__("IdentityVerification|We've sent a verification code to %{email}"),
    code: s__('IdentityVerification|Verification code'),
    noCode: s__(
      'IdentityVerification|Having trouble? %{resendLinkStart}Send a new code%{resendLinkEnd} or %{supportLinkStart}contact support%{supportLinkEnd}.',
    ),
    verify: s__('IdentityVerification|Verify email address'),
  },
  links: {
    contactSupportUrl: CONTACT_SUPPORT_URL,
  },
  passwordManagerIgnoreAttrs: PASSWORD_MANAGER_IGNORE_ATTRS,
};
</script>
<template>
  <div>
    <p class="gl-mt-3">
      <gl-sprintf :message="$options.i18n.header">
        <template #email>
          <b>{{ email.obfuscated }}</b>
        </template>
      </gl-sprintf>
    </p>
    <gl-form class="gl-mt-6" @submit.prevent="verify">
      <gl-form-group
        :label="$options.i18n.code"
        label-for="verification_code"
        :state="isValidInput"
        :invalid-feedback="invalidFeedback"
      >
        <gl-form-input
          id="verification_code"
          v-model="verificationCode"
          v-bind="$options.passwordManagerIgnoreAttrs"
          name="verification_code"
          :autofocus="true"
          autocomplete="one-time-code"
          data-testid="verification-code-field"
          inputmode="numeric"
          maxlength="6"
          :state="isValidInput"
          trim
        />
      </gl-form-group>
      <div class="gl-text-sm gl-text-subtle">
        <gl-icon name="information-o" :size="16" variant="info" />
        <gl-sprintf :message="$options.i18n.noCode">
          <template #resendLink="{ content }">
            <gl-link class="gl-text-sm" @click="resend">{{ content }}</gl-link>
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
      <gl-button class="js-no-auto-disable gl-mb-0 gl-mt-6" block variant="confirm" type="submit">
        {{ $options.i18n.verify }}
      </gl-button>
    </gl-form>
  </div>
</template>
