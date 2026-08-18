<script>
import {
  GlButton,
  GlForm,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlModal,
  GlSprintf,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__, sprintf } from '~/locale';
import { isEmptyValue } from '~/lib/utils/forms';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import {
  DETAILS_ROUTE_NAME,
  ENTITY_PROJECT,
  INDEX_ROUTE_NAME,
  SECRET_DESCRIPTION_MAX_LENGTH,
} from 'ee/ci/secrets/constants';
import SecretBranchesField from './secret_branches_field.vue';

export default {
  name: 'SecretForm',
  components: {
    CiEnvironmentsDropdown,
    GlButton,
    GlForm,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlModal,
    GlSprintf,
    SecretBranchesField,
  },
  inject: ['contextConfig', 'fullPath', 'isReadOnly'],
  props: {
    areEnvironmentsLoading: {
      type: Boolean,
      required: true,
    },
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    secretData: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  emits: ['search-environment', 'show-secrets-toast'],
  data() {
    return {
      isSubmitting: false,
      secret: {
        branch: undefined,
        description: undefined,
        environment: undefined,
        name: undefined,
        protected: false,
        rotationIntervalDays: this.secretData?.rotationInfo?.rotationIntervalDays || null,
        secret: undefined, // shown as "value" in the UI
        ...this.secretData,
      },
      showConfirmEditModal: false,
    };
  },
  computed: {
    canSubmit() {
      const baseValid =
        this.isNameValid &&
        this.isValueValid &&
        this.isDescriptionValid &&
        this.isEnvironmentScopeValid &&
        this.isRotationValid;

      if (this.isProjectContext) {
        return baseValid && this.isBranchValid;
      }

      return baseValid;
    },
    isBranchFieldValid() {
      return this.secret.branch === undefined || this.isBranchValid;
    },
    isEnvironmentFieldValid() {
      return this.secret.environment === undefined || this.isEnvironmentScopeValid;
    },
    isProjectContext() {
      return this.contextConfig.type === ENTITY_PROJECT;
    },
    isBranchValid() {
      return this.secret.branch.length > 0;
    },
    isDescriptionValid() {
      return (
        this.secret.description?.length > 0 &&
        this.secret.description?.length <= SECRET_DESCRIPTION_MAX_LENGTH
      );
    },
    isEnvironmentScopeValid() {
      return this.secret.environment.length > 0;
    },
    isNameValid() {
      return this.secret.name?.length > 0;
    },
    isValueValid() {
      if (this.isEditing) {
        return true; // value is optional when editing
      }

      return this.secret.secret?.length > 0;
    },
    isRotationValid() {
      const { rotationIntervalDays } = this.secret;
      return isEmptyValue(rotationIntervalDays) || rotationIntervalDays > 6;
    },
    nameHelpText() {
      if (this.isProjectContext) {
        return s__(
          `SecretsManager|The name should be unique within this project and can contain only letters, digits, and '_'.`,
        );
      }

      return s__(
        `SecretsManager|The name should be unique within this group and can contain only letters, digits, and '_'.`,
      );
    },
    submitButtonText() {
      return this.isEditing ? __('Save changes') : s__('SecretsManager|Add secret');
    },
    valueFieldPlaceholder() {
      if (this.isEditing) {
        return s__('SecretsManager|Enter a new value to update secret');
      }

      return s__('SecretsManager|Enter a value for the secret');
    },
  },
  methods: {
    async createSecret() {
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.contextConfig.createSecret.mutation,
          variables: {
            fullPath: this.fullPath,
            rotationIntervalDays: this.secret.rotationIntervalDays,
            ...this.secret,
          },
        });

        const error = data.secretCreate?.errors[0];
        if (error) {
          createAlert({
            message: error,
            captureError: true,
            error: new Error(error),
          });
          return;
        }

        await this.$router.push({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: this.secret.name },
        });
      } catch (e) {
        createAlert({
          message: formatGraphQLError(e.message),
          captureError: true,
          error: e,
        });
      } finally {
        this.isSubmitting = false;
      }
    },
    async editSecret() {
      this.hideModal();
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.contextConfig.updateSecret.mutation,
          variables: {
            fullPath: this.fullPath,
            rotationIntervalDays: this.secret.rotationIntervalDays,
            ...this.secret,
          },
        });

        const error = data.secretUpdate?.errors[0];
        if (error) {
          createAlert({
            message: error,
            captureError: true,
            error: new Error(error),
          });
          return;
        }

        this.showUpdateToastMessage();
        await this.$router.push({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: this.secret.name },
        });
      } catch (e) {
        createAlert({
          message: formatGraphQLError(e.message),
          captureError: true,
          error: e,
        });
      } finally {
        this.isSubmitting = false;
      }
    },
    hideModal() {
      this.showConfirmEditModal = false;
    },
    setBranch(branch) {
      this.secret.branch = branch;
    },
    setEnvironment(environment) {
      this.secret.environment = environment;
    },
    setRotation(value) {
      this.secret.rotationIntervalDays = value ? parseInt(value, 10) : null;
    },
    showUpdateToastMessage() {
      const toastMessage = sprintf(
        s__('SecretsManager|Secret %{secretName} was successfully updated.'),
        {
          secretName: this.secret.name,
        },
      );

      this.$emit('show-secrets-toast', toastMessage);
    },
    async submitSecret() {
      // these values are initially undefined
      // upon submit, set default values as empty strings to trigger the validation checks
      this.secret.name = this.secret.name || '';
      this.secret.description = this.secret.description || '';
      this.secret.environment = this.secret.environment || '';

      if (this.isProjectContext) {
        this.secret.branch = this.secret.branch || '';
      }

      // secret value is optional when editing
      if (!this.isEditing) {
        this.secret.secret = this.secret.secret || '';
      }

      if (!this.canSubmit) {
        return;
      }

      if (this.isEditing) {
        this.showConfirmEditModal = true;
      } else {
        await this.createSecret();
      }
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
  i18n: {
    fieldRequired: __('This field is required.'),
  },
  modalOptions: {
    actionPrimary: {
      text: __('Save changes'),
    },
    actionSecondary: {
      text: __('Cancel'),
    },
  },
  secretsIndexRoute: INDEX_ROUTE_NAME,
};
</script>
<template>
  <div>
    <gl-form>
      <gl-form-group
        v-if="!isEditing"
        data-testid="secret-name-field-group"
        label-for="secret-name"
        :label="__('Name')"
        :description="nameHelpText"
        :invalid-feedback="$options.i18n.fieldRequired"
      >
        <gl-form-input
          id="secret-name"
          v-model="secret.name"
          required
          :disabled="isReadOnly"
          :placeholder="__('Enter a name')"
          :state="secret.name === undefined || isNameValid"
        />
      </gl-form-group>
      <gl-form-group
        data-testid="secret-value-field-group"
        label-for="secret-value"
        :invalid-feedback="$options.i18n.fieldRequired"
      >
        <template #label>
          {{ __('Value') }}
        </template>
        <gl-form-textarea
          id="secret-value"
          ref="editValueField"
          v-model="secret.secret"
          rows="5"
          max-rows="15"
          no-resize
          :disabled="isReadOnly"
          :placeholder="valueFieldPlaceholder"
          :required="!isEditing"
          :spellcheck="false"
          :state="secret.secret === undefined || isValueValid"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Description')"
        data-testid="secret-description-field-group"
        label-for="secret-description"
        :description="s__('SecretsManager|Maximum 200 characters.')"
        :invalid-feedback="
          s__('SecretsManager|This field is required and must be 200 characters or less.')
        "
      >
        <gl-form-input
          id="secret-description"
          v-model.trim="secret.description"
          data-testid="secret-description"
          required
          :disabled="isReadOnly"
          :placeholder="s__('SecretsManager|Add a description for the secret')"
          :state="secret.description === undefined || isDescriptionValid"
        />
      </gl-form-group>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          :label="__('Environments')"
          label-for="secret-environments"
          data-testid="secret-environments"
          class="gl-w-1/2 gl-pr-2"
          :invalid-feedback="$options.i18n.fieldRequired"
          :state="isEnvironmentFieldValid"
        >
          <ci-environments-dropdown
            id="secret-environments"
            :are-environments-loading="areEnvironmentsLoading"
            :environments="environments"
            :selected-environment-scope="secret.environment"
            :state="isEnvironmentFieldValid"
            :disabled="isReadOnly"
            @select-environment="setEnvironment"
            @search-environment-scope="$emit('search-environment', $event)"
          />
        </gl-form-group>
        <gl-form-group
          v-if="isProjectContext"
          :label="__('Branches')"
          label-for="secret-branches"
          data-testid="secret-branches"
          class="gl-w-1/2 gl-pr-2"
          :invalid-feedback="$options.i18n.fieldRequired"
          :state="isBranchFieldValid"
        >
          <secret-branches-field
            label-for="secret-branches"
            :disabled="isReadOnly"
            :full-path="fullPath"
            :selected-branch="secret.branch"
            :state="isBranchFieldValid"
            @select-branch="setBranch"
          />
        </gl-form-group>
      </div>
      <div v-if="!isProjectContext" class="gl-flex gl-gap-4">
        <gl-form-checkbox v-model="secret.protected" :disabled="isReadOnly">
          {{ s__('SecretsManager|Protected Branches') }}
          <p class="gl-text-subtle">
            {{
              s__('SecretsManager|Export secret to pipelines running on protected branches only.')
            }}
          </p>
        </gl-form-checkbox>
      </div>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          class="gl-w-1/2 gl-pr-2"
          :label="s__('SecretRotation|Rotation reminder period')"
          data-testid="secret-rotation-field-group"
          :description="
            s__(
              'SecretRotation|After a set number of days, send a reminder to rotate the secret. Minimum 7 days.',
            )
          "
          label-for="secret-rotation-period"
          optional
          :invalid-feedback="
            s__('SecretRotation|This field must be a number greater than or equal to 7.')
          "
        >
          <gl-form-input
            :value="secret.rotationIntervalDays"
            :state="isRotationValid"
            :disabled="isReadOnly"
            type="number"
            @input="setRotation"
          />
        </gl-form-group>
      </div>
      <div class="gl-my-3">
        <gl-button
          variant="confirm"
          data-testid="submit-form-button"
          :aria-label="submitButtonText"
          :disabled="isReadOnly || isSubmitting"
          :loading="isSubmitting"
          @click="submitSecret"
        >
          {{ submitButtonText }}
        </gl-button>
        <gl-button
          :to="{ name: $options.secretsIndexRoute }"
          data-testid="cancel-button"
          class="gl-my-4"
          :aria-label="__('Cancel')"
          :disabled="isSubmitting"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
      <gl-modal
        modal-id="secret-confirm-edit"
        :visible="showConfirmEditModal"
        :title="__('Save changes')"
        :action-primary="$options.modalOptions.actionPrimary"
        :action-secondary="$options.modalOptions.actionSecondary"
        @primary.prevent="editSecret"
        @secondary="hideModal"
        @canceled="hideModal"
        @hidden="hideModal"
      >
        <gl-sprintf
          :message="
            s__(
              `SecretsManager|Are you sure you want to update secret %{secretName}? Saving these changes could cause disruptions, such as loss of access to connected services or failed deployments, if the value is rejected by the services.`,
            )
          "
        >
          <template #secretName>
            <b>{{ secret.name }}</b>
          </template>
        </gl-sprintf>
      </gl-modal>
    </gl-form>
  </div>
</template>
