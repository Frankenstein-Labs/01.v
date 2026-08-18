import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ModelSelectionFeatureSettingsTable from 'ee/ai/model_selection/feature_settings_table.vue';
import ModelAllowListSelector from 'ee/ai/model_selection/model_allow_list_selector.vue';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectionBatchSettingsUpdater from 'ee/ai/model_selection/batch_settings_updater.vue';
import AvailableModelsRow from 'ee/ai/shared/feature_settings/available_models_row.vue';

import { mockCodeSuggestionsFeatureSettings, mockAgenticChatFeatureSetting } from './mock_data';

describe('ModelSelectionFeatureSettingsTable', () => {
  let wrapper;
  const groupId = 'gid://gitlab/Group/1';

  const createComponent = (props = {}) => {
    wrapper = mountExtended(ModelSelectionFeatureSettingsTable, {
      propsData: {
        featureSettings: mockCodeSuggestionsFeatureSettings,
        isLoading: false,
        ...props,
      },
      provide: {
        groupId,
      },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(ModelSelectionFeatureSettingsTable);
  const findTableRows = () => findFeatureSettingsTable().findAllComponents('tbody > tr');
  const findTableHeaders = () => findFeatureSettingsTable().findAllComponents('thead > tr');
  const findRowFeatureNameByIdx = (idx) => findTableRows().at(idx).findAll('td').at(0);
  const findModelSelectorByIdx = (idx) => findTableRows().at(idx).findComponent(ModelSelector);
  const findModelBatchSettingsUpdaterByIdx = (idx) =>
    findTableRows().at(idx).findComponent(ModelSelectionBatchSettingsUpdater);
  const findAvailableModelsRow = () => wrapper.findComponent(AvailableModelsRow);
  const findModelAllowListSelector = () => wrapper.findComponent(ModelAllowListSelector);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  describe('rows', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders column headers', () => {
      const headerTexts = findTableHeaders()
        .at(0)
        .findAll('th')
        .wrappers.map((h) => h.text());

      expect(headerTexts).toEqual(['Feature', 'Model', 'Apply to all sub-features']);
    });

    it('renders row data for each feature setting', () => {
      expect(findTableRows()).toHaveLength(mockCodeSuggestionsFeatureSettings.length);
    });

    it('renders the feature name', () => {
      expect(findRowFeatureNameByIdx(0).text()).toBe('Code Completion');
      expect(findRowFeatureNameByIdx(1).text()).toBe('Code Generation');
    });

    it('renders the model select dropdown and passes the correct props', () => {
      [0, 1].forEach((idx) => {
        expect(findModelSelectorByIdx(idx).props()).toEqual({
          aiFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
          batchUpdateIsSaving: false,
        });
      });
    });

    describe('model batch settings updater', () => {
      it('renders the model batch settings updater', () => {
        [0, 1].forEach((idx) => {
          expect(findModelBatchSettingsUpdaterByIdx(idx).props()).toEqual({
            selectedFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
            aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
          });
        });
      });

      it('does not render the batch settings updater when there is a single feature', () => {
        const featureSetting = mockCodeSuggestionsFeatureSettings[0];

        createComponent({ featureSettings: [featureSetting] });

        expect(findModelBatchSettingsUpdaterByIdx(0).exists()).toBe(false);
      });

      it('handles update-batch-saving-state event correctly', () => {
        findModelBatchSettingsUpdaterByIdx(0).vm.$emit('update-batch-saving-state', true);

        expect(wrapper.vm.batchUpdateIsSaving).toBe(true);
      });
    });
  });

  describe('available models field', () => {
    describe('when `showAvailableModelsField` is false (default)', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the batch update column', () => {
        const headers = findTableHeaders().at(0).findAll('th');

        expect(headers.at(2).text()).toEqual('Apply to all sub-features');
      });

      it('does not render the available models column, configure button or selector', () => {
        const headers = findTableHeaders().at(0).findAll('th');

        expect(headers.wrappers.map((h) => h.text())).not.toContain('Available models');
        expect(findAvailableModelsRow().exists()).toBe(false);
        expect(findModelAllowListSelector().exists()).toBe(false);
      });
    });

    describe('when `showAvailableModelsField` is true', () => {
      beforeEach(() => {
        createComponent({
          showAvailableModelsField: true,
          featureSettings: [mockAgenticChatFeatureSetting],
        });
      });

      it('renders the available models column and relabels the model column', () => {
        const headerTexts = findTableHeaders()
          .at(0)
          .findAll('th')
          .wrappers.map((h) => h.text());

        expect(headerTexts).toEqual(['Feature', 'Default model', 'Available models']);
      });

      describe('available models row', () => {
        it('renders the configure button', () => {
          expect(findAvailableModelsRow().exists()).toBe(true);
        });

        it('passes the feature `allowList` to the row', () => {
          expect(findAvailableModelsRow().props('allowList')).toEqual(
            mockAgenticChatFeatureSetting.allowList,
          );
        });

        describe('`disabled` state', () => {
          it('is not disabled when the feature has an allow-list', () => {
            expect(findAvailableModelsRow().props('disabled')).toBe(false);
          });

          it('is disabled when the feature has no allow-list', () => {
            createComponent({
              showAvailableModelsField: true,
              featureSettings: [{ ...mockAgenticChatFeatureSetting, allowList: null }],
            });

            expect(findAvailableModelsRow().props('disabled')).toBe(true);
          });

          it('is disabled while the feature is saving, even when the feature has an allow-list', async () => {
            expect(findAvailableModelsRow().props('disabled')).toBe(false);

            findModelSelectorByIdx(0).vm.$emit('update:is-saving', true);
            await nextTick();

            expect(findAvailableModelsRow().props('disabled')).toBe(true);
          });

          it('re-enables after saving completes when the feature still has an allow-list', async () => {
            findModelSelectorByIdx(0).vm.$emit('update:is-saving', true);
            await nextTick();
            expect(findAvailableModelsRow().props('disabled')).toBe(true);

            findModelSelectorByIdx(0).vm.$emit('update:is-saving', false);
            await nextTick();
            expect(findAvailableModelsRow().props('disabled')).toBe(false);
          });
        });

        describe('showModal guard', () => {
          it('does not open the modal while the feature is saving', async () => {
            findModelSelectorByIdx(0).vm.$emit('update:is-saving', true);
            await nextTick();

            await findAvailableModelsRow().vm.$emit('click');

            expect(findModelAllowListSelector().props('visible')).toBe(false);
          });
        });

        describe('`isLoading` state', () => {
          it.each([false, true])(
            'passes `isLoading` as %s when isSaving is %s',
            async (isSaving) => {
              findModelSelectorByIdx(0).vm.$emit('update:is-saving', isSaving);
              await nextTick();

              expect(findAvailableModelsRow().props('isLoading')).toBe(isSaving);
            },
          );
        });

        it('renders the ModelAllowListSelector with the active feature setting when configure is clicked', async () => {
          expect(findModelAllowListSelector().props()).toMatchObject({
            aiFeatureSetting: null,
            visible: false,
          });

          await findAvailableModelsRow().vm.$emit('click');

          expect(findModelAllowListSelector().props()).toMatchObject({
            aiFeatureSetting: mockAgenticChatFeatureSetting,
            visible: true,
          });
        });

        it('updates `isAllowlistModalVisible` when the selector emits `update:visible`', async () => {
          await findAvailableModelsRow().vm.$emit('click');

          expect(findModelAllowListSelector().props('visible')).toBe(true);

          findModelAllowListSelector().vm.$emit('update:visible', false);
          await nextTick();

          expect(findModelAllowListSelector().props('visible')).toBe(false);
        });
      });
    });
  });
});
