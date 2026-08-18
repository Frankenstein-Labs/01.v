import { __, sprintf } from '~/locale';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';

export const formatDefaultModelData = (defaultModel) => {
  const { name, modelProvider, modelDescription, costIndicator } = defaultModel;

  const formattedModelText = sprintf(__('%{modelName} - Default'), { modelName: name }) || '';

  return {
    text: formattedModelText,
    value: GITLAB_DEFAULT_MODEL,
    provider: modelProvider,
    description: modelDescription,
    costIndicator,
  };
};
