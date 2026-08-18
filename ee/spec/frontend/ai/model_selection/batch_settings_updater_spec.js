import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import updateNamespaceFeatureSettingsMutation from 'ee/ai/model_selection/graphql/update_ai_namespace_feature_settings.mutation.graphql';
import getAiNamespaceFeatureSettingsQuery from 'ee/ai/model_selection/graphql/get_ai_namepace_feature_settings.query.graphql';
import ModelSelectionBatchSettingsUpdater from 'ee/ai/model_selection/batch_settings_updater.vue';
import BatchUpdateButton from 'ee/ai/shared/feature_settings/batch_update_button.vue';

import { mockCodeSuggestionsFeatureSettings } from './mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('ModelSelectionBatchSettingsUpdater', () => {
  let wrapper;
  let mockApollo;

  const groupId = 'gid://gitlab/Group/1';
  const selectedFeatureSetting = mockCodeSuggestionsFeatureSettings[0];
  const mockToastShow = jest.fn();

  const updateNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceUpdate: {
        errors: [],
      },
    },
  });

  const getAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceSettings: {
        nodes: mockCodeSuggestionsFeatureSettings,
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [updateNamespaceFeatureSettingsMutation, updateNamespaceFeatureSettingsSuccessHandler],
      [getAiNamespaceFeatureSettingsQuery, getAiNamespaceFeatureSettingsSuccessHandler],
    ],
    props = {},
  } = {}) => {
    mockApollo = createMockApollo([...apolloHandlers]);
    wrapper = mountExtended(ModelSelectionBatchSettingsUpdater, {
      apolloProvider: mockApollo,
      propsData: {
        selectedFeatureSetting,
        aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
        ...props,
      },
      provide: { groupId },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });
  };

  const findBatchUpdateButton = () => wrapper.findComponent(BatchUpdateButton);

  it('renders `BatchUpdateButton` component', () => {
    createComponent();

    expect(findBatchUpdateButton().text()).toBe('Apply to all');
    expect(findBatchUpdateButton().props()).toEqual({
      tooltipTitle: 'Apply to all Code Suggestions sub-features',
      disabled: false,
    });
  });

  it('disables batch update button if the selected model cannot be applied for all sub-features', () => {
    const incompatibleFeatureSetting = {
      feature: 'incompatible_feature_setting',
      selectedModel: null,
      selectableModels: [
        {
          ref: 'claude_3_haiku_20240307',
          name: 'Claude Haiku 3 - Anthropic',
        },
      ],
    };

    const aiFeatureSettings = [...mockCodeSuggestionsFeatureSettings, incompatibleFeatureSetting];

    createComponent({ props: { aiFeatureSettings } });

    expect(findBatchUpdateButton().props()).toEqual({
      tooltipTitle: 'This model cannot be applied to all Code Suggestions sub-features',
      disabled: true,
    });
  });

  describe('onClick', () => {
    beforeEach(async () => {
      createComponent();

      findBatchUpdateButton().vm.$emit('batch-update');
      await waitForPromises();
    });

    it('emits update-batch-saving-state events', () => {
      expect(wrapper.emitted('update-batch-saving-state')).toHaveLength(2);
    });

    it('invokes update mutation with correct input', () => {
      const features = mockCodeSuggestionsFeatureSettings.map((fs) => fs.feature.toUpperCase());

      expect(updateNamespaceFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
        input: {
          groupId,
          features,
          offeredModelRef: selectedFeatureSetting.selectedModel.ref,
        },
      });
    });

    describe('when the update succeeds', () => {
      it('refetches namespace feature settings data', () => {
        expect(getAiNamespaceFeatureSettingsSuccessHandler).toHaveBeenCalled();
      });

      it('triggers a success toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          'Successfully updated all Code Suggestions features',
        );
      });

      it('does not HTML-escape special characters in the toast message', async () => {
        const aiFeatureSettings = mockCodeSuggestionsFeatureSettings.map((fs) => ({
          ...fs,
          mainFeature: 'Agents & flows',
        }));

        createComponent({ props: { aiFeatureSettings } });

        findBatchUpdateButton().vm.$emit('batch-update');
        await waitForPromises();

        expect(mockToastShow).toHaveBeenCalledWith(
          'Successfully updated all Agents & flows features',
        );
      });
    });

    describe('when the update does not succeed', () => {
      describe('due to a general error', () => {
        it('displays an error message', async () => {
          createComponent({
            apolloHandlers: [
              [updateNamespaceFeatureSettingsMutation, jest.fn().mockRejectedValue('ERROR')],
            ],
          });

          findBatchUpdateButton().vm.$emit('batch-update');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the Code Suggestions sub-feature settings. Please try again.',
            }),
          );
        });

        it('does not HTML-escape special characters in the error message', async () => {
          createComponent({
            apolloHandlers: [
              [updateNamespaceFeatureSettingsMutation, jest.fn().mockRejectedValue('ERROR')],
            ],
            props: {
              selectedFeatureSetting: {
                ...selectedFeatureSetting,
                mainFeature: 'Agents & flows',
              },
            },
          });

          findBatchUpdateButton().vm.$emit('batch-update');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the Agents & flows sub-feature settings. Please try again.',
            }),
          );
        });
      });

      describe('due to a business logic error', () => {
        const updateNamespaceFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
          data: {
            aiModelSelectionNamespaceUpdate: {
              aiFeatureSettings: null,
              errors: ['An error occured'],
            },
          },
        });

        it('displays an error message', async () => {
          createComponent({
            apolloHandlers: [
              [updateNamespaceFeatureSettingsMutation, updateNamespaceFeatureSettingsErrorHandler],
            ],
          });

          findBatchUpdateButton().vm.$emit('batch-update');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the Code Suggestions sub-feature settings. Please try again.',
            }),
          );
        });
      });
    });
  });
});
