import { getStorageValue, saveStorageValue, removeStorageValue } from '~/lib/utils/local_storage';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY } from 'ee/ai/constants';
import {
  getModel,
  getDefaultModel,
  getSavedModel,
  getCurrentModel,
  saveModel,
  clearSavedModel,
  isModelSelectionDisabled,
} from 'ee/ai/duo_agentic_chat/utils/model_selection_utils';

jest.mock('~/lib/utils/local_storage', () => ({
  getStorageValue: jest.fn(),
  saveStorageValue: jest.fn(),
  removeStorageValue: jest.fn(),
}));

describe('model_selection_utils', () => {
  const MOCK_AVAILABLE_MODELS = [
    { text: 'Claude Sonnet 4.0', value: GITLAB_DEFAULT_MODEL },
    { text: 'Claude 3.5 Sonnet', value: 'anthropic/claude-3.5-sonnet' },
    { text: 'GPT-4', value: 'openai/gpt-4' },
  ];

  const MOCK_DEFAULT_MODEL = MOCK_AVAILABLE_MODELS[0];
  const MOCK_CUSTOM_MODEL = MOCK_AVAILABLE_MODELS[1];

  afterEach(() => {
    jest.resetAllMocks();
  });

  describe('getModel', () => {
    it('returns the model with matching value', () => {
      const result = getModel(MOCK_AVAILABLE_MODELS, 'anthropic/claude-3.5-sonnet');

      expect(result).toEqual(MOCK_CUSTOM_MODEL);
    });
  });

  describe('getDefaultModel', () => {
    it('returns the model with GITLAB_DEFAULT_MODEL value', () => {
      const result = getDefaultModel(MOCK_AVAILABLE_MODELS);

      expect(result).toEqual(MOCK_DEFAULT_MODEL);
    });
  });

  describe('getSavedModel', () => {
    describe('when saved model exists in available models', () => {
      it('returns the saved model', () => {
        getStorageValue.mockReturnValueOnce({
          exists: true,
          value: MOCK_CUSTOM_MODEL,
        });

        const result = getSavedModel(MOCK_AVAILABLE_MODELS);

        expect(result).toEqual(MOCK_CUSTOM_MODEL);
      });
    });

    describe('when saved model is not in available models', () => {
      it('returns null and clears localStorage', () => {
        const deletedModel = { text: 'Deleted Model', value: 'deleted/model' };
        getStorageValue.mockReturnValueOnce({
          exists: true,
          value: deletedModel,
        });

        const result = getSavedModel(MOCK_AVAILABLE_MODELS);

        expect(result).toBeNull();
        expect(removeStorageValue).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY);
      });
    });

    describe('when localStorage is empty', () => {
      it('returns null', () => {
        const result = getSavedModel(MOCK_AVAILABLE_MODELS);

        expect(result).toBeNull();
      });
    });
  });

  describe('getCurrentModel', () => {
    describe('when pinnedModel is available', () => {
      it('returns pinnedModel', () => {
        const pinnedModel = { text: 'Pinned Model', value: 'pinned/model' };
        getStorageValue.mockReturnValueOnce({
          exists: true,
          value: MOCK_CUSTOM_MODEL,
        });

        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel,
          selectedModel: MOCK_CUSTOM_MODEL,
        });

        expect(result).toEqual(pinnedModel);
      });
    });

    describe('when no pinnedModel', () => {
      it('returns selectedModel', () => {
        getStorageValue.mockReturnValueOnce({
          exists: true,
          value: MOCK_CUSTOM_MODEL,
        });

        const selectedModel = MOCK_AVAILABLE_MODELS[2];
        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel,
        });

        expect(result).toEqual(selectedModel);
      });
    });

    describe('when no pinnedModel or selectedModel', () => {
      it('returns saved model from localStorage', () => {
        getStorageValue.mockReturnValueOnce({
          exists: true,
          value: MOCK_CUSTOM_MODEL,
        });

        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel: null,
        });

        expect(result).toEqual(MOCK_CUSTOM_MODEL);
      });
    });

    describe('when no other options available', () => {
      it('returns default model', () => {
        getStorageValue.mockReturnValueOnce({ exists: false });

        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel: null,
        });

        expect(result).toEqual(MOCK_DEFAULT_MODEL);
      });
    });
  });

  describe('saveModel', () => {
    describe('when successful', () => {
      it('saves the model to localStorage and returns true', () => {
        const result = saveModel(MOCK_CUSTOM_MODEL);

        expect(result).toBe(true);
        expect(saveStorageValue).toHaveBeenCalledWith(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          MOCK_CUSTOM_MODEL,
        );
      });
    });

    describe('when saveStorageValue throws an error', () => {
      it('returns false', () => {
        saveStorageValue.mockImplementation(() => {
          throw new Error('QuotaExceededError');
        });

        const result = saveModel(MOCK_CUSTOM_MODEL);

        expect(result).toBe(false);
      });
    });
  });

  describe('clearSavedModel', () => {
    describe('when successful', () => {
      it('removes the model from localStorage and returns true', () => {
        getStorageValue.mockReturnValueOnce({
          exists: true,
          value: MOCK_CUSTOM_MODEL,
        });

        const result = clearSavedModel();

        expect(result).toBe(true);
        expect(removeStorageValue).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY);
      });
    });

    describe('when removeStorageValue throws an error', () => {
      it('returns false', () => {
        removeStorageValue.mockImplementation(() => {
          throw new Error('Storage error');
        });

        const result = clearSavedModel();

        expect(result).toBe(false);
      });
    });
  });

  describe('isModelSelectionDisabled', () => {
    describe('when pinnedModel is provided', () => {
      it('returns true', () => {
        const pinnedModel = { text: 'Pinned Model', value: 'pinned/model' };

        const result = isModelSelectionDisabled(pinnedModel);

        expect(result).toBe(true);
      });
    });

    describe('when pinnedModel is not provided', () => {
      it('returns false', () => {
        const result = isModelSelectionDisabled(undefined);

        expect(result).toBe(false);
      });
    });
  });
});
