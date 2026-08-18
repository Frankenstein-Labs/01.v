import {
  BEDROCK_DUMMY_ENDPOINT,
  VERTEX_DUMMY_ENDPOINT,
} from 'ee/ai/instance_model_selection/self_hosted_models/constants';

export const mockListItems = [
  { value: 'CLAUDE_3', text: 'Claude', releaseState: 'GA' },
  { value: 'CODELLAMA', text: 'Code Llama', releaseState: 'BETA' },
  { value: 'CODEGEMMA', text: 'CodeGemma', releaseState: 'BETA' },
  { value: 'DEEPSEEKCODER', text: 'DeepSeek Coder', releaseState: 'BETA' },
  { value: 'GPT', text: 'GPT', releaseState: 'GA' },
];

export const mockSelfHostedModel = {
  id: 'gid://gitlab/Ai::SelfHostedModel/1',
  name: 'mock-self-hosted-model',
  model: 'mistral',
  modelDisplayName: 'Mistral',
  provider: 'API',
  endpoint: 'https://mock-endpoint.com',
  identifier: 'provider/some-model-1',
  apiToken: 'mock-api-token-123',
  featureSettings: {
    nodes: [],
  },
};

export const mockBedrockSelfHostedModel = {
  id: 'gid://gitlab/Ai::SelfHostedModel/1',
  name: 'mock-bedrock-model',
  model: 'mistral',
  modelDisplayName: 'Mistral',
  provider: 'BEDROCK',
  endpoint: BEDROCK_DUMMY_ENDPOINT,
  identifier: 'bedrock/some-model-1',
  apiToken: '',
  featureSettings: {
    nodes: [],
  },
};

export const mockVertexAiSelfHostedModel = {
  id: 'gid://gitlab/Ai::SelfHostedModel/1',
  name: 'mock-vertex-model',
  model: 'mistral',
  modelDisplayName: 'Mistral',
  provider: 'VERTEX_AI',
  endpoint: VERTEX_DUMMY_ENDPOINT,
  identifier: 'vertex_ai/some-model-1',
  apiToken: '',
  featureSettings: {
    nodes: [],
  },
};

export const mockSelfHostedModelsList = [
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/1',
    name: 'mock-self-hosted-model-1',
    model: 'codellama',
    modelDisplayName: 'Code Llama',
    endpoint: 'https://mock-endpoint-1.com',
    identifier: 'provider/some-model-1',
    hasApiToken: true,
    releaseState: 'BETA',
    featureSettings: {
      nodes: [
        {
          title: 'Code Completion',
          feature: 'code_completions',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/2',
    name: 'mock-self-hosted-model-2',
    model: 'mistral',
    modelDisplayName: 'Mistral',
    endpoint: 'https://mock-endpoint-2.com',
    identifier: 'provider/some-model-2',
    hasApiToken: true,
    releaseState: 'GA',
    featureSettings: {
      nodes: [],
    },
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/3',
    name: 'mock-bedrock-self-hosted-model',
    model: 'mistral',
    modelDisplayName: 'Mistral',
    endpoint: BEDROCK_DUMMY_ENDPOINT,
    identifier: 'bedrock/example-model',
    hasApiToken: false,
    releaseState: 'GA',
    featureSettings: {
      nodes: [],
    },
  },
];

export const mockModelConnectionTestInput = {
  name: 'mock-self-hosted-model-1',
  model: 'MISTRAL',
  endpoint: 'https://mock-endpoint.com',
  identifier: '',
  apiToken: 'mock-api-token-123',
};

export const SELF_HOSTED_MODEL_OPTIONS = [
  { modelValue: 'CODEGEMMA', modelName: 'CodeGemma', releaseState: 'BETA' },
  { modelValue: 'CODELLAMA', modelName: 'Code-Llama', releaseState: 'BETA' },
  { modelValue: 'CODESTRAL', modelName: 'Codestral', releaseState: 'GA' },
  { modelValue: 'MISTRAL', modelName: 'Mistral', releaseState: 'GA' },
  { modelValue: 'DEEPSEEKCODER', modelName: 'Deepseek Coder', releaseState: 'BETA' },
  { modelValue: 'LLAMA3', modelName: 'Llama 3', releaseState: 'BETA' },
  { modelValue: 'GPT', modelName: 'GPT', releaseState: 'GA' },
  { modelValue: 'CLAUDE_3', modelName: 'Claude', releaseState: 'GA' },
];
