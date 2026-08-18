import { getStorageValue, saveStorageValue, removeStorageValue } from '~/lib/utils/local_storage';

import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY } from 'ee/ai/constants';

export const getModel = (availableModels, modelValue) => {
  return availableModels?.find((item) => item.value === modelValue);
};

export const getDefaultModel = (availableModels) => {
  return getModel(availableModels, GITLAB_DEFAULT_MODEL);
};

export const clearSavedModel = () => {
  try {
    removeStorageValue(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY);
    return true;
  } catch (error) {
    return false;
  }
};

export const getSavedModel = (availableModels) => {
  try {
    const savedModel = getStorageValue(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY)?.value;

    // Validate that the saved model still exists
    if (!getModel(availableModels, savedModel?.value)) {
      clearSavedModel();
      return null;
    }

    return savedModel;
  } catch {
    return null;
  }
};

export const getCurrentModel = ({ availableModels, pinnedModel, selectedModel }) => {
  return (
    pinnedModel ||
    selectedModel ||
    getSavedModel(availableModels) ||
    getDefaultModel(availableModels)
  );
};

export const saveModel = (model) => {
  try {
    saveStorageValue(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY, model);
    return true;
  } catch (error) {
    return false;
  }
};

export const isModelSelectionDisabled = (pinnedModel) => {
  return Boolean(pinnedModel);
};
