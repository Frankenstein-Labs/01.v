import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SelfHostedModelForm from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_model_form.vue';
import PlatformSelector from 'ee/ai/instance_model_selection/self_hosted_models/components/platform_selector.vue';
import TestConnectionButton from 'ee/ai/instance_model_selection/self_hosted_models/components/test_connection_button.vue';
import ModelSelector from 'ee/ai/instance_model_selection/self_hosted_models/components/model_selector.vue';
import BetaFeaturesAlert from 'ee/ai/instance_model_selection/shared/components/beta_features_alert.vue';
import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';
import createSelfHostedModelMutation from 'ee/ai/instance_model_selection/self_hosted_models/graphql/mutations/create_self_hosted_model.mutation.graphql';
import updateSelfHostedModelMutation from 'ee/ai/instance_model_selection/self_hosted_models/graphql/mutations/update_self_hosted_model.mutation.graphql';
import { createAlert } from '~/alert';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import {
  SELF_HOSTED_MODEL_MUTATIONS,
  SELF_HOSTED_MODEL_PLATFORMS,
  BEDROCK_DUMMY_ENDPOINT,
  VERTEX_DUMMY_ENDPOINT,
} from 'ee/ai/instance_model_selection/self_hosted_models/constants';
import {
  SELF_HOSTED_MODEL_OPTIONS,
  mockSelfHostedModel,
  mockBedrockSelfHostedModel,
  mockVertexAiSelfHostedModel,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility');

describe('SelfHostedModelForm', () => {
  let wrapper;

  const basePath = '/admin/gitlab_duo/model_selection';
  const duoConfigurationSettingsPath = '/admin/gitlab_duo/configuration';
  const createMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelCreate: {
        errors: [],
      },
    },
  });

  const createComponent = async ({
    props = {
      mutationData: {
        name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
        mutation: createSelfHostedModelMutation,
      },
    },
    apolloHandlers = [[createSelfHostedModelMutation, createMutationSuccessHandler]],
    injectedProps = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mountExtended(SelfHostedModelForm, {
      attachTo: document.body,
      apolloProvider: mockApollo,
      provide: {
        basePath,
        betaModelsEnabled: true,
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
        duoConfigurationSettingsPath,
        ...injectedProps,
      },
      propsData: {
        ...props,
      },
    });

    await waitForPromises();
  };

  beforeEach(async () => {
    await createComponent({
      props: {
        mutationData: {
          name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
          mutation: createSelfHostedModelMutation,
        },
      },
    });
  });

  // Find elements
  const findGlForm = () => wrapper.findComponent(GlForm);
  const findNameInputField = () => wrapper.findByLabelText('Deployment name', { exact: false });
  const findEndpointInputField = () => wrapper.findByLabelText('Endpoint', { exact: false });
  const findPlatformSelector = () => wrapper.findComponent(PlatformSelector);
  const findIdentifierInputField = () =>
    wrapper.findByLabelText('Model identifier', { exact: false });
  const findApiKeyInputField = () => wrapper.findComponent(InputCopyToggleVisibility);
  const findModelSelector = () => wrapper.findComponent(ModelSelector);
  const findCreateButton = () => wrapper.find('button[type="submit"]');
  const findCancelButton = () => wrapper.findByText('Cancel');
  const findTestConnectionButton = () => wrapper.findComponent(TestConnectionButton);
  const findBetaAlert = () => wrapper.findComponent(BetaFeaturesAlert);
  const findIdentifierInput = () => wrapper.findByLabelText('Model identifier', { exact: false });
  const findIdentifierLabelDescription = () =>
    wrapper.findByText(/Provide the model identifier/, { exact: false });

  // Find validation messages
  const findNameValidationMessage = () => wrapper.findByText('Please enter a deployment name.');
  const findModelValidationMessage = () => wrapper.findByText('Please select a model.');
  const findEndpointValidationMessage = () => wrapper.findByText('Please enter an endpoint.');
  const findIdentifierValidationMessage = () =>
    wrapper.findByText('Please enter a model identifier.');
  const findIdentifierTooLongValidationMessage = () =>
    wrapper.findByText('Model identifier must be less than 255 characters.');

  it('renders the self-hosted model form', () => {
    expect(findGlForm().exists()).toBe(true);
  });

  describe('when beta models are enabled', () => {
    it('does not display a beta models info alert', () => {
      expect(findBetaAlert().exists()).toBe(false);
    });
  });

  describe('when beta models are disabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { betaModelsEnabled: false } });
    });

    it('displays a beta models info alert', () => {
      expect(findBetaAlert().exists()).toBe(true);
    });
  });

  describe('form fields', () => {
    describe('for all platforms', () => {
      it('renders the name input field', () => {
        expect(findNameInputField().exists()).toBe(true);
      });

      describe('platform selector', () => {
        it('renders the platform selector', () => {
          expect(findPlatformSelector().exists()).toBe(true);
        });

        describe('when platform selector emits `update:platform`', () => {
          it('updates platform value', async () => {
            expect(findPlatformSelector().props('platform')).toBe('API');

            findPlatformSelector().vm.$emit('update:platform', 'VERTEX_AI');
            await nextTick();

            expect(findPlatformSelector().props('platform')).toBe('VERTEX_AI');
          });
        });
      });

      describe('model selector', () => {
        it('renders the model selector', () => {
          expect(findModelSelector().exists()).toBe(true);
        });

        it('updates model value when model selector emits `update:model`', async () => {
          expect(findModelSelector().props('selectedModel')).toBe('');

          findModelSelector().vm.$emit('update:model', 'MISTRAL');
          await nextTick();

          expect(findModelSelector().props('selectedModel')).toBe('MISTRAL');
        });
      });
    });

    describe('when platform is API', () => {
      it('renders the endpoint input field', () => {
        expect(findEndpointInputField().exists()).toBe(true);
      });

      it('renders the optional API token input field', () => {
        expect(findApiKeyInputField().exists()).toBe(true);
      });

      describe('identifier placeholder', () => {
        it('shows custom_openai/ placeholder for non-cloud provider models', async () => {
          await findModelSelector().vm.$emit('update:model', 'MISTRAL');

          expect(findIdentifierInput().attributes('placeholder')).toBe('custom_openai/');
        });

        it('shows no placeholder for cloud provider models', async () => {
          await findModelSelector().vm.$emit('update:model', 'GPT');

          expect(findIdentifierInput().attributes('placeholder')).toBe('');

          await findModelSelector().vm.$emit('update:model', 'CLAUDE_3');

          expect(findIdentifierInput().attributes('placeholder')).toBe('');
        });
      });

      describe('identifier label description', () => {
        it('shows custom_openai/ format for non-cloud provider models', async () => {
          await findModelSelector().vm.$emit('update:model', 'MISTRAL');

          expect(findIdentifierLabelDescription().text()).toContain('custom_openai/model-name');
        });

        it('shows provider/ format for cloud provider models', async () => {
          await findModelSelector().vm.$emit('update:model', 'GPT');

          expect(findIdentifierLabelDescription().text()).toContain('provider/model-name');

          await findModelSelector().vm.$emit('update:model', 'CLAUDE_3');

          expect(findIdentifierLabelDescription().text()).toContain('provider/model-name');
        });
      });
    });

    describe.each`
      platform                                 | identifierPrefix | setupMessage
      ${SELF_HOSTED_MODEL_PLATFORMS.BEDROCK}   | ${'bedrock/'}    | ${'AWS Bedrock Configuration Guide'}
      ${SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI} | ${'vertex_ai/'}  | ${'Google Vertex AI Configuration Guide'}
    `('when platform is $platform', ({ platform, identifierPrefix, setupMessage }) => {
      beforeEach(() => {
        findPlatformSelector().vm.$emit('update:platform', platform);
      });

      it('does not render the endpoint input field', () => {
        expect(findEndpointInputField().exists()).toBe(false);
      });

      it('does not render the API token input field', () => {
        expect(findApiKeyInputField().exists()).toBe(false);
      });

      it('renders the correct setup message', () => {
        expect(findGlForm().text()).toMatch(setupMessage);
      });

      describe('identifier placeholder', () => {
        it(`shows the ${identifierPrefix} placeholder regardless of model`, async () => {
          await findModelSelector().vm.$emit('update:model', 'MISTRAL');
          expect(findIdentifierInput().attributes('placeholder')).toBe(identifierPrefix);

          await findModelSelector().vm.$emit('update:model', 'GPT');
          expect(findIdentifierInput().attributes('placeholder')).toBe(identifierPrefix);
        });
      });

      describe('identifier label description', () => {
        it(`shows ${identifierPrefix} format regardless of model`, async () => {
          await findModelSelector().vm.$emit('update:model', 'MISTRAL');
          expect(findIdentifierLabelDescription().text()).toContain(
            `${identifierPrefix}model-name`,
          );

          await findModelSelector().vm.$emit('update:model', 'GPT');
          expect(findIdentifierLabelDescription().text()).toContain(
            `${identifierPrefix}model-name`,
          );
        });
      });
    });
  });

  describe('form validations', () => {
    describe('when platform is API', () => {
      it('displays validation errors when required fields are empty', async () => {
        await findGlForm().trigger('submit');

        expect(findNameValidationMessage().exists()).toBe(true);
        expect(findModelValidationMessage().exists()).toBe(true);
        expect(findEndpointValidationMessage().exists()).toBe(true);
        expect(findIdentifierValidationMessage().exists()).toBe(true);
      });

      it('displays validation error when identifier is too long', async () => {
        const longModelIdentifier = `identifier/${'looooong-identifier'.repeat(255)}`;
        await findIdentifierInputField().setValue(longModelIdentifier);
        await findGlForm().trigger('submit');

        expect(findIdentifierTooLongValidationMessage().exists()).toBe(true);
      });
    });

    describe.each`
      platform                                 | identifierPrefix
      ${SELF_HOSTED_MODEL_PLATFORMS.BEDROCK}   | ${'bedrock/'}
      ${SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI} | ${'vertex_ai/'}
    `('when platform is $platform', ({ platform, identifierPrefix }) => {
      beforeEach(() => {
        findPlatformSelector().vm.$emit('update:platform', platform);
      });

      it('displays validation errors when required fields are empty', async () => {
        await findGlForm().trigger('submit');

        expect(findNameValidationMessage().exists()).toBe(true);
        expect(findModelValidationMessage().exists()).toBe(true);
        expect(findIdentifierValidationMessage().exists()).toBe(true);
      });

      it('displays validation error for invalid identifier', async () => {
        await findIdentifierInputField().setValue('invalid/identifier');
        await findGlForm().trigger('submit');

        expect(
          wrapper.findByText(`Model identifier must start with "${identifierPrefix}"`).exists(),
        ).toBe(true);
      });

      it('displays validation error when identifier is too long', async () => {
        const longModelIdentifier = `${identifierPrefix}${'looooong-identifier'.repeat(255)}`;
        await findIdentifierInputField().setValue(longModelIdentifier);
        await findGlForm().trigger('submit');

        expect(findIdentifierTooLongValidationMessage().exists()).toBe(true);
      });
    });
  });

  describe('test connection button', () => {
    it('renders the button', () => {
      expect(findTestConnectionButton().exists()).toBe(true);
    });

    it('passes the correct props', async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findModelSelector().vm.$emit('update:model', 'MISTRAL');
      await findIdentifierInputField().setValue('identifier/test');
      await findApiKeyInputField().vm.$emit('input', 'test-abc-123');

      expect(findTestConnectionButton().props()).toEqual({
        connectionTestInput: {
          name: 'test deployment',
          model: 'MISTRAL',
          endpoint: 'http://test.com',
          identifier: 'identifier/test',
          apiToken: 'test-abc-123',
          provider: 'API',
        },
        disabled: false,
      });
    });

    it('is disabled when there are missing inputs', () => {
      expect(findTestConnectionButton().props('disabled')).toBe(true);
    });
  });

  it('renders a cancel button', () => {
    expect(findCancelButton().exists()).toBe(true);
  });

  describe('when required form inputs are missing', () => {
    it('does not invoke mutation', async () => {
      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(createMutationSuccessHandler).not.toHaveBeenCalled();
    });
  });

  describe('server errors', () => {
    describe('when deployment name is not unique', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: ['Validation failed: Name has already been taken'],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findModelSelector().vm.$emit('update:model', 'MISTRAL');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please enter a unique deployment name.');
      });
    });

    describe('when endpoint is not valid', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: [
              'Validation failed: Endpoint is blocked: Only allowed schemes are http, https',
            ],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('invalid endpoint');
        await findModelSelector().vm.$emit('update:model', 'MISTRAL');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please add a valid endpoint.');
      });
    });

    describe('when the error is not specific', () => {
      it('displays a generic error alert', async () => {
        const error = new Error();
        const createMutationErrorHandler = jest.fn().mockRejectedValue(error);

        await createComponent({
          apolloHandlers: [[createSelfHostedModelMutation, createMutationErrorHandler]],
        });

        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findModelSelector().vm.$emit('update:model', 'MISTRAL');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'There was an error saving the self-hosted model. Please try again.',
            error,
            captureError: true,
          }),
        );
      });
    });
  });

  describe('When creating a self-hosted model', () => {
    beforeEach(async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findModelSelector().vm.$emit('update:model', 'MISTRAL');
      await findIdentifierInputField().setValue('provider/model-name');

      wrapper.find('form').trigger('submit.prevent');
    });

    it('renders the submit button with the correct text', () => {
      const button = findCreateButton();

      expect(button.text()).toBe('Add self-hosted model');
    });

    describe.each`
      platform                                 | identifierPrefix    | endpoint
      ${SELF_HOSTED_MODEL_PLATFORMS.API}       | ${'custom_openai/'} | ${'http://test.com'}
      ${SELF_HOSTED_MODEL_PLATFORMS.BEDROCK}   | ${'bedrock/'}       | ${BEDROCK_DUMMY_ENDPOINT}
      ${SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI} | ${'vertex_ai/'}     | ${VERTEX_DUMMY_ENDPOINT}
    `('when model is a $platform model', ({ platform, identifierPrefix, endpoint }) => {
      it('invokes the create mutation with correct input variables', async () => {
        await findPlatformSelector().vm.$emit('update:platform', platform);
        await findIdentifierInputField().setValue(`${identifierPrefix}example-model`);

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(createMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            name: 'test deployment',
            endpoint,
            model: 'MISTRAL',
            apiToken: '',
            identifier: `${identifierPrefix}example-model`,
            provider: platform,
          },
        });
      });
    });

    describe('when model successfully created', () => {
      beforeEach(async () => {
        await waitForPromises();
      });

      it('displays success message', () => {
        expect(visitUrlWithAlerts).toHaveBeenCalledWith(basePath, [
          expect.objectContaining({
            message: 'Model added. Select it for a feature to start using it.',
            variant: 'success',
          }),
        ]);
      });
    });
  });

  describe('When editing a self-hosted model', () => {
    const updateMutationSuccessHandler = jest.fn().mockResolvedValue({
      data: {
        aiSelfHostedModelUpdate: {
          errors: [],
        },
      },
    });

    beforeEach(async () => {
      await createComponent({
        props: {
          initialFormValues: mockSelfHostedModel,
          mutationData: {
            name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
            mutation: updateSelfHostedModelMutation,
          },
          submitButtonText: 'Save changes',
        },
        apolloHandlers: [[updateSelfHostedModelMutation, updateMutationSuccessHandler]],
      });
    });

    it('renders the submit button with the correct text', () => {
      const button = findCreateButton();

      expect(button.text()).toBe('Save changes');
    });

    it('renders the model selector with initial model', () => {
      expect(findModelSelector().props('selectedModel')).toBe('MISTRAL');
    });

    describe('when model is an API model', () => {
      it('invokes the update mutation with correct input variables', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findModelSelector().vm.$emit('update:model', 'MISTRAL');
        await findApiKeyInputField().vm.$emit('input', 'abc123');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            id: mockSelfHostedModel.id,
            name: 'test deployment',
            endpoint: 'http://test.com',
            model: 'MISTRAL',
            apiToken: 'abc123',
            identifier: 'provider/model-name',
            provider: 'API',
          },
        });
      });
    });

    describe.each`
      platform                                 | identifierPrefix | endpoint                  | mockData
      ${SELF_HOSTED_MODEL_PLATFORMS.BEDROCK}   | ${'bedrock/'}    | ${BEDROCK_DUMMY_ENDPOINT} | ${mockBedrockSelfHostedModel}
      ${SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI} | ${'vertex_ai/'}  | ${VERTEX_DUMMY_ENDPOINT}  | ${mockVertexAiSelfHostedModel}
    `('when model is a $platform model', ({ identifierPrefix, endpoint, mockData }) => {
      beforeEach(async () => {
        await createComponent({
          props: {
            initialFormValues: mockData,
            mutationData: {
              name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
              mutation: updateSelfHostedModelMutation,
            },
            submitButtonText: 'Edit self-hosted model',
          },
          apolloHandlers: [[updateSelfHostedModelMutation, updateMutationSuccessHandler]],
        });
      });

      it('invokes the update mutation with correct input variables', async () => {
        await findNameInputField().setValue(mockData.name);
        await findModelSelector().vm.$emit('update:model', 'MISTRAL');
        await findIdentifierInputField().setValue(`${identifierPrefix}new-example-model`);

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            id: mockData.id,
            name: mockData.name,
            endpoint,
            model: 'MISTRAL',
            apiToken: '',
            identifier: `${identifierPrefix}new-example-model`,
            provider: mockData.provider,
          },
        });
      });
    });

    it('displays success message when model successfully saved', async () => {
      wrapper.find('form').trigger('submit');

      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(basePath, [
        expect.objectContaining({
          message: 'The self-hosted model was successfully saved.',
          variant: 'success',
        }),
      ]);
    });
  });
});
