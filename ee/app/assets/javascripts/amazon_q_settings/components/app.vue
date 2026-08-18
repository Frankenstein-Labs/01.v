<script>
import {
  GlButton,
  GlAlert,
  GlFormGroup,
  GlFormInput,
  GlFormInputGroup,
  GlForm,
  GlFormRadioGroup,
  GlFormRadio,
  GlLink,
  GlSprintf,
  GlModalDirective,
  GlFormCheckbox,
} from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { createAndSubmitForm } from '~/lib/utils/create_and_submit_form';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { awsIamRoleArnRegex } from '~/lib/utils/regexp';
import { AVAILABILITY_OPTIONS as AVAILABILITY_OPTIONS_VALUES } from 'ee/ai/settings/constants';
import DisconnectSuccessAlert from './disconnect_success_alert.vue';
import DisconnectWarningModal from './disconnect_warning_modal.vue';

const AVAILABILITY_OPTIONS = [
  {
    value: AVAILABILITY_OPTIONS_VALUES.DEFAULT_ON,
    label: s__('AmazonQ|On by default'),
    helpText: s__(
      'AmazonQ|Features are available. However, any group, subgroup, or project can turn them off.',
    ),
  },
  {
    value: AVAILABILITY_OPTIONS_VALUES.DEFAULT_OFF,
    label: s__('AmazonQ|Off by default'),
    helpText: s__(
      'AmazonQ|Features are not available. However, any group, subgroup, or project can turn them on.',
    ),
  },
  {
    value: AVAILABILITY_OPTIONS_VALUES.NEVER_ON,
    label: s__('AmazonQ|Always off'),
    helpText: s__(
      'AmazonQ|Features are not available and cannot be turned on for any group, subgroup, or project.',
    ),
  },
];

