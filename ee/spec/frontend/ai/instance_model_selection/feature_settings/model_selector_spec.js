import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo, { createControlledMockApollo } from 'helpers/mock_apollo_helper';
import ModelSelector from 'ee/ai/instance_model_selection/feature_settings/components/model_selector.vue';
import GitlabManagedModelsDisclaimerModal from 'ee/ai/instance_model_selection/feature_settings/components/gitlab_managed_models_disclaimer_modal.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import updateAiFeatureSetting from 'ee/ai/instance_model_selection/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/ai/instance_model_selection/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import {
  PROVIDERS,
  GITLAB_DEFAULT_MODEL,
} from 'ee/ai/instance_model_selection/feature_settings/constants';
import { INSTANCE_MODEL_SELECTION_ROUTE_NAMES } from 'ee/ai/instance_model_selection/constants';
import { createAlert } from '~/alert';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import {
  mockSelfHostedModels,
  mockAiFeatureSettings,
  mockGitlabManagedModels,
  mockDefaultGitlabModel,
} from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

const EXPECTED_SELF_HOSTED_MODELS_OPTIONS = [
  {
    releaseState: 'GA',
    text: 'Model 1 (Mistral)',
    value: 'gid://gitlab/Ai::SelfHostedModel/1',
  },
  {
    releaseState: 'GA',
    text: 'Model 4 (GPT)',
    value: 'gid://gitlab/Ai::SelfHostedModel/4',
  },
  {
    releaseState: 'GA',
    text: 'Model 5 (Claude)',
    value: 'gid://gitlab/Ai::SelfHostedModel/5',
  },
  {
    releaseState: 'BETA',
    text: 'Model 2 (Code Llama)',
    value: 'gid://gitlab/Ai::SelfHostedModel/2',
  },
  {
    releaseState: 'BETA',
    text: 'Model 3 (CodeGemma)',
    value: 'gid://gitlab/Ai::SelfHostedModel/3',
  },
];

const EXPECTED_GITLAB_MANAGED_MODELS_OPTIONS = [
  {
    text: 'Claude Sonnet 4.0',
    value: 'claude_sonnet_4_20250514',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses',
    costIndicator: '$$$',
  },
  {
    text: 'Claude Sonnet 3.7',
    value: 'claude_sonnet_3_7_20250219_vertex',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses',
    costIndicator: '$$$',
  },
  {
    text: 'Claude Sonnet 4.6 - Anthropic',
    value: 'claude_sonnet_4_6',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses',
    costIndicator: '$$$',
  },
];

const EXPECTED_SELF_HOSTED_MODELS_GROUPED_OPTIONS = {
  text: 'Self-hosted models',
  options: [
    ...EXPECTED_SELF_HOSTED_MODELS_OPTIONS,
    {
      text: 'Disabled',
      value: PROVIDERS.DISABLED,
    },
  ],
};

const EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS = {
  text: 'GitLab managed models',
  options: EXPECTED_GITLAB_MANAGED_MODELS_OPTIONS,
};

const EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS_WITH_DEFAULT_MODEL_OPTION = {
  text: 'GitLab managed models',
  options: [
    ...EXPECTED_GITLAB_MANAGED_MODELS_OPTIONS,
    {
      text: 'Claude Sonnet 4.0 - Default',
      value: GITLAB_DEFAULT_MODEL,
      provider: 'Anthropic',
      description: 'Fast, cost-effective responses',
      costIndicator: '$$$',
    },
  ],
};

