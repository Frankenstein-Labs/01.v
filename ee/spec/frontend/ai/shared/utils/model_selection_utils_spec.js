import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { formatDefaultModelData } from 'ee/ai/shared/utils/model_selection_utils';

describe('formatDefaultModelData', () => {
  it('returns formatted default model data', () => {
    const defaultModelData = {
      name: 'Claude Sonnet 4.5',
      ref: GITLAB_DEFAULT_MODEL,
      modelProvider: 'Anthropic',
      modelDescription: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    };

    expect(formatDefaultModelData(defaultModelData)).toEqual({
      text: 'Claude Sonnet 4.5 - Default',
      value: GITLAB_DEFAULT_MODEL,
      provider: 'Anthropic',
      description: 'Fast, cost-effective responses.',
      costIndicator: '$$$',
    });
  });
});