export default {
  name: 'AmazonQSettingsApp',
  components: {
    ClipboardButton,
    DisconnectSuccessAlert,
    DisconnectWarningModal,
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormInputGroup,
    GlFormRadioGroup,
    GlFormRadio,
    GlFormCheckbox,
    GlLink,
    GlSprintf,
    HelpPageLink,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  props: {
    submitUrl: {
      type: String,
      required: true,
    },
    disconnectUrl: {
      type: String,
      required: true,
    },
    identityProviderPayload: {
      type: Object,
      required: false,
      default: null,
    },
    amazonQSettings: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['auto-review-toggled'],
  data() {
    return {
      availability: this.amazonQSettings?.availability || AVAILABILITY_OPTIONS_VALUES.DEFAULT_ON,
      roleArn: this.amazonQSettings?.roleArn || '',
      ready: this.amazonQSettings?.ready || false,
      isSubmitting: false,
      isDisconnecting: false,
      isDisconnectWarningVisible: false,
      isDisconnectSuccessVisible: false,
      isValidated: false,
      amazonQCodeReviewEnabled: this.amazonQSettings?.autoReviewEnabled || false,
    };
  },
  computed: {
    payload() {
      if (this.ready) {
        return {
          availability: this.availability,
          auto_review_enabled: this.amazonQCodeReviewEnabled,
        };
      }

      return {
        availability: this.availability,
        role_arn: this.roleArn,
        auto_review_enabled: this.amazonQCodeReviewEnabled,
      };
    },
    isRoleArnValid() {
      return awsIamRoleArnRegex.test(this.roleArn);
    },
    invalidFeedback() {
      if (!this.roleArn) {
        return this.$options.I18N_IAM_ROLE_ARN_REQUIRED_LABEL;
      }

      if (!this.isRoleArnValid) {
        return this.$options.I18N_IAM_ROLE_ARN_INVALID;
      }

      return '';
    },
    roleArnDisabled() {
      return this.isSubmitting || this.ready;
    },
    availabilityWarning() {
      if (!this.ready || this.availability === this.amazonQSettings?.availability) {
        return '';
      }

      if (this.availability === AVAILABILITY_OPTIONS_VALUES.NEVER_ON) {
        return this.$options.I18N_WARNING_NEVER_ON;
      }
      if (this.availability === AVAILABILITY_OPTIONS_VALUES.DEFAULT_OFF) {
        return this.$options.I18N_WARNING_OFF_BY_DEFAULT;
      }
      return '';
    },
    identityProviderFields() {
      return [
        { label: s__('AmazonQ|Instance ID'), value: this.identityProviderPayload.instance_uid },
        { label: s__('AmazonQ|Provider type'), value: 'OpenID Connect' },
        {
          label: s__('AmazonQ|Provider URL'),
          value: this.identityProviderPayload.aws_provider_url,
        },
        { label: s__('AmazonQ|Audience'), value: this.identityProviderPayload.aws_audience },
      ];
    },
  },
  methods: {
    markValidated() {
      this.isValidated = true;
    },
    submit() {
      this.isValidated = true;

      if (!this.isRoleArnValid) {
        this.isSubmitting = false;
        return;
      }

      try {
        this.isSubmitting = true;

        createAndSubmitForm({
          url: this.submitUrl,
          data: this.payload,
        });
      } catch (e) {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        logError('Unexpected error while submitting the form.', e);

        createAlert({
          message: s__(
            'AmazonQ|An unexpected error occurred while submitting the form. Please see the browser console log for more details.',
          ),
          error: e,
        });
      } finally {
        this.isSubmitting = false;
      }
    },
    showDisconnectWarning() {
      this.isDisconnectWarningVisible = true;
    },
    shouldShowAmazonQCodeReview(value) {
      return value === AVAILABILITY_OPTIONS_VALUES.DEFAULT_ON && this.ready;
    },
    handleCodeReviewToggle() {
      this.$emit('auto-review-toggled', this.amazonQCodeReviewEnabled);
    },
    async disconnect() {
      try {
        this.isDisconnecting = true;

        await axios.post(this.disconnectUrl);

        this.isDisconnectSuccessVisible = true;
        this.roleArn = '';
        this.ready = false;
        this.amazonQCodeReviewEnabled = false;
      } catch (e) {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        logError('Unexpected error while disconnecting Amazon Q.', e);

        const errorType = e.response?.data?.error_type;

        if (errorType === 'uuid_mismatch') {
          createAlert({
            message: s__(
              'AmazonQ|Amazon Q failed to disconnect because of a mismatch with the GitLab instance UUID. This issue typically occurs when the GitLab instance has been restored or migrated. %{linkStart}View troubleshooting information%{linkEnd}.',
            ),
            messageLinks: {
              link: {
                href: helpPagePath('user/duo_amazon_q/setup.md', { anchor: 'troubleshooting' }),
                target: '_blank',
                // eslint-disable-next-line @gitlab/require-i18n-strings
                rel: 'noopener noreferrer',
              },
            },
          });
        } else {
          createAlert({
            // show the normal alert
            message: s__(
              'AmazonQ|An unexpected error occurred while disconnecting Amazon Q. Please see the browser console log for more details.',
            ),
            error: e,
          });
        }
      } finally {
        this.isDisconnecting = false;
      }
    },
  },
  AVAILABILITY_OPTIONS,
  I18N_READY: s__('AmazonQ|GitLab Duo with Amazon Q is ready to go! 🎉'),
  I18N_STEP_IDENTITY_PROVIDER: s__(
    'AmazonQ|Create an identity provider for this GitLab instance within AWS using the following values. %{helpStart}Learn more%{helpEnd}.',
  ),
  I18N_STEP_IAM_ROLE: s__(
    'AmazonQ|Within your AWS account, create an IAM role for Amazon Q and the relevant identity provider. %{helpStart}Learn how to create an IAM role%{helpEnd}.',
  ),
  I18N_IAM_ROLE_ARN_LABEL: s__("AmazonQ|IAM role's ARN"),
  I18N_IAM_ROLE_ARN_REQUIRED_LABEL: s__('AmazonQ|This field is required'),
  I18N_IAM_ROLE_ARN_VALID: s__("AmazonQ|IAM role's ARN is valid"),
  I18N_IAM_ROLE_ARN_INVALID: s__("AmazonQ|IAM role's ARN is not valid"),
  I18N_SAVE_ACKNOWLEDGE: s__(
    'AmazonQ|I understand that by selecting Save changes, GitLab creates a service account for Amazon Q and sends its credentials to AWS. Use of the Amazon Q Developer capabilities as part of GitLab Duo with Amazon Q is governed by the %{helpStart}AWS Customer Agreement%{helpEnd} or other written agreement between you and AWS governing your use of AWS services. Amazon Q Developer processes data across all US Regions and makes cross-region API calls when your requests require it.',
  ),
  I18N_WARNING_OFF_BY_DEFAULT: s__(
    'AmazonQ|Amazon Q will be turned off by default, but still be available to any groups or projects that have previously enabled it.',
  ),
  I18N_WARNING_NEVER_ON: s__(
    'AmazonQ|Amazon Q will be turned off for all groups, subgroups, and projects, even if they have previously enabled it.',
  ),
  I18N_AMAZON_Q_CODE_REVIEW: s__(
    'AmazonQ|Have Amazon Q review code in merge requests automatically',
  ),
  I18N_COPY: s__('AmazonQ|Copy to clipboard'),
  I18N_CREATE_Q_PROFILE: s__(
    'AmazonQ|Create an Amazon Q Developer profile in the %{linkStart}Amazon Q Developer console.%{linkEnd}',
  ),
  INPUT_PLACEHOLDER_ARN: 'arn:aws:iam::account-id:role/role-name',
  HELP_PAGE_IAM_ROLE: helpPagePath('user/duo_amazon_q/setup.md', {
    anchor: 'create-an-iam-role',
  }),
  AMAZON_Q_CONSOLE_HREF:
    'https://us-east-1.console.aws.amazon.com/amazonq/developer/home?region=us-east-1#/gitlab',
};
</script>

<template>
  <gl-form @submit.prevent="submit">
    <gl-form-group v-if="ready" :label="s__('AmazonQ|Status')">
      {{ $options.I18N_READY }}
    </gl-form-group>
    <gl-form-group v-else :label="s__('AmazonQ|Setup')">
      <ol class="gl-mb-0 gl-list-inside gl-pl-0">
        <li>
          <gl-sprintf :message="$options.I18N_CREATE_Q_PROFILE">
            <template #link="{ content }">
              <gl-link
                :show-external-icon="true"
                :href="$options.AMAZON_Q_CONSOLE_HREF"
                target="_blank"
                variant="inline"
              >
                {{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </li>
        <li>
          <gl-sprintf :message="$options.I18N_STEP_IDENTITY_PROVIDER">
            <template #help="{ content }">
              <help-page-link
                href="user/duo_amazon_q/setup.md"
                anchor="create-an-iam-identity-provider"
                target="_blank"
                rel="noopener noreferrer"
                >{{ content }}</help-page-link
              >
            </template>
          </gl-sprintf>
          <div class="gl-mt-3">
            <gl-form-group
              v-for="field in identityProviderFields"
              :key="field.label"
              :label="field.label"
            >
              <gl-form-input-group readonly :value="field.value">
                <template #append>
                  <clipboard-button :text="field.value" :title="$options.I18N_COPY" />
                </template>
              </gl-form-input-group>
            </gl-form-group>
          </div>
        </li>
        <li>
          <gl-sprintf :message="$options.I18N_STEP_IAM_ROLE">
            <template #help="{ content }">
              <help-page-link
                href="user/duo_amazon_q/setup.md"
                anchor="create-an-iam-role"
                target="_blank"
                rel="noopener noreferrer"
                >{{ content }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </li>
        <li>
          {{ s__("AmazonQ|Enter the IAM role's ARN.") }}
        </li>
      </ol>
    </gl-form-group>
    <gl-form-group
      :label="$options.I18N_IAM_ROLE_ARN_LABEL"
      :state="isValidated ? isRoleArnValid : null"
      :invalid-feedback="invalidFeedback"
      :valid-feedback="$options.I18N_IAM_ROLE_ARN_VALID"
    >
      <div class="gl-flex">
        <gl-form-input
          v-model="roleArn"
          :state="!isValidated || isRoleArnValid"
          type="text"
          width="lg"
          name="aws_role"
          :disabled="roleArnDisabled"
          :placeholder="$options.INPUT_PLACEHOLDER_ARN"
          @focus="markValidated"
        />
        <gl-button
          v-if="ready"
          class="gl-ml-3"
          variant="danger"
          category="secondary"
          :loading="isDisconnecting"
          @click="showDisconnectWarning"
        >
          {{ s__('AmazonQ|Disconnect') }}
        </gl-button>
      </div>
    </gl-form-group>
    <gl-form-group class="!gl-mb-3" :label="s__('AmazonQ|Availability')">
      <gl-form-radio-group v-model="availability" name="availability">
        <template v-for="{ value, label, helpText } in $options.AVAILABILITY_OPTIONS">
          <gl-form-radio :key="value" :value="value">
            {{ label }}
            <template #help>{{ helpText }}</template>
          </gl-form-radio>
          <div
            v-if="shouldShowAmazonQCodeReview(value)"
            :key="`${value}-code-review-toggle`"
            class="gl-my-3 gl-ml-6"
            data-testid="amazon-q-code-review-toggle"
          >
            <gl-form-checkbox
              v-model="amazonQCodeReviewEnabled"
              class="gl-pl-6"
              name="auto_review_enabled"
              :disabled="availability !== value"
              @change="handleCodeReviewToggle"
            >
              {{ $options.I18N_AMAZON_Q_CODE_REVIEW }}
            </gl-form-checkbox>
          </div>
        </template>
      </gl-form-radio-group>
    </gl-form-group>
    <gl-alert v-if="availabilityWarning" class="gl-mb-5" :dismissible="false" variant="warning">{{
      availabilityWarning
    }}</gl-alert>
    <div class="gl-flex">
      <gl-button
        type="submit"
        variant="confirm"
        category="primary"
        :loading="isSubmitting"
        class="js-no-auto-disable"
      >
        {{ s__('AmazonQ|Save changes') }}
      </gl-button>
    </div>
    <p v-if="!ready" class="gl-mt-3" data-testid="amazon-q-save-warning">
      <gl-sprintf :message="$options.I18N_SAVE_ACKNOWLEDGE">
        <template #help="{ content }">
          <a href="http://aws.amazon.com/agreement" target="_blank" rel="noopener noreferrer">{{
            content
          }}</a>
        </template>
      </gl-sprintf>
    </p>
    <disconnect-warning-modal v-model="isDisconnectWarningVisible" @submit="disconnect" />
    <disconnect-success-alert
      v-if="isDisconnectSuccessVisible"
      @dismiss="isDisconnectSuccessVisible = false"
    />
  </gl-form>
</template>
