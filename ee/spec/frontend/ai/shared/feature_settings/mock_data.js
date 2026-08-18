export const featureSettings = [
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
  },
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
  },
];

export const mockGroupedModelItems = [
  {
    text: 'Self-hosted models',
    options: [
      { value: 'model-1', text: 'Mistral 7B' },
      { value: 'model-2', text: 'Claude Instant' },
    ],
  },
  {
    text: 'GitLab managed models',
    options: [
      { value: 'model-3', text: 'Claude Sonnet 3.5' },
      { value: 'model-4', text: 'GPT-4o' },
    ],
  },
];
