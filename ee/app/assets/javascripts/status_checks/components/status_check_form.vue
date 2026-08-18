<script>
import { GlAlert, GlButton, GlFormGroup, GlFormInput, GlTooltipDirective } from '@gitlab/ui';
import { isEqual, isNumber } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ProtectedBranchesSelector from 'ee/vue_shared/components/branches_selector/protected_branches_selector.vue';
import { isValidURL } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import { ALL_BRANCHES } from 'ee/vue_shared/components/branches_selector/constants';
import {
  EMPTY_STATUS_CHECK,
  NAME_TAKEN_SERVER_ERROR,
  URL_TAKEN_SERVER_ERROR,
  SHARED_SECRET_MAX_LENGTH,
} from '../constants';

export default {
  name: 'StatusCheckForm',
  i18n: {
    form: {
      addStatusChecks: s__('StatusCheck|API to check'),
      statusChecks: s__('StatusCheck|Status to check'),
      statusChecksDescription: s__('StatusCheck|Invoke an external API as part of the pipeline.'),
      nameLabel: s__('StatusCheck|Service name'),
      nameDescription: s__('StatusCheck|Examples: QA, Security.'),
      protectedBranchLabel: s__('StatusCheck|Target branch'),
      protectedBranchDescription: s__(
        'StatusCheck|Apply this status check to all branches or a specific protected branch.',
      ),
      sharedSecretLabel: s__('StatusCheck|HMAC Shared Secret'),
      sharedSecretDescription: s__(
        'StatusCheck|Provide a shared secret. This secret is used to authenticate requests for a status check using HMAC.',
      ),
      sharedSecretExistingDescription: s__(
        'StatusCheck|A secret is currently configured for this status check.',
      ),
      overrideWarningMessage: s__(
        'StatusChecks|Enter a new value to overwrite the current secret.',
      ),
      editSecret: s__('StatusChecks|Edit secret'),
    },
    validations: {
      branchesRequired: __('Select a valid target branch.'),
      branchesApiFailure: __('Unable to fetch branches list, please close the form and try again'),
      nameTaken: __('Name is already taken.'),
      nameMissing: __('Please provide a name.'),
      urlTaken: s__(
        'StatusCheck|The specified external API is already in use by another status check.',
      ),
      invalidUrl: __('Please provide a valid URL.'),
      invalidSharedSecret: __('Please provide a shared secret.'),
      sharedSecretInvalidMessage: s__(
        'StatusCheck|Shared secret cannot be longer than 255 characters.',
      ),
    },
  },
  components: {
    ProtectedBranchesSelector,
    GlAlert,
    GlButton,
    GlFormGroup,
    GlFormInput,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    projectId: {
      type: String,
      required: true,
    },
    serverValidationErrors: {
      type: Array,
      required: false,
      default: () => [],
    },
    statusCheck: {
      type: Object,
      required: false,
      default: () => EMPTY_STATUS_CHECK,
    },
  },
  emits: ['submit'],
  data() {
    const {
      protectedBranches: branches,
      name,
      externalUrl: url,
      sharedSecret = '',
    } = this.statusCheck;

    return {
      branches,
      branchesToAdd: [],
      branchesApiFailed: false,
      name,
      sharedSecret,
      showValidation: false,
      url,
      overrideHmac: false,
    };
  },
  computed: {
    hasSharedSecret() {
      return Boolean(this.sharedSecret);
    },
    isValid() {
      return (
        this.isValidName && this.isValidURL && this.isValidBranches && this.isValidSharedSecret
      );
    },
    isValidBranches() {
      return this.branches.every((branch) => isEqual(branch, ALL_BRANCHES) || isNumber(branch?.id));
    },
    isValidName() {
      return Boolean(this.name);
    },
    isValidURL() {
      return Boolean(this.url) && isValidURL(this.url);
    },
    isValidSharedSecret() {
      return (
        (!this.overrideHmac && !this.hasSharedSecret) ||
        (this.hasSharedSecret && this.sharedSecret.length <= SHARED_SECRET_MAX_LENGTH)
      );
    },
    hmacState() {
      return !this.showValidation || this.isValidSharedSecret;
    },
    branchesState() {
      return !this.showValidation || this.isValidBranches;
    },
    nameState() {
      return (
        !this.showValidation ||
        (this.isValidName && !this.serverValidationErrors.includes(NAME_TAKEN_SERVER_ERROR))
      );
    },
    urlState() {
      return (
        !this.showValidation ||
        (this.isValidURL && !this.serverValidationErrors.includes(URL_TAKEN_SERVER_ERROR))
      );
    },
    invalidNameMessage() {
      if (this.serverValidationErrors.includes(NAME_TAKEN_SERVER_ERROR)) {
        return this.$options.i18n.validations.nameTaken;
      }

      return this.$options.i18n.validations.nameMissing;
    },
    invalidUrlMessage() {
      if (this.serverValidationErrors.includes(URL_TAKEN_SERVER_ERROR)) {
        return this.$options.i18n.validations.urlTaken;
      }

      return this.$options.i18n.validations.invalidUrl;
    },
    invalidSharedSecretMessage() {
      if (this.hasSharedSecret && this.sharedSecret.length > SHARED_SECRET_MAX_LENGTH) {
        return this.$options.i18n.validations.sharedSecretInvalidMessage;
      }

      return this.$options.i18n.validations.invalidSharedSecret;
    },
    sharedSecretDescription() {
      if (this.overrideHmac) {
        return this.$options.i18n.form.overrideWarningMessage;
      }

      if (this.hmacEnabled) {
        return this.$options.i18n.form.sharedSecretExistingDescription;
      }

      return this.$options.i18n.form.sharedSecretDescription;
    },
    hmacEnabled() {
      return this.statusCheck.hmac;
    },
    hmacFieldDisabled() {
      return this.hmacEnabled && !this.overrideHmac;
    },
    hmacFieldPlaceholder() {
      return this.hmacFieldDisabled ? '••••••' : '';
    },
    overrideTooltipTitle() {
      return this.overrideHmac ? '' : this.$options.i18n.form.overrideWarningMessage;
    },
  },
  watch: {
    branchesToAdd(value) {
      this.branches = value || [];
    },
  },
  methods: {
    submit() {
      this.showValidation = true;

      if (this.isValid) {
        const { branches, name, url, sharedSecret, overrideHmac } = this;

        this.$emit('submit', { branches, name, url, sharedSecret, overrideHmac });
      }
    },
    setBranchApiError({ hasErrored, error }) {
      if (!this.branchesApiFailed && error) {
        Sentry.captureException(error);
      }

      this.branchesApiFailed = hasErrored;
    },
    enableOverrideHmac() {
      this.overrideHmac = true;
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="branchesApiFailed" class="gl-mb-5" :dismissible="false" variant="danger">
      {{ $options.i18n.validations.branchesApiFailure }}
    </gl-alert>
    <form novalidate @submit.prevent.stop="submit">
      <gl-form-group
        :label="$options.i18n.form.nameLabel"
        :description="$options.i18n.form.nameDescription"
        :state="nameState"
        :invalid-feedback="invalidNameMessage"
        data-testid="name-group"
      >
        <gl-form-input v-model="name" :state="nameState" data-testid="name" />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.form.addStatusChecks"
        :description="$options.i18n.form.statusChecksDescription"
        :state="urlState"
        :invalid-feedback="invalidUrlMessage"
        data-testid="url-group"
      >
        <gl-form-input
          v-model="url"
          :state="urlState"
          type="url"
          :placeholder="`https://api.gitlab.com/`"
          data-testid="url"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.form.protectedBranchLabel"
        :description="$options.i18n.form.protectedBranchDescription"
        :state="branchesState"
        :invalid-feedback="$options.i18n.validations.branchesRequired"
        data-testid="branches-group"
      >
        <protected-branches-selector
          v-model="branchesToAdd"
          :project-id="projectId"
          :is-invalid="!branchesState"
          :selected-branches="branches"
          multiple
          @api-error="setBranchApiError"
        />
      </gl-form-group>
      <div>
        <div class="gl-flex gl-items-center gl-gap-2">
          <label class="gl-mb-0">{{ $options.i18n.form.sharedSecretLabel }}</label>
          <gl-button
            v-if="hmacEnabled"
            v-gl-tooltip.hover.top
            :disabled="overrideHmac"
            :title="overrideTooltipTitle"
            data-testid="override-hmac"
            category="primary"
            variant="link"
            @click="enableOverrideHmac"
          >
            {{ $options.i18n.form.editSecret }}
          </gl-button>
        </div>
        <gl-form-group
          :class="{ 'gl-mb-3': hmacEnabled }"
          :disabled="hmacFieldDisabled"
          :state="hmacState"
          :description="sharedSecretDescription"
          :invalid-feedback="invalidSharedSecretMessage"
          data-testid="shared-secret"
        >
          <gl-form-input
            v-model="sharedSecret"
            :state="hmacState"
            :placeholder="hmacFieldPlaceholder"
            autocomplete="off"
            name="shared-secret"
            type="password"
          />
        </gl-form-group>
      </div>
    </form>
  </div>
</template>
