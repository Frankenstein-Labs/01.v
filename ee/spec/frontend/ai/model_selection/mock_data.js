import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';

export const mockListItems = [
  {
    value: 'claude_3_5_sonnet_20240620',
    text: 'Claude Sonnet 3.5',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
  {
    value: 'claude_3_7_sonnet_20240620',
    text: 'Claude Sonnet 3.7',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
  {
    value: 'claude_3_haiku_20240307',
    text: 'Claude Haiku 3',
    provider: 'Anthropic',
    description: 'Earlier generation model for high-volume tasks.',
    costIndicator: '$',
  },
  {
    value: GITLAB_DEFAULT_MODEL,
    text: 'Claude Sonnet 3.7 - Default',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
];

const selectableModels = [
  {
    ref: 'claude_sonnet_3_7_20250219',
    name: 'Claude Sonnet 3.7',
    modelProvider: 'Anthropic',
    modelDescription: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
  {
    ref: 'claude_3_5_sonnet_20240620',
    name: 'Claude Sonnet 3.5',
    modelProvider: 'Anthropic',
    modelDescription: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
  {
    ref: 'claude_3_haiku_20240307"',
    name: 'Claude Haiku 3',
    modelProvider: 'Anthropic',
    modelDescription: 'Earlier generation model for high-volume tasks.',
    costIndicator: '$',
  },
];

export const mockCodeSuggestionsFeatureSettings = [
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    selectedModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
    },
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    selectedModel: {
      ref: GITLAB_DEFAULT_MODEL,
      name: 'GitLab default model',
      modelProvider: 'Anthropic',
    },
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
];

export const mockDuoChatFeatureSettings = [
  {
    feature: 'duo_chat',
    title: 'General Chat',
    mainFeature: 'GitLab Duo Chat',
    selectedModel: null,
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
];

export const mockMergeRequestFeatureSettings = [
  {
    feature: 'summarize_review',
    title: 'Code Review Summary',
    mainFeature: 'GitLab Duo for merge requests',
    selectedModel: null,
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
  {
    feature: 'generate_commit_message',
    title: 'Merge Commit Message Generation',
    mainFeature: 'GitLab Duo for merge requests',
    selectedModel: null,
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
];

export const mockIssueFeatureSettings = [
  {
    feature: 'duo_chat_summarize_comments',
    title: 'Discussion Summary',
    mainFeature: 'GitLab Duo for issues',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5',
      modelProvider: 'Anthropic',
    },
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
];

export const mockDuoAgentPlatformSettings = [
  {
    feature: 'duo_agent_platform',
    title: 'GitLab Duo Agent Platform - all agents',
    mainFeature: 'GitLab Duo Agent Platform',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5',
      modelProvider: 'Anthropic',
    },
    defaultModel: {
      ref: 'claude_sonnet_4_20250514',
      name: 'Claude Sonnet 4.0',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
];

export const mockAgenticChatFeatureSetting = {
  feature: 'duo_agent_platform_agentic_chat',
  title: 'GitLab Duo Agentic Chat',
  mainFeature: 'GitLab Duo Agent Platform',
  selectedModel: {
    ref: 'claude_3_5_sonnet_20240620',
    name: 'Claude Sonnet 3.5',
    modelProvider: 'Anthropic',
  },
  defaultModel: {
    ref: 'claude_sonnet_4_20250514',
    name: 'Claude Sonnet 4.0',
    modelProvider: 'Anthropic',
    modelDescription: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
  selectableModels,
  allowList: {
    enabled: true,
    models: {
      nodes: [
        {
          ref: 'claude_sonnet_3_7_20250219',
          name: 'Claude Sonnet 3.7',
          modelDescription: 'Fast, cost-effective responses.',
          costIndicator: '$$$',
          allowed: true,
        },
        {
          ref: 'claude_3_5_sonnet_20240620',
          name: 'Claude Sonnet 3.5',
          modelDescription: 'Fast, cost-effective responses.',
          costIndicator: '$$$',
          allowed: false,
        },
      ],
    },
  },
};

export const mockOtherDuoFeaturesSettings = [
  {
    feature: 'glab_ask_git_command',
    title: 'GitLab Duo for CLI',
    mainFeature: 'Other GitLab Duo features',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5',
      modelProvider: 'Anthropic',
    },
    defaultModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7',
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    },
    selectableModels,
    allowList: null,
  },
];

export const mockAiFeatureSettings = [
  ...mockCodeSuggestionsFeatureSettings,
  ...mockDuoChatFeatureSettings,
  ...mockMergeRequestFeatureSettings,
  ...mockIssueFeatureSettings,
  ...mockOtherDuoFeaturesSettings,
  ...mockDuoAgentPlatformSettings,
];

export const mockAiFeatureSettingsWithAgenticChat = [
  ...mockAiFeatureSettings,
  mockAgenticChatFeatureSetting,
];
