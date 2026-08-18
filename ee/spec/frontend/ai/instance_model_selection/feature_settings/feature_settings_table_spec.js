import { nextTick } from 'vue';
import { GlExperimentBadge } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/ai/instance_model_selection/feature_settings/components/feature_settings_table.vue';
import BaseFeatureSettingsTable from 'ee/ai/shared/feature_settings/base_feature_settings_table.vue';
import ModelAllowListSelector from 'ee/ai/instance_model_selection/feature_settings/components/model_allow_list_selector.vue';
import AvailableModelsRow from 'ee/ai/shared/feature_settings/available_models_row.vue';
import DuoSelfHostedBatchSettingsUpdater from 'ee/ai/instance_model_selection/feature_settings/components/batch_settings_updater.vue';
import ModelSelector from 'ee/ai/instance_model_selection/feature_settings/components/model_selector.vue';

import {
  mockCodeSuggestionsFeatureSettings,
  mockAgenticChatFeatureSetting,
  mockAiFeatureSettings,
  mockDefaultGitlabModel,
} from './mock_data';

describe('FeatureSettingsTable', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    wrapper = mountExtended(FeatureSettingsTable, {
      provide: {
        canManageSelfHostedModels: false,
        canManageDapSelfHostedModels: false,
        ...provide,
      },
      propsData: {
        featureSettings: mockCodeSuggestionsFeatureSettings,
        isLoading: false,
        ...props,
      },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(FeatureSettingsTable);
  const findBaseTable = () => wrapper.findComponent(BaseFeatureSettingsTable);
  const findTableRows = () => findFeatureSettingsTable().findAllComponents('tbody > tr');
  const findTableHeaders = () => findFeatureSettingsTable().findAllComponents('thead > tr');
  const findRowFeatureNameByIdx = (idx) => findTableRows().at(idx).findAll('td').at(0);
  const findModelSelectorByIdx = (idx) => findTableRows().at(idx).findComponent(ModelSelector);
  const findModelBatchSettingsUpdaterByIdx = (idx) =>
    findTableRows().at(idx).findComponent(DuoSelfHostedBatchSettingsUpdater);
  const findBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findConfigureButton = () => wrapper.findByTestId('configure-button');
  const findAvailableModelsRow = () => wrapper.findComponent(AvailableModelsRow);
  const findModelAllowListSelector = () => wrapper.findComponent(ModelAllowListSelector);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  describe('column headers', () => {
    describe('when `showAvailableModelsField` is false', () => {
      it('renders the default column headers', () => {
        createComponent();
        const headers = findTableHeaders().at(0).findAll('th');

        expect(headers.at(0).text()).toEqual('Feature');
        expect(headers.at(1).text()).toEqual('Model');
        expect(headers.at(2).text()).toEqual('Apply to all sub-features');
      });
    });

    describe('when `showAvailableModelsField` is true', () => {
      it('renders the allow-list column headers', () => {
        createComponent({ showAvailableModelsField: true });
        const headers = findTableHeaders().at(0).findAll('th');

        expect(headers.at(0).text()).toEqual('Feature');
        expect(headers.at(1).text()).toEqual('Default model');
        expect(headers.at(2).text()).toEqual('Available models');
      });
    });
  });

  describe('rows', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders row data for each feature setting', () => {
      expect(findTableRows()).toHaveLength(mockCodeSuggestionsFeatureSettings.length);
    });

    it('renders the feature name', () => {
      expect(findRowFeatureNameByIdx(0).text()).toBe('Code Generation');
      expect(findRowFeatureNameByIdx(1).text()).toBe('Code Completion');
    });

    describe('beta/experiment badges', () => {
      it('renders the beta badge for beta features', () => {
        const betaFeature = mockAiFeatureSettings[4];
        createComponent({ featureSettings: [betaFeature] });

        expect(findBadge().props('type')).toBe('beta');
      });

      it('renders the experiment badge for experiment features', () => {
        const experimentFeature = mockAiFeatureSettings[2];
        createComponent({ featureSettings: [experimentFeature] });

        expect(findBadge().props('type')).toBe('experiment');
      });

      it('does not render the badges for non-beta or non-experimental features', () => {
        createComponent();

        expect(findBadge().exists()).toBe(false);
      });
    });

    it('renders the model selector and passes the correct props', () => {
      [0, 1].forEach((idx) => {
        expect(findModelSelectorByIdx(idx).props()).toEqual({
          aiFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
          batchUpdateIsSaving: false,
          hasMixedSources: false,
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

      it('does not render the batch settings updater when `showAvailableModelsField` is true', () => {
        createComponent({ showAvailableModelsField: true });

        expect(findModelBatchSettingsUpdaterByIdx(0).exists()).toBe(false);
      });

      it('handles update-batch-saving-state event correctly', async () => {
        findModelBatchSettingsUpdaterByIdx(0).vm.$emit('update-batch-saving-state', true);
        await nextTick();

        expect(findModelSelectorByIdx(0).props('batchUpdateIsSaving')).toBe(true);
      });
    });

    describe('available models field', () => {
      describe('when `showAvailableModelsField` is false', () => {
        it('does not render the available models column header, `Configure` button or selector', () => {
          const tableFields = findBaseTable().props('fields');

          expect(tableFields.map((f) => f.key)).not.toContain('available_models');
          expect(findConfigureButton().exists()).toBe(false);
          expect(findModelAllowListSelector().exists()).toBe(false);
        });
      });

      describe('when `showAvailableModelsField` is true', () => {
        const createWithFeature = (overrides = {}) =>
          createComponent({
            featureSettings: [{ ...mockAgenticChatFeatureSetting, ...overrides }],
            showAvailableModelsField: true,
          });

        it('renders the available models column header, `Configure` button and selector', () => {
          createWithFeature();
          const tableFields = findBaseTable().props('fields');

          expect(tableFields.map((f) => f.key)).toContain('available_models');
          expect(findConfigureButton().text()).toBe('Configure');
          expect(findModelAllowListSelector().exists()).toBe(true);
        });

        it('hides the allow-list modal by default', () => {
          createWithFeature();

          expect(findModelAllowListSelector().props('visible')).toBe(false);
        });

        it('hides the allow-list modal when selector emits `update:visible` with false', async () => {
          createWithFeature();

          await findConfigureButton().trigger('click');
          expect(findModelAllowListSelector().props('visible')).toBe(true);

          findModelAllowListSelector().vm.$emit('update:visible', false);
          await nextTick();

          expect(findModelAllowListSelector().props('visible')).toBe(false);
        });

        it('does not render the batch settings updater', () => {
          createWithFeature();

          expect(findModelBatchSettingsUpdaterByIdx(0).exists()).toBe(false);
        });

        describe('available models row', () => {
          it('passes the feature `allowList` to the row', () => {
            createWithFeature();

            expect(findAvailableModelsRow().props('allowList')).toEqual(
              mockAgenticChatFeatureSetting.allowList,
            );
          });

          describe('when `Configure` button is clicked', () => {
            beforeEach(async () => {
              createWithFeature();

              await findConfigureButton().trigger('click');
            });

            it('passes the correct props to the allow-list selector', () => {
              expect(findModelAllowListSelector().props('visible')).toBe(true);
              expect(findModelAllowListSelector().props('aiFeatureSetting')).toEqual(
                mockAgenticChatFeatureSetting,
              );
            });
          });

          describe('`disabled` state', () => {
            it.each`
              scenario                                            | overrides                                                                 | expected
              ${'a GitLab-managed (vendored) model is selected'}  | ${{ provider: 'vendored' }}                                               | ${false}
              ${'provider is unassigned with a default model'}    | ${{ provider: 'unassigned', defaultGitlabModel: mockDefaultGitlabModel }} | ${false}
              ${'a self-hosted model is selected'}                | ${{ provider: 'self_hosted' }}                                            | ${true}
              ${'provider is disabled'}                           | ${{ provider: 'disabled' }}                                               | ${true}
              ${'provider is unassigned without a default model'} | ${{ provider: 'unassigned', defaultGitlabModel: null }}                   | ${true}
              ${'the feature has no allow-list'}                  | ${{ provider: 'vendored', allowList: null }}                              | ${true}
            `('passes `disabled` as $expected when $scenario', ({ overrides, expected }) => {
              createWithFeature(overrides);

              expect(findAvailableModelsRow().props('disabled')).toBe(expected);
            });

            it('is disabled while the feature is saving, even when the provider would normally enable it', async () => {
              createWithFeature({ provider: 'vendored' });

              expect(findAvailableModelsRow().props('disabled')).toBe(false);

              findModelSelectorByIdx(0).vm.$emit('update:is-saving', true);
              await nextTick();

              expect(findAvailableModelsRow().props('disabled')).toBe(true);
            });

            it('re-enables after saving completes when the provider still allows it', async () => {
              createWithFeature({ provider: 'vendored' });

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
              createWithFeature({ provider: 'vendored' });

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
                createWithFeature();

                findModelSelectorByIdx(0).vm.$emit('update:is-saving', isSaving);
                await nextTick();

                expect(findAvailableModelsRow().props('isLoading')).toBe(isSaving);
              },
            );
          });
        });
      });
    });
  });
});
