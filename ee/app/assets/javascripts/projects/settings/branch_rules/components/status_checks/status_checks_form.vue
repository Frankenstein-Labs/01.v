<script>
import { GlButton, GlForm, GlFormGroup, GlFormInput, GlTooltipDirective } from '@gitlab/ui';
import { isValidURL } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import { SHARED_SECRET_MAX_LENGTH } from 'ee/status_checks/constants';

/* eslint-disable @gitlab/require-i18n-strings */
const SERVER_VALIDATION_ERRORS = {
  urlTaken: 'External url has already been taken',
  nameTaken: 'Name has already been taken',
};
/* eslint-enable @gitlab/require-i18n-strings */

export default {
  name: 'StatusCheckForm',
  i18n: {
    serviceNameLabel: s__('StatusChecks|Service name'),
    serviceNameDescription: s__('StatusChecks|Examples: QA, Security, Performance.'),
    apiLabel: s__('StatusChecks|API to check'),
    apiDescription: s__('StatusChecks|Invoke an external API as part of the pipeline process.'),
    nameTaken: s__('StatusCheck|Name already exists.'),
    nameMissing: s__('StatusCheck|Please provide a name.'),
    urlTaken: s__('StatusCheck|External API is already in use.'),
    invalidUrl: s__('StatusCheck|Please provide a valid URL.'),
    saveChanges: __('Save changes'),
    cancel: __('Cancel'),
    sharedSecretLabel: s__('StatusCheck|HMAC Shared Secret'),
    sharedSecretDescription: s__(
      'StatusCheck|Provide a shared secret. This secret is used to authenticate requests for a status check using HMAC.',
    ),
    sharedSecretExistingDescription: s__(
      'StatusCheck|A secret is currently configured for this status check.',
    ),
    overrideWarningMessage: s__('StatusChecks|Enter a new value to overwrite the current secret.'),
    editSecret: s__('StatusChecks|Edit secret'),
    sharedSecretInvalidMessage: s__(
      'StatusCheck|Shared secret cannot be longer than 255 characters.',
    ),
  },
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedStatusCheck: {
      type: Object,
      required: false,
      default: () => null,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    serverValidationErrors: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['close-status-check-drawer', 'save-status-check-change'],
  data() {
    const { name = '', externalUrl = '', id = null } = this.selectedStatusCheck || {};
    return {
      id,
      name,
      externalUrl,
      sharedSecret: '',
      showValidation: false,
      overrideHmac: false,
    };
  },
  computed: {
    isValid() {
      return this.isValidName && this.isValidURL && this.isValidSharedSecret;
    },
    isValidName() {
      return Boolean(this.name.trim());
    },
    isValidURL() {
      return isValidURL(this.externalUrl);
    },
    hasSharedSecret() {
      return Boolean(this.sharedSecret);
    },
    isValidSharedSecret() {
      return !this.hasSharedSecret || this.sharedSecret.length <= SHARED_SECRET_MAX_LENGTH;
    },
    hmacState() {
      return !this.showValidation || this.isValidSharedSecret;
    },
    hmacEnabled() {
      return this.selectedStatusCheck?.hmac;
    },
    hmacFieldDisabled() {
      return this.hmacEnabled && !this.overrideHmac;
    },
    hmacFieldPlaceholder() {
      return this.hmacFieldDisabled ? '••••••' : '';
    },
    overrideTooltipTitle() {
      return this.overrideHmac ? '' : this.$options.i18n.overrideWarningMessage;
    },
    sharedSecretDescription() {
      if (this.overrideHmac) {
        return this.$options.i18n.overrideWarningMessage;
      }

      if (this.hmacEnabled) {
        return this.$options.i18n.sharedSecretExistingDescription;
      }

      return this.$options.i18n.sharedSecretDescription;
    },
    isValidNameState() {
      return this.showValidation
        ? this.isValidName &&
            !this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.nameTaken)
        : true;
    },
    isValidUrlState() {
      return this.showValidation
        ? this.isValidURL &&
            !this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.urlTaken)
        : true;
    },
    invalidNameMessage() {
      if (this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.nameTaken)) {
        return this.$options.i18n.nameTaken;
      }

      return this.$options.i18n.nameMissing;
    },
    invalidUrlMessage() {
      if (this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.urlTaken)) {
        return this.$options.i18n.urlTaken;
      }

      return this.$options.i18n.invalidUrl;
    },
  },
  methods: {
    emitSaveEvent() {
      this.showValidation = true;

      if (this.isValid) {
        const { name, externalUrl, id, sharedSecret } = this;
        this.$emit('save-status-check-change', { name, externalUrl, id, sharedSecret });
      }
    },
    enableOverrideHmac() {
      this.overrideHmac = true;
    },
  },
  serviceNameInput: 'service-name-input',
  apiUrlInput: 'api-url-input',
  sharedSecretInput: 'shared-secret-input',
  apiPlaceholderText: 'https://api.gitlab.com',
};
</script>

<template>
  <gl-form novalidate @submit.prevent="emitSaveEvent">
    <gl-form-group
      data-testid="service-name-group"
      :label="$options.i18n.serviceNameLabel"
      :label-for="$options.serviceNameInput"
      :description="$options.i18n.serviceNameDescription"
      :state="isValidNameState"
      :invalid-feedback="invalidNameMessage"
      class="gl-border-none"
    >
      <gl-form-input
        :id="$options.serviceNameInput"
        v-model="name"
        data-testid="service-name-input"
      />
    </gl-form-group>

    <gl-form-group
      data-testid="api-url-group"
      :label="$options.i18n.apiLabel"
      :label-for="$options.apiUrlInput"
      :description="$options.i18n.apiDescription"
      :state="isValidUrlState"
      :invalid-feedback="invalidUrlMessage"
      class="gl-border-none"
    >
      <gl-form-input
        :id="$options.apiUrlInput"
        v-model="externalUrl"
        type="url"
        data-testid="api-url-input"
        :placeholder="$options.apiPlaceholderText"
      />
    </gl-form-group>

    <div>
      <div class="gl-mb-3 gl-flex gl-items-center gl-gap-2">
        <label :for="$options.sharedSecretInput" class="gl-mb-0">{{
          $options.i18n.sharedSecretLabel
        }}</label>
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
          {{ $options.i18n.editSecret }}
        </gl-button>
      </div>
      <gl-form-group
        :disabled="hmacFieldDisabled"
        :state="hmacState"
        :description="sharedSecretDescription"
        :invalid-feedback="$options.i18n.sharedSecretInvalidMessage"
        data-testid="shared-secret-group"
      >
        <gl-form-input
          :id="$options.sharedSecretInput"
          v-model="sharedSecret"
          :state="hmacState"
          :placeholder="hmacFieldPlaceholder"
          :disabled="hmacFieldDisabled"
          autocomplete="off"
          name="shared-secret"
          type="password"
          data-testid="shared-secret-input"
        />
      </gl-form-group>
    </div>

    <div class="gl-flex gl-gap-3">
      <gl-button
        variant="confirm"
        data-testid="save-btn"
        :loading="isLoading"
        type="submit"
        @click.prevent="emitSaveEvent"
      >
        {{ $options.i18n.saveChanges }}
      </gl-button>
      <gl-button data-testid="cancel-btn" @click="$emit('close-status-check-drawer')">
        {{ $options.i18n.cancel }}
      </gl-button>
    </div>
  </gl-form>
</template>
