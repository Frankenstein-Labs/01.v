<script>
import { GlButton, GlForm, GlFormFields, GlLink, GlSprintf } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';

import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';
import {
  SELF_HOSTED_MODEL_PLATFORMS,
  BEDROCK_DUMMY_ENDPOINT,
  VERTEX_DUMMY_ENDPOINT,
  CLOUD_PROVIDER_MODELS,
} from '../constants';
import BetaFeaturesAlert from '../../shared/components/beta_features_alert.vue';
import TestConnectionButton from './test_connection_button.vue';
import ModelSelector from './model_selector.vue';
import PlatformSelector from './platform_selector.vue';

const identifierPrefixByPlatform = {
  [SELF_HOSTED_MODEL_PLATFORMS.BEDROCK]: 'bedrock/',
  [SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI]: 'vertex_ai/',
};

const identifierPrefixForPlatform = (platform) => identifierPrefixByPlatform[platform] || '';
const baseFormFieldClasses = ['gl-bg-subtle', 'gl-w-full', 'gl-p-6', 'gl-pb-2', 'gl-m-0'];
const baseFormFields = {
  name: {
    label: s__('AdminSelfHostedModels|Deployment name'),
    validators: [
      formValidators.required(s__('AdminSelfHostedModels|Please enter a deployment name.')),
    ],
  },
  platform: {
    label: s__('AdminSelfHostedModels|Platform'),
  },
  model: {
    label: s__('AdminSelfHostedModels|Model family'),
    validators: [formValidators.required(s__('AdminSelfHostedModels|Please select a model.'))],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
};
const apiFormFields = {
  endpoint: {
    label: s__('AdminSelfHostedModels|Endpoint'),
    validators: [formValidators.required(s__('AdminSelfHostedModels|Please enter an endpoint.'))],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
  identifier: {
    label: s__('AdminSelfHostedModels|Model identifier'),
    validators: [
      formValidators.required(s__('AdminSelfHostedModels|Please enter a model identifier.')),
      formValidators.factory(
        s__('AdminSelfHostedModels|Model identifier must be less than 255 characters.'),
        (val) => val.length <= 255,
      ),
    ],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
};
const cloudPlatformFormFields = (identifierPrefix) => ({
  identifier: {
    label: s__('AdminSelfHostedModels|Model identifier'),
    validators: [
      formValidators.required(s__('AdminSelfHostedModels|Please enter a model identifier.')),
      formValidators.factory(
        sprintf(
          s__('AdminSelfHostedModels|Model identifier must start with "%{identifierPrefix}"'),
          { identifierPrefix },
        ),
        (val) => val.startsWith(identifierPrefix),
      ),
      formValidators.factory(
        s__('AdminSelfHostedModels|Model identifier must be less than 255 characters.'),
        (val) => val.length <= 255,
      ),
    ],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
});

export default {
  name: 'SelfHostedModelForm',
  components: {
    GlButton,
    GlForm,
    GlFormFields,
    GlLink,
    GlSprintf,
    BetaFeaturesAlert,
    InputCopyToggleVisibility,
    ModelSelector,
    PlatformSelector,
    TestConnectionButton,
  },
  inject: ['basePath', 'betaModelsEnabled'],
  props: {
    submitButtonText: {
      type: String,
      required: false,
      default: s__('AdminSelfHostedModels|Add self-hosted model'),
    },
    mutationData: {
      type: Object,
      required: true,
    },
    initialFormValues: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['submit'],
  i18n: {
    defaultError: s__(
      'AdminSelfHostedModels|There was an error saving the self-hosted model. Please try again.',
    ),
    nonUniqueDeploymentNameError: s__(
      'AdminSelfHostedModels|Please enter a unique deployment name.',
    ),
    invalidEndpointError: s__('AdminSelfHostedModels|Please add a valid endpoint.'),
    awsSetupMessage: s__(
      'AdminSelfHostedModels|To fully set up AWS credentials for this model please refer to the %{linkStart}AWS Bedrock Configuration Guide%{linkEnd}',
    ),
    vertexAiSetupMessage: s__(
      'AdminSelfHostedModels|To fully set up Google Cloud credentials for this model please refer to the %{linkStart}Google Vertex AI Configuration Guide%{linkEnd}',
    ),
  },
  formId: 'self-hosted-model-form',
  cloudPlatformSetupUrl: helpPagePath(
    'administration/gitlab_duo_self_hosted/supported_llm_serving_platforms',
    {
      anchor: 'cloud-hosted-model-deployments',
    },
  ),
  baseFormFieldClasses,
  data() {
    const {
      name = '',
      model = '',
      endpoint = '',
      identifier = '',
      apiToken = '',
      provider = SELF_HOSTED_MODEL_PLATFORMS.API,
    } = this.initialFormValues;

    return {
      baseFormValues: {
        name,
        endpoint,
        identifier,
        model: model.toUpperCase(),
      },
      platform: provider,
      apiToken,
      serverValidations: {},
      isSaving: false,
    };
  },
  computed: {
    cloudPlatformIdentifierPrefix() {
      return identifierPrefixForPlatform(this.platform);
    },
    cloudPlatformFields() {
      return cloudPlatformFormFields(this.cloudPlatformIdentifierPrefix);
    },
    formFields() {
      const platformFields = this.isApiPlatform ? apiFormFields : this.cloudPlatformFields;
      const fields = {
        ...baseFormFields,
        ...platformFields,
      };

      fields.identifier.inputAttrs = {
        placeholder: this.identifierPlaceholder,
      };

      return fields;
    },
    hasValidInput() {
      const { name, model, endpoint, identifier } = this.baseFormValues;

      if (name === '' || model === '' || identifier === '') {
        return false;
      }

      if (this.isApiPlatform) {
        return endpoint !== '' && identifier.length <= 255;
      }

      return identifier.startsWith(this.cloudPlatformIdentifierPrefix) && identifier.length <= 255;
    },
    isEditing() {
      return Boolean(this.initialFormValues.id);
    },
    isApiPlatform() {
      return this.platform === SELF_HOSTED_MODEL_PLATFORMS.API;
    },
    successMessage() {
      if (this.isEditing) {
        return s__('AdminSelfHostedModels|The self-hosted model was successfully saved.');
      }

      return s__('AdminSelfHostedModels|Model added. Select it for a feature to start using it.');
    },
    platformSetupMessage() {
      return this.platform === SELF_HOSTED_MODEL_PLATFORMS.BEDROCK
        ? this.$options.i18n.awsSetupMessage
        : this.$options.i18n.vertexAiSetupMessage;
    },
    formValues() {
      /*
        Endpoint and api tokens aren't used for Bedrock models. There is currently a non-null constraint
        on the endpoint column so so we still need to send a placeholder. This is a workaround for
        going GA in 17.9 - the columns should be made nullable as a more permanent solution.
        https://gitlab.com/gitlab-org/gitlab/-/issues/507966
      */
      if (!this.isApiPlatform) {
        const endpoint =
          this.platform === SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI
            ? VERTEX_DUMMY_ENDPOINT
            : BEDROCK_DUMMY_ENDPOINT;

        return {
          ...this.baseFormValues,
          endpoint,
          apiToken: '',
          provider: this.platform,
        };
      }

      return {
        apiToken: this.apiToken,
        provider: this.platform,
        ...this.baseFormValues,
      };
    },
    identifierPlaceholder() {
      if (!this.isApiPlatform) {
        return this.cloudPlatformIdentifierPrefix;
      }

      const { model } = this.baseFormValues;
      if (model && !Object.values(CLOUD_PROVIDER_MODELS).includes(model)) {
        return 'custom_openai/';
      }

      return '';
    },
    identifierLabelDescription() {
      let identifierLabel = 'provider/model-name';
      if (this.identifierPlaceholder.length > 0) {
        identifierLabel = `${this.identifierPlaceholder}model-name`;
      }

      return sprintf(
        s__('AdminSelfHostedModels|Provide the model identifier in the form of %{identifierLabel}'),
        { identifierLabel },
      );
    },
  },
  methods: {
    async onSubmit() {
      if (!this.hasValidInput) return;

      const { mutation } = this.mutationData;

      const mutationInput = {
        ...this.formValues,
        ...(this.isEditing
          ? {
              id: convertToGraphQLId('Ai::SelfHostedModel', this.initialFormValues.id),
            }
          : {}),
      };

      this.isSaving = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              ...mutationInput,
            },
          },
        });
        if (data) {
          const { errors } = data[this.mutationData.name];
          if (errors.length > 0) {
            this.onError(errors);
            this.isSaving = false;
            return;
          }

          this.isSaving = false;
          visitUrlWithAlerts(this.basePath, [
            {
              message: this.successMessage,
              variant: 'success',
            },
          ]);
        }
      } catch (error) {
        createAlert({
          message: this.$options.i18n.defaultError,
          error,
          captureError: true,
        });
        this.isSaving = false;
      }
    },
    onModelUpdate(selectedModel) {
      this.onInputField({ name: 'model' });
      this.baseFormValues.model = selectedModel;
    },
    // clears the validation error
    onInputField({ name }) {
      delete this.serverValidations[name];
    },
    onClick(event) {
      event.currentTarget.blur();
    },
    onPlatformUpdate(value) {
      this.platform = value;
    },
    onError(errors) {
      // TODO: Delegate sorting of errors to the back-end - the client should only need to consume these
      const error = errors[0];
      const SERVER_VALIDATION_ERRORS = {
        /* eslint-disable @gitlab/require-i18n-strings */
        name: 'Name has already been taken',
        endpoint: 'Endpoint is blocked',
        /* eslint-enable @gitlab/require-i18n-strings */
      };

      if (error.includes(SERVER_VALIDATION_ERRORS.endpoint)) {
        this.serverValidations = {
          ...this.serverValidations,
          endpoint: this.$options.i18n.invalidEndpointError,
        };
      }
      if (error.includes(SERVER_VALIDATION_ERRORS.name)) {
        this.serverValidations = {
          ...this.serverValidations,
          name: this.$options.i18n.nonUniqueDeploymentNameError,
        };
      }

      // Unrecognised error, display generic error message
      if (
        !error.includes(SERVER_VALIDATION_ERRORS.name) &&
        !error.includes(SERVER_VALIDATION_ERRORS.endpoint)
      ) {
        throw new Error(error);
      }
    },
  },
};
</script>
<template>
  <gl-form :id="$options.formId" class="gl-max-w-62" @submit.prevent="onSubmit">
    <gl-form-fields
      :key="`${platform}-form-fields`"
      v-model="baseFormValues"
      :fields="formFields"
      :form-id="$options.formId"
      :server-validations="serverValidations"
      @input-field="onInputField"
      @submit="$emit('submit', baseFormValues)"
    >
      <template #group(name)-label-description>
        {{ s__('AdminSelfHostedModels|A unique and descriptive name for your deployment.') }}
      </template>

      <template #input(platform)>
        <platform-selector :platform="platform" @update:platform="onPlatformUpdate" />
      </template>

      <template #after(platform)>
        <beta-features-alert
          v-if="!betaModelsEnabled"
          :message="
            s__(
              'AdminSelfHostedModels|More models are available in beta. You can %{linkStart}turn on self-hosted model beta features%{linkEnd}.',
            )
          "
        />
      </template>

      <template #group(model)-label-description>
        {{
          s__(
            'AdminSelfHostedModels|Select an appropriate model family from the list of approved GitLab models.',
          )
        }}
      </template>

      <template #input(model)>
        <model-selector
          :selected-model="baseFormValues.model"
          :is-loading="isSaving"
          @update:model="onModelUpdate"
        />
      </template>

      <template #group(endpoint)-label-description>
        {{
          s__(
            'AdminSelfHostedModels|Specify the URL endpoint where your self-hosted model is accessible',
          )
        }}
      </template>

      <template #group(identifier)-label-description>
        {{ identifierLabelDescription }}
      </template>
    </gl-form-fields>
    <div :class="[...$options.baseFormFieldClasses, 'gl-pb-6']">
      <input-copy-toggle-visibility
        v-if="isApiPlatform"
        v-model="apiToken"
        :value="apiToken"
        :label="s__('AdminSelfHostedModels|API Key (optional)')"
        :initial-visibility="false"
        :disabled="isSaving"
        :show-copy-button="false"
        :label-description="
          s__(
            'AdminSelfHostedModels|If required, provide the API token that grants access to your self-hosted model deployment.',
          )
        "
      />
      <gl-sprintf v-else :message="platformSetupMessage">
        <template #link="{ content }">
          <gl-link :href="$options.cloudPlatformSetupUrl" target="_blank">{{ content }} </gl-link>
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-pt-6">
      <gl-button
        type="submit"
        variant="confirm"
        class="js-no-auto-disable gl-mr-2"
        :loading="isSaving"
        @click="onClick"
      >
        {{ submitButtonText }}
      </gl-button>
      <test-connection-button
        class="gl-mr-2"
        :disabled="!hasValidInput"
        :connection-test-input="formValues"
      />
      <gl-button :href="basePath">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </gl-form>
</template>
