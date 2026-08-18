import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';

import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import FeatureSettings from 'ee/ai/instance_model_selection/feature_settings/components/feature_settings.vue';
import getAiFeatureSettingsQuery from 'ee/ai/instance_model_selection/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import BetaFeaturesAlert from 'ee/ai/instance_model_selection/shared/components/beta_features_alert.vue';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';

import {
  mockAiFeatureSettings,
  mockDuoChatFeatureSettings,
  mockCodeSuggestionsFeatureSettings,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('FeatureSettings', () => {
  let wrapper;

  const getAiFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: mockAiFeatureSettings,
        errors: [],
      },
    },
  });

  const getSelfHostedModelsEmptyHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        nodes: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [getAiFeatureSettingsQuery, getAiFeatureSettingsSuccessHandler],
      [getSelfHostedModelsQuery, getSelfHostedModelsEmptyHandler],
    ],
    injectedProps = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = shallowMountExtended(FeatureSettings, {
      apolloProvider: mockApollo,
      provide: {
        betaModelsEnabled: true,
        canManageSelfHostedModels: true,
        canManageDapSelfHostedModels: true,
        modelSelectionAllowlistAvailable: false,
        ...injectedProps,
      },
    });
  };

  const findFeatureSettings = () => wrapper.findComponent(FeatureSettings);
  const findDuoChatTable = () => wrapper.findComponentByTestId('duo-chat-table');
  const findCodeSuggestionsTable = () => wrapper.findComponentByTestId('code-suggestions-table');
  const findOtherDuoFeaturesTable = () => wrapper.findComponentByTestId('other-duo-features-table');
  const findDuoMergeRequestTable = () => wrapper.findComponentByTestId('duo-merge-requests-table');
  const findDuoIssuesTable = () => wrapper.findComponentByTestId('duo-issues-table');
  const findDuoAgentPlatformTable = () => wrapper.findComponentByTestId('duo-agent-platform-table');
  const findAgenticChatTable = () => wrapper.findComponentByTestId('duo-agentic-chat-table');
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findSettingsBlockByTitle = (title) =>
    findAllSettingsBlock().wrappers.find((block) => block.props('title') === title);
  const findBetaAlert = () => wrapper.findComponent(BetaFeaturesAlert);

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  it('renders the component', () => {
    expect(findFeatureSettings().exists()).toBe(true);
  });

  it('renders the sections in the expected order', () => {
    expect(findAllSettingsBlock().wrappers.map((block) => block.props('title'))).toEqual([
      'GitLab Duo Agent Platform',
      'GitLab Duo Chat',
      'Code Suggestions',
      'GitLab Duo for merge requests',
      'GitLab Duo for issues',
      'Other GitLab Duo features',
    ]);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to FeatureSettingsTable', () => {
      createComponent();

      [findCodeSuggestionsTable, findDuoChatTable].forEach((findTableFn) => {
        expect(findTableFn().props('isLoading')).toBe(true);
      });
    });
  });

  describe('when feature settings query is successful', () => {
    beforeEach(async () => {
      createComponent({
        injectedProps: {
          modelSelectionAllowlistAvailable: true,
        },
      });
      await waitForPromises();
    });

    describe.each`
      section                         | expectedTitle                      | expectedDescription                                                                                                        | findSectionTableFn           | expectedFeatureSettings
      ${'GitLab Duo Agent Platform'}  | ${'GitLab Duo Agent Platform'}     | ${'Multiple AI agents that work in parallel to help you create code, research results, and perform tasks simultaneously.'} | ${findDuoAgentPlatformTable} | ${[['duo_agent_platform', 'EXPERIMENT']]}
      ${'Agentic Chat'}               | ${'GitLab Duo Agentic Chat'}       | ${'An AI chat assistant that autonomously uses tools and performs multi-step tasks to answer complex questions.'}          | ${findAgenticChatTable}      | ${[['duo_agent_platform_agentic_chat', 'GA']]}
      ${'Duo Chat'}                   | ${'GitLab Duo Chat'}               | ${'An AI assistant that helps users accelerate software development using real-time conversational AI.'}                   | ${findDuoChatTable}          | ${[['duo_chat', 'GA'], ['duo_chat_explain_code', 'BETA'], ['duo_chat_troubleshoot_job', 'EXPERIMENT']]}
      ${'Code Suggestions'}           | ${'Code Suggestions'}              | ${'Assists developers by generating and completing code in real-time.'}                                                    | ${findCodeSuggestionsTable}  | ${[['code_generations', 'GA'], ['code_completions', 'GA']]}
      ${'Duo merge request features'} | ${'GitLab Duo for merge requests'} | ${'AI-native features that help users accomplish tasks during the lifecycle of a merge request.'}                          | ${findDuoMergeRequestTable}  | ${[['summarize_review', 'BETA'], ['generate_commit_message', 'BETA']]}
      ${'Duo issues'}                 | ${'GitLab Duo for issues'}         | ${'An AI-native feature that generates a summary of discussions on an issue.'}                                             | ${findDuoIssuesTable}        | ${[['duo_chat_summarize_comments', 'BETA']]}
      ${'Other Duo features'}         | ${'Other GitLab Duo features'}     | ${'AI-native features that support users outside of Chat or Code Suggestions.'}                                            | ${findOtherDuoFeaturesTable} | ${[['glab_ask_git_command', 'BETA']]}
    `(
      '$section',
      ({ expectedTitle, expectedDescription, findSectionTableFn, expectedFeatureSettings }) => {
        it('renders section and table', () => {
          const settingsBlock = findSettingsBlockByTitle(expectedTitle);

          expect(settingsBlock).toBeDefined();

          const msg = settingsBlock.findComponent(GlSprintf).attributes('message');
          expect(msg).toContain(expectedDescription);
          if (expectedTitle === 'GitLab Duo Chat') {
            expect(msg).toContain('This setting is for regular Duo Chat only.');
          }
          expect(findSectionTableFn().exists()).toBe(true);
        });

        it('passes sorted feature settings by release state as table props', () => {
          expect(
            findSectionTableFn()
              .props('featureSettings')
              .map((fs) => [fs.feature, fs.releaseState]),
          ).toEqual(expectedFeatureSettings);
        });
      },
    );

    describe('when the user can not manage DAP self-hosted models', () => {
      it('does not show the `GitLab Duo Agent Platform` or `GitLab Duo Agentic Chat` sections', () => {
        createComponent({
          injectedProps: {
            canManageDapSelfHostedModels: false,
          },
        });

        expect(findDuoAgentPlatformTable().exists()).toBe(false);
        expect(findAgenticChatTable().exists()).toBe(false);
      });
    });

    describe('when the model selection allowlist is unavailable', () => {
      // This is the case for self-managed offline instances: with no online
      // cloud license the backend policy resolves `modelSelectionAllowlistAvailable`
      // to false, so the `Available models` column must not be shown at all.
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('does not show the `GitLab Duo Agentic Chat` section', () => {
        expect(findAgenticChatTable().exists()).toBe(false);
      });

      it('includes agentic chat feature in the `GitLab Duo Agent Platform` section', () => {
        expect(
          findDuoAgentPlatformTable()
            .props('featureSettings')
            .map((fs) => fs.feature),
        ).toContain('duo_agent_platform_agentic_chat');
      });
    });

    describe('when the model selection allowlist is available', () => {
      beforeEach(async () => {
        createComponent({
          injectedProps: {
            modelSelectionAllowlistAvailable: true,
          },
        });
        await waitForPromises();
      });

      it('shows the `Agentic Chat` section separately', () => {
        expect(findAgenticChatTable().exists()).toBe(true);
      });

      it('renders table sections in the expected order', () => {
        expect(findAllSettingsBlock().wrappers.map((block) => block.props('title'))).toEqual([
          'GitLab Duo Agent Platform',
          'GitLab Duo Agentic Chat',
          'GitLab Duo Chat',
          'Code Suggestions',
          'GitLab Duo for merge requests',
          'GitLab Duo for issues',
          'Other GitLab Duo features',
        ]);
      });

      it('excludes agentic chat from the `GitLab Duo Agent Platform` section', () => {
        expect(
          findDuoAgentPlatformTable()
            .props('featureSettings')
            .map((fs) => fs.feature),
        ).not.toContain('duo_agent_platform_agentic_chat');
      });

      it('passes showAvailableModelsField=true only to the `GitLab Duo Agentic Chat` table', () => {
        expect(findAgenticChatTable().props('showAvailableModelsField')).toBe(true);
        expect(findDuoAgentPlatformTable().props('showAvailableModelsField')).toBe(false);
        expect(findCodeSuggestionsTable().props('showAvailableModelsField')).toBe(false);
      });
    });

    it('does not render optional sections when they have no feature settings', async () => {
      const alwaysShownFeatureSettings = [
        ...mockDuoChatFeatureSettings,
        ...mockCodeSuggestionsFeatureSettings,
      ];
      const getFeatureSettingsExcludingOtherDuoSuccessHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            nodes: alwaysShownFeatureSettings,
            errors: [],
          },
        },
      });

      createComponent({
        apolloHandlers: [
          [getAiFeatureSettingsQuery, getFeatureSettingsExcludingOtherDuoSuccessHandler],
          [getSelfHostedModelsQuery, getSelfHostedModelsEmptyHandler],
        ],
      });
      await waitForPromises();

      expect(findAllSettingsBlock()).toHaveLength(2);
      expect(findOtherDuoFeaturesTable().exists()).toBe(false);
      expect(findDuoAgentPlatformTable().exists()).toBe(false);
      expect(findDuoIssuesTable().exists()).toBe(false);
      expect(findDuoMergeRequestTable().exists()).toBe(false);
    });
  });

  describe('beta features alert', () => {
    describe.each`
      betaModelsEnabled | canManageSelfHostedModels | visible
      ${false}          | ${true}                   | ${true}
      ${false}          | ${false}                  | ${false}
      ${true}           | ${true}                   | ${false}
      ${true}           | ${false}                  | ${false}
    `(
      'betaModelsEnabled=$betaModelsEnabled, canManageSelfHostedModels=$canManageSelfHostedModels',
      ({ betaModelsEnabled, canManageSelfHostedModels, visible }) => {
        it(`${visible ? 'displays' : 'hides'} beta features alert`, () => {
          createComponent({
            injectedProps: {
              betaModelsEnabled,
              canManageSelfHostedModels,
            },
          });

          if (visible) {
            expect(findBetaAlert().exists()).toBe(true);
            expect(findBetaAlert().props('message')).toBe(
              'More features are available in beta. You can %{linkStart}turn on AI-native beta features%{linkEnd}.',
            );
          } else {
            expect(findBetaAlert().exists()).toBe(false);
          }
        });
      },
    );
  });

  describe('when the API request is unsuccessful', () => {
    describe('due to a general error', () => {
      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [
            [getAiFeatureSettingsQuery, jest.fn().mockRejectedValue('ERROR')],
            [getSelfHostedModelsQuery, getSelfHostedModelsEmptyHandler],
          ],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [
            [getAiFeatureSettingsQuery, getAiFeatureSettingsErrorHandler],
            [getSelfHostedModelsQuery, getSelfHostedModelsEmptyHandler],
          ],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });
  });

  describe('self-hosted models query', () => {
    const featureSettingsWithGitlabModelsHandler = jest.fn().mockResolvedValue({
      data: {
        aiFeatureSettings: {
          nodes: [
            {
              ...mockAiFeatureSettings[0],
              validGitlabModels: {
                nodes: [
                  {
                    ref: 'claude_sonnet_4_20250514',
                    name: 'Claude Sonnet 4.0',
                    modelProvider: 'Anthropic',
                    modelDescription: 'Fast, cost-effective responses',
                    costIndicator: '$$$',
                  },
                ],
              },
            },
            ...mockAiFeatureSettings.slice(1),
          ],
          errors: [],
        },
      },
    });

    const selfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
      data: {
        aiSelfHostedModels: {
          nodes: [
            {
              id: 'gid://gitlab/Ai::SelfHostedModel/1',
              name: 'Model 1',
              model: 'mistral',
              modelDisplayName: 'Mistral',
              identifier: 'mistral-1',
              endpoint: 'https://example.com',
              hasApiToken: false,
              releaseState: 'GA',
              featureSettings: { nodes: [] },
            },
          ],
        },
      },
    });

    it('renders the table with hasMixedSources=false when the query fails', async () => {
      createComponent({
        apolloHandlers: [
          [getAiFeatureSettingsQuery, featureSettingsWithGitlabModelsHandler],
          [getSelfHostedModelsQuery, jest.fn().mockRejectedValue(new Error('failed'))],
        ],
      });

      await waitForPromises();

      expect(findCodeSuggestionsTable().exists()).toBe(true);
      expect(findCodeSuggestionsTable().props('hasMixedSources')).toBe(false);
    });

    it('renders the table with hasMixedSources=true when the query returns models alongside GitLab managed models', async () => {
      createComponent({
        apolloHandlers: [
          [getAiFeatureSettingsQuery, featureSettingsWithGitlabModelsHandler],
          [getSelfHostedModelsQuery, selfHostedModelsSuccessHandler],
        ],
      });

      await waitForPromises();

      expect(findCodeSuggestionsTable().exists()).toBe(true);
      expect(findCodeSuggestionsTable().props('hasMixedSources')).toBe(true);
    });
  });
});