describe('ModelSelector', () => {
  let wrapper;

  const mockAiFeatureSetting = mockAiFeatureSettings[0];

  const updateFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettingUpdate: {
        errors: [],
      },
    },
  });

  const getFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: [],
      },
    },
  });

  const getSelfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        nodes: [],
      },
    },
  });
  const mockShowModal = jest.fn();

  const defaultHandlers = [
    [updateAiFeatureSetting, updateFeatureSettingsSuccessHandler],
    [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
    [getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler],
  ];

  const mountComponent = (mockApollo, { props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(ModelSelector, {
        apolloProvider: mockApollo,
        provide: {
          canManageSelfHostedModels: false,
          canManageDapSelfHostedModels: false,
          ...injectedProps,
        },
        propsData: {
          aiFeatureSetting: mockAiFeatureSetting,
          batchUpdateIsSaving: false,
          ...props,
        },
        stubs: {
          GitlabManagedModelsDisclaimerModal: stubComponent(GitlabManagedModelsDisclaimerModal, {
            methods: {
              showModal: mockShowModal,
            },
          }),
        },
        mocks: {
          $toast: {
            show: jest.fn(),
          },
        },
      }),
    );
  };

  const createComponent = ({ apolloHandlers = defaultHandlers, ...options } = {}) => {
    mountComponent(createMockApollo([...apolloHandlers]), options);
  };

  const createControlledComponent = ({ apolloHandlers = defaultHandlers, ...options } = {}) => {
    const { apolloProvider, resolveMutation, resolveQuery } = createControlledMockApollo([
      ...apolloHandlers,
    ]);

    mountComponent(apolloProvider, options);

    return { resolveMutation, resolveQuery };
  };

  const findModelSelector = () => wrapper.findComponent(ModelSelector);
  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findAddModelButton = () => wrapper.findComponentByTestId('add-self-hosted-model-button');
  const findDisclaimerModal = () => wrapper.findComponent(GitlabManagedModelsDisclaimerModal);
  const findSourceInfoIcon = () => wrapper.findComponentByTestId('model-source-info');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
  });

  it('renders compatible models header-text', () => {
    createComponent();

    expect(findModelSelectDropdown().props('headerText')).toBe('Compatible models');
  });

  describe('canAddSelfHostedModel', () => {
    describe('for Classic settings', () => {
      it.each`
        canManageDapSelfHostedModels | canManageSelfHostedModels | expected
        ${true}                      | ${true}                   | ${true}
        ${false}                     | ${true}                   | ${true}
        ${true}                      | ${false}                  | ${false}
        ${false}                     | ${false}                  | ${false}
      `(
        'returns expected canAddSelfHostedModel props',
        ({ canManageSelfHostedModels, canManageDapSelfHostedModels, expected }) => {
          createComponent({
            props: {
              aiFeatureSetting: { feature: 'code_suggestions', title: 'Code Suggestions' },
            },
            injectedProps: { canManageDapSelfHostedModels, canManageSelfHostedModels },
          });

          if (expected) {
            expect(findAddModelButton().text()).toBe('Add self-hosted model');
            expect(findAddModelButton().props('to')).toEqual({
              name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.NEW,
            });
          } else {
            expect(findAddModelButton().exists()).toBe(false);
          }
        },
      );
    });

    describe('for DAP settings', () => {
      describe.each`
        feature                              | title
        ${'duo_agent_platform'}              | ${'Duo Agent Platform'}
        ${'duo_agent_platform_agentic_chat'} | ${'Duo Agent Platform Agentic Chat'}
      `('for $feature: returns expected canAddSelfHostedModel props', ({ feature, title }) => {
        it.each`
          canManageDapSelfHostedModels | canManageSelfHostedModels | expected
          ${true}                      | ${true}                   | ${true}
          ${true}                      | ${false}                  | ${true}
          ${false}                     | ${true}                   | ${false}
          ${false}                     | ${false}                  | ${false}
        `(
          'with canManageDapSelfHostedModels=$canManageDapSelfHostedModels and canManageSelfHostedModels=$canManageSelfHostedModels',
          ({ canManageSelfHostedModels, canManageDapSelfHostedModels, expected }) => {
            createComponent({
              props: {
                aiFeatureSetting: { feature, title },
              },
              injectedProps: { canManageDapSelfHostedModels, canManageSelfHostedModels },
            });

            if (expected) {
              expect(findAddModelButton().text()).toBe('Add self-hosted model');
              expect(findAddModelButton().props('to')).toEqual({
                name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.NEW,
              });
            } else {
              expect(findAddModelButton().exists()).toBe(false);
            }
          },
        );
      });
    });
  });

  describe('for self-hosted models', () => {
    it('contains a list of options sorted by release state', () => {
      createComponent();

      const modelOptions = findModelSelectDropdown().props('items');
      const selfHostedModelsOptions = modelOptions[0].options;

      expect(
        selfHostedModelsOptions.map(({ text, releaseState }) => {
          const withReleaseState = releaseState ? [releaseState] : [];
          return [text, ...withReleaseState];
        }),
      ).toEqual([
        ['Model 1 (Mistral)', 'GA'],
        ['Model 4 (GPT)', 'GA'],
        ['Model 5 (Claude)', 'GA'],
        ['Model 2 (Code Llama)', 'BETA'],
        ['Model 3 (CodeGemma)', 'BETA'],
        ['Disabled'],
      ]);
    });

    it('does not render self-hosted models if there are none returned', () => {
      createComponent({
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validModels: { nodes: [] },
            validGitlabModels: { nodes: mockGitlabManagedModels },
          },
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS]);
    });
  });

  describe('with GitLab managed models', () => {
    it('renders two groups of options: self-hosted models and GitLab managed models', () => {
      createComponent({
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validGitlabModels: { nodes: mockGitlabManagedModels },
          },
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([
        EXPECTED_SELF_HOSTED_MODELS_GROUPED_OPTIONS,
        EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS,
      ]);
    });

    it('renders default GitLab model under GitLab managed models group if it exists', () => {
      createComponent({
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validModels: { nodes: [] },
            validGitlabModels: { nodes: mockGitlabManagedModels },
            defaultGitlabModel: mockDefaultGitlabModel,
          },
        },
      });

      const modelOptions = findModelSelectDropdown().props('items');
      expect(modelOptions).toStrictEqual([
        EXPECTED_GITLAB_MANAGED_MODELS_GROUPED_OPTIONS_WITH_DEFAULT_MODEL_OPTION,
      ]);
    });
  });

  describe('when an update is saving', () => {
    beforeEach(async () => {
      createComponent();

      await findModelSelectDropdown().vm.$emit('select', 'disabled');
    });

    it('updates the loading state', () => {
      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });

    it('emits an `update:is-saving` event', () => {
      expect(wrapper.emitted('update:is-saving')).toEqual([[true]]);
    });
  });

  describe('when a batch update is saving', () => {
    it('updates the loading state', () => {
      createComponent({ props: { batchUpdateIsSaving: true } });

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });
  });

  describe('updating the feature setting', () => {
    beforeEach(() => {
      createComponent();
    });

    describe.each`
      testCase               | selectedOption                          | provider                 | selfHostedModelId                       | offeredModelRef
      ${'self-hosted model'} | ${'gid://gitlab/Ai::SelfHostedModel/1'} | ${PROVIDERS.SELF_HOSTED} | ${'gid://gitlab/Ai::SelfHostedModel/1'} | ${null}
      ${'disabled'}          | ${'disabled'}                           | ${PROVIDERS.DISABLED}    | ${null}                                 | ${null}
    `(
      'with $testCase as selected option: calls the update mutation with the correct input',
      ({ selectedOption, provider, selfHostedModelId, offeredModelRef }) => {
        beforeEach(() => {
          const modelSelectDropdown = findModelSelectDropdown();
          modelSelectDropdown.vm.$emit('select', selectedOption);
        });

        it('calls the update mutation with the correct input', () => {
          expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              features: ['CODE_GENERATIONS'],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: selfHostedModelId,
              offeredModelRef,
            },
          });
        });

        it('does not call show disclaimer modal when selected', () => {
          expect(mockShowModal).not.toHaveBeenCalled();
        });
      },
    );

    describe.each`
      testCase                  | selectedOption                    | modelName                          | provider              | offeredModelRef
      ${'GitLab managed model'} | ${mockGitlabManagedModels[0].ref} | ${mockGitlabManagedModels[0].name} | ${PROVIDERS.VENDORED} | ${mockGitlabManagedModels[0].ref}
      ${'GitLab default model'} | ${GITLAB_DEFAULT_MODEL}           | ${'Claude Sonnet 4.0 - Default'}   | ${PROVIDERS.VENDORED} | ${GITLAB_DEFAULT_MODEL}
    `(
      'with $testCase as selected option',
      ({ selectedOption, modelName, provider, offeredModelRef }) => {
        beforeEach(() => {
          createComponent({
            props: {
              aiFeatureSetting: {
                ...mockAiFeatureSetting,
                validGitlabModels: { nodes: mockGitlabManagedModels },
                defaultGitlabModel: mockDefaultGitlabModel,
              },
            },
          });
          const modelSelectDropdown = findModelSelectDropdown();
          modelSelectDropdown.vm.$emit('select', selectedOption);
        });

        it('calls show disclaimer modal when selected', () => {
          expect(mockShowModal).toHaveBeenCalledTimes(1);
          expect(mockShowModal).toHaveBeenCalledWith(
            expect.objectContaining({
              value: selectedOption,
              text: modelName,
            }),
          );
        });

        it('calls update operations when Gitlab managed model modal is acknowledged', async () => {
          findDisclaimerModal().vm.$emit('confirm', selectedOption);
          await waitForPromises();

          expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              features: ['CODE_GENERATIONS'],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: null,
              offeredModelRef,
            },
          });
          expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
            'Successfully updated Code Suggestions / Code Generation',
          );
        });
      },
    );

    describe('when initial state is unassigned', () => {
      it('sets default GitLab model as the default when it is available', () => {
        createComponent({
          props: {
            aiFeatureSetting: {
              ...mockAiFeatureSetting,
              provider: PROVIDERS.UNASSIGNED,
              defaultGitlabModel: mockDefaultGitlabModel,
              gitlabModel: mockDefaultGitlabModel,
            },
          },
        });

        const modelSelectDropdown = findModelSelectDropdown();
        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          text: 'Claude Sonnet 4.0 - Default',
          value: GITLAB_DEFAULT_MODEL,
          provider: 'Anthropic',
          description: 'Fast, cost-effective responses',
          costIndicator: '$$$',
        });
      });

      it('does not set default GitLab model as the default when it is not available', () => {
        createComponent({
          props: {
            aiFeatureSetting: {
              ...mockAiFeatureSetting,
              provider: PROVIDERS.UNASSIGNED,
              defaultGitlabModel: null,
              gitlabModel: null,
            },
          },
        });

        const modelSelectDropdown = findModelSelectDropdown();
        expect(modelSelectDropdown.props('selectedOption')).toEqual(null);
      });
    });

    it('triggers a success toast', async () => {
      findModelSelectDropdown().vm.$emit('select', 'gid://gitlab/Ai::SelfHostedModel/1');

      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated Code Suggestions / Code Generation',
      );
    });

    it('does not HTML-escape special characters in the toast message', async () => {
      createComponent({
        props: {
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            mainFeature: 'GitLab Duo Agent Platform',
            title: 'Agents & flows',
          },
        },
      });

      findModelSelectDropdown().vm.$emit('select', 'gid://gitlab/Ai::SelfHostedModel/1');

      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated GitLab Duo Agent Platform / Agents & flows',
      );
    });

    it('refreshes self-hosted models and feature settings data', async () => {
      findModelSelectDropdown().vm.$emit('select', 'gid://gitlab/Ai::SelfHostedModel/1');

      await waitForPromises();

      expect(getSelfHostedModelsSuccessHandler).toHaveBeenCalled();
      expect(getFeatureSettingsSuccessHandler).toHaveBeenCalled();
    });

    describe('when the mutation has resolved but the refetched queries have not', () => {
      let resolveMutation;
      let resolveQuery;

      beforeEach(async () => {
        ({ resolveMutation, resolveQuery } = createControlledComponent());

        findModelSelectDropdown().vm.$emit('select', 'gid://gitlab/Ai::SelfHostedModel/1');

        await resolveMutation(updateAiFeatureSetting);
      });

      it('keeps the saving state until the refetched queries resolve', async () => {
        expect(wrapper.emitted('update:is-saving')).toEqual([[true]]);
        expect(findModelSelectDropdown().props('isLoading')).toBe(true);

        await resolveQuery(getSelfHostedModelsQuery);
        await resolveQuery(getAiFeatureSettingsQuery);

        expect(wrapper.emitted('update:is-saving')).toEqual([[true], [false]]);
        expect(findModelSelectDropdown().props('isLoading')).toBe(false);
      });
    });

    describe('when the feature state is changed', () => {
      it('updates the selected option', async () => {
        const modelSelectDropdown = findModelSelectDropdown();

        expect(modelSelectDropdown.props('selectedOption')).toBe(null);

        modelSelectDropdown.vm.$emit('select', 'disabled');
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            provider: PROVIDERS.DISABLED,
            selfHostedModel: null,
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          text: 'Disabled',
          value: PROVIDERS.DISABLED,
        });
      });
    });

    describe('when a model has been selected', () => {
      it('for a self-hosted model: displays the selected deployment name and model', async () => {
        const selectedModel = mockSelfHostedModels[0];
        const modelSelectDropdown = findModelSelectDropdown();

        modelSelectDropdown.vm.$emit('select', selectedModel.id);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            provider: PROVIDERS.SELF_HOSTED,
            selfHostedModel: { id: selectedModel.id },
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          value: selectedModel.id,
          text: `${selectedModel.name} (${selectedModel.modelDisplayName})`,
          releaseState: selectedModel.releaseState,
        });
      });

      it('for a GitLab managed model: displays the selected deployment name and model', async () => {
        const selectedModel = mockGitlabManagedModels[0];
        const modelSelectDropdown = findModelSelectDropdown();

        modelSelectDropdown.vm.$emit('select', selectedModel.ref);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...mockAiFeatureSetting,
            validGitlabModels: { nodes: mockGitlabManagedModels },
            provider: PROVIDERS.VENDORED,
            gitlabModel: { ref: selectedModel.ref },
          },
        });

        expect(modelSelectDropdown.props('selectedOption')).toStrictEqual({
          value: selectedModel.ref,
          text: selectedModel.name,
          provider: selectedModel.modelProvider,
          description: selectedModel.modelDescription,
          costIndicator: selectedModel.costIndicator,
        });
      });
    });
  });

  describe('source indicator', () => {
    const selfHostedTooltip =
      'This feature is using a self-hosted model, deployed on your own infrastructure.';
    const gitlabManagedTooltip =
      'This feature is using a GitLab managed model, external to your infrastructure.';

    describe('when the instance has both self-hosted and GitLab managed models', () => {
      const selfHostedFeature = {
        provider: PROVIDERS.SELF_HOSTED,
        selfHostedModel: { id: mockSelfHostedModels[0].id },
      };
      const gitlabManagedFeature = {
        provider: PROVIDERS.VENDORED,
        validGitlabModels: { nodes: mockGitlabManagedModels },
        gitlabModel: { ref: mockGitlabManagedModels[0].ref },
      };
      const defaultGitlabFeature = {
        provider: PROVIDERS.UNASSIGNED,
        defaultGitlabModel: mockDefaultGitlabModel,
        gitlabModel: null,
      };

      it.each`
        scenario                      | featureOverrides        | subtext                   | tooltip
        ${'a self-hosted model'}      | ${selfHostedFeature}    | ${'Self-hosted model'}    | ${selfHostedTooltip}
        ${'a GitLab managed model'}   | ${gitlabManagedFeature} | ${'GitLab managed model'} | ${gitlabManagedTooltip}
        ${'the default GitLab model'} | ${defaultGitlabFeature} | ${'GitLab managed model'} | ${gitlabManagedTooltip}
      `(
        'renders the subtext and info icon when $scenario is selected',
        ({ featureOverrides, subtext, tooltip }) => {
          createComponent({
            props: {
              hasMixedSources: true,
              aiFeatureSetting: { ...mockAiFeatureSetting, ...featureOverrides },
            },
          });

          expect(findModelSelectDropdown().props('selectedOption')).toMatchObject({ subtext });
          expect(findSourceInfoIcon().attributes('arialabel')).toBe(tooltip);
          expect(findSourceInfoIcon().props()).toMatchObject({
            name: 'information-o',
            variant: 'info',
          });
        },
      );

      it('hides the indicator when the feature is disabled', () => {
        createComponent({
          props: {
            hasMixedSources: true,
            aiFeatureSetting: {
              ...mockAiFeatureSetting,
              provider: PROVIDERS.DISABLED,
              selfHostedModel: null,
              gitlabModel: null,
              defaultGitlabModel: null,
            },
          },
        });

        expect(findModelSelectDropdown().props('selectedOption')).not.toHaveProperty('subtext');
        expect(findSourceInfoIcon().exists()).toBe(false);
      });

      it('hides the indicator when no model is selected', () => {
        createComponent({ props: { hasMixedSources: true } });

        expect(findSourceInfoIcon().exists()).toBe(false);
      });
    });

    describe('when the instance does not have a mix of model sources', () => {
      it('hides the indicator even when a model is selected', () => {
        createComponent({
          props: {
            hasMixedSources: false,
            aiFeatureSetting: {
              ...mockAiFeatureSetting,
              provider: PROVIDERS.VENDORED,
              validGitlabModels: { nodes: mockGitlabManagedModels },
              gitlabModel: { ref: mockGitlabManagedModels[0].ref },
            },
          },
        });

        expect(findModelSelectDropdown().props('selectedOption')).not.toHaveProperty('subtext');
        expect(findSourceInfoIcon().exists()).toBe(false);
      });
    });
  });

  describe('when an update fails', () => {
    const selectedModel = mockSelfHostedModels[0];
    const updateFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
      data: {
        aiFeatureSettingUpdate: {
          errors: ['Codegemma is incompatible with the Duo Chat feature'],
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        apolloHandlers: [
          [updateAiFeatureSetting, updateFeatureSettingsErrorHandler],
          [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
          [getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler],
        ],
      });

      findModelSelectDropdown().vm.$emit('select', selectedModel.id);

      await waitForPromises();
    });

    it('does not update the selected option', () => {
      expect(findModelSelectDropdown().props('selectedOption')).toBe(null);
    });

    it('triggers an error message', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Codegemma is incompatible with the Duo Chat feature',
        }),
      );
    });
  });
});
