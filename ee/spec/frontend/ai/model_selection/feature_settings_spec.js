import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import FeatureSettings from 'ee/ai/model_selection/feature_settings.vue';

import {
  mockCodeSuggestionsFeatureSettings,
  mockDuoChatFeatureSettings,
  mockMergeRequestFeatureSettings,
  mockIssueFeatureSettings,
  mockOtherDuoFeaturesSettings,
  mockAiFeatureSettings,
  mockAiFeatureSettingsWithAgenticChat,
  mockDuoAgentPlatformSettings,
  mockAgenticChatFeatureSetting,
} from './mock_data';

describe('FeatureSettings', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureSettings, {
      propsData: {
        featureSettings: mockAiFeatureSettings,
        isLoading: false,
        ...props,
      },
      provide: {
        modelSelectionAllowlistAvailable: false,
        ...provide,
      },
    });
  };

  const findFeatureSettings = () => wrapper.findComponent(FeatureSettings);
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findSettingsBlockByTitle = (title) =>
    findAllSettingsBlock().wrappers.find((block) => block.props('title') === title);
  const findDuoChatTable = () => wrapper.findComponentByTestId('duo-chat-table');
  const findCodeSuggestionsTable = () => wrapper.findComponentByTestId('code-suggestions-table');
  const findOtherDuoFeaturesTable = () => wrapper.findComponentByTestId('other-duo-features-table');
  const findDuoIssuesTable = () => wrapper.findComponentByTestId('duo-issues-table');
  const findDuoMergeRequestTable = () => wrapper.findComponentByTestId('duo-merge-requests-table');
  const findDuoAgentPlatformTable = () => wrapper.findComponentByTestId('duo-agent-platform-table');
  const findAgenticChatTable = () => wrapper.findComponentByTestId('duo-agentic-chat-table');

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettings().exists()).toBe(true);
  });

  it('renders the sections in the expected order', () => {
    createComponent();

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
    it('passes the correct loading state to `FeatureSettingsTableRows`', () => {
      createComponent({ props: { isLoading: true } });

      expect(findCodeSuggestionsTable().props('isLoading')).toBe(true);
      expect(findDuoChatTable().props('isLoading')).toBe(true);
      expect(findDuoMergeRequestTable().props('isLoading')).toBe(true);
      expect(findDuoIssuesTable().props('isLoading')).toBe(true);
      expect(findDuoAgentPlatformTable().props('isLoading')).toBe(true);
      expect(findOtherDuoFeaturesTable().props('isLoading')).toBe(true);
    });
  });

  describe.each`
    section                         | expectedTitle                      | expectedDescription                                                                                                        | findSectionTableFn           | expectedFeatureSettings
    ${'GitLab Duo Agent Platform'}  | ${'GitLab Duo Agent Platform'}     | ${'Multiple AI agents that work in parallel to help you create code, research results, and perform tasks simultaneously.'} | ${findDuoAgentPlatformTable} | ${mockDuoAgentPlatformSettings}
    ${'Duo Chat'}                   | ${'GitLab Duo Chat'}               | ${'An AI assistant that helps users accelerate software development using real-time conversational AI.'}                   | ${findDuoChatTable}          | ${mockDuoChatFeatureSettings}
    ${'Code Suggestions'}           | ${'Code Suggestions'}              | ${'Assists developers by generating and completing code in real-time.'}                                                    | ${findCodeSuggestionsTable}  | ${mockCodeSuggestionsFeatureSettings}
    ${'Duo merge request features'} | ${'GitLab Duo for merge requests'} | ${'AI-native features that help users accomplish tasks during the lifecycle of a merge request.'}                          | ${findDuoMergeRequestTable}  | ${mockMergeRequestFeatureSettings}
    ${'Duo issues'}                 | ${'GitLab Duo for issues'}         | ${'An AI-native feature that generates a summary of discussions on an issue.'}                                             | ${findDuoIssuesTable}        | ${mockIssueFeatureSettings}
    ${'Other Duo features'}         | ${'Other GitLab Duo features'}     | ${'AI-native features that support users outside of Chat or Code Suggestions.'}                                            | ${findOtherDuoFeaturesTable} | ${mockOtherDuoFeaturesSettings}
  `(
    '$section',
    ({ expectedTitle, expectedDescription, findSectionTableFn, expectedFeatureSettings }) => {
      beforeEach(() => {
        createComponent();
      });

      it('renders section and table', () => {
        const settingsBlock = findSettingsBlockByTitle(expectedTitle);

        expect(settingsBlock).toBeDefined();

        const msg = settingsBlock.findComponent(GlSprintf).attributes('message');
        expect(msg).toContain(expectedDescription);
        expect(findSectionTableFn().exists()).toBe(true);
      });

      it('passes correct featureSettings to section table', () => {
        expect(findSectionTableFn().props('featureSettings')).toEqual(expectedFeatureSettings);
      });
    },
  );

  describe('Agentic Chat section', () => {
    describe('when the model selection allowlist is available', () => {
      beforeEach(() => {
        createComponent({
          props: { featureSettings: mockAiFeatureSettingsWithAgenticChat },
          provide: { modelSelectionAllowlistAvailable: true },
        });
      });

      it('renders the Agentic Chat section table', () => {
        expect(findAgenticChatTable().exists()).toBe(true);
        expect(findAgenticChatTable().props('featureSettings')).toEqual([
          mockAgenticChatFeatureSetting,
        ]);
        expect(findAgenticChatTable().props('showAvailableModelsField')).toBe(true);
      });

      it('renders the sections in the expected order', () => {
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

      it('excludes the Agentic Chat feature from the Agent Platform section', () => {
        expect(findDuoAgentPlatformTable().props('featureSettings')).toEqual(
          mockDuoAgentPlatformSettings,
        );
      });
    });

    describe('when the model selection allowlist is not available', () => {
      beforeEach(() => {
        createComponent({
          props: { featureSettings: mockAiFeatureSettingsWithAgenticChat },
          provide: { modelSelectionAllowlistAvailable: false },
        });
      });

      it('does not render the Agentic Chat section', () => {
        expect(findAgenticChatTable().exists()).toBe(false);
      });

      it('keeps the Agentic Chat feature in the Agent Platform section', () => {
        expect(findDuoAgentPlatformTable().props('featureSettings')).toEqual([
          ...mockDuoAgentPlatformSettings,
          mockAgenticChatFeatureSetting,
        ]);
      });
    });
  });
});
