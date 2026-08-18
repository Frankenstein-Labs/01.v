import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import updateAiFeatureSettings from 'ee/ai/instance_model_selection/feature_settings/graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/ai/instance_model_selection/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import DuoSelfHostedBatchSettingsUpdater from 'ee/ai/instance_model_selection/feature_settings/components/batch_settings_updater.vue';
import BatchUpdateButton from 'ee/ai/shared/feature_settings/batch_update_button.vue';
import { mockDuoChatFeatureSettings, mockGitlabManagedModels } from './mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('DuoSelfHostedBatchSettingsUpdater', () => {
  let wrapper;
  let mockApollo;

  const selectedFeatureSetting = mockDuoChatFeatureSettings[0];
  const mockToastShow = jest.fn();

  const updateFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettingUpdate: {
        errors: [],
      },
    },
  });

  const getFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: mockDuoChatFeatureSettings,
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [updateAiFeatureSettings, updateFeatureSettingsSuccessHandler],
      [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
    ],
    props = {},
  } = {}) => {
    mockApollo = createMockApollo([...apolloHandlers]);
    wrapper = mountExtended(DuoSelfHostedBatchSettingsUpdater, {
      apolloProvider: mockApollo,
      propsData: {
        selectedFeatureSetting,
        aiFeatureSettings: mockDuoChatFeatureSettings,
        ...props,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });
  };

  const findBatchUpdateButton = () => wrapper.findComponent(BatchUpdateButton);
  const findUnassignedFeatureIcon = () => wrapper.findByTestId('warning-icon');
  const findUnassignedFeatureTooltip = () => wrapper.findByTestId('unassigned-feature-tooltip');

  it('renders `BatchUpdateButton` component', () => {
    createComponent();

    expect(findBatchUpdateButton().text()).toBe('Apply to all');
    expect(findBatchUpdateButton().props()).toEqual({
      tooltipTitle: 'Apply to all GitLab Duo Chat sub-features',
      disabled: false,
    });
  });

  describe('with GitLab managed models', () => {
    beforeEach(() => {
      const unassignedFeatureSetting = {
        feature: 'duo_chat',
        title: 'General Chat',
        provider: 'unassigned',
        validGitlabModels: { nodes: mockGitlabManagedModels },
      };

      createComponent({ props: { selectedFeatureSetting: unassignedFeatureSetting } });
    });

    it('does not show batch update button', () => {
      expect(findBatchUpdateButton().exists()).toBe(false);
    });

    it('does not show warning tooltip and icon', () => {
      expect(findUnassignedFeatureIcon().exists()).toBe(false);
      expect(findUnassignedFeatureTooltip().exists()).toBe(false);
    });
  });

  describe('when the selected feature setting is unassigned', () => {
    beforeEach(() => {
      const unassignedFeatureSetting = {
        feature: 'duo_chat',
        title: 'General Chat',
        provider: 'unassigned',
      };

      createComponent({ props: { selectedFeatureSetting: unassignedFeatureSetting } });
    });

    it('disables the batch update button', () => {
      expect(findBatchUpdateButton().props()).toEqual({
        tooltipTitle: 'Assign a model to General Chat before applying to all',
        disabled: true,
      });
    });

    it('renders a warning tooltip and icon', () => {
      expect(findUnassignedFeatureIcon().exists()).toBe(true);
      expect(findUnassignedFeatureTooltip().attributes('title')).toBe(
        'Assign a model to enable this feature',
      );
    });
  });

  it('disables batch update button if selected model is not compatible with all feature settings', () => {
    const incompatibleModel = { id: 'gid://gitlab/Ai::SelfHostedModel/999' };
    const featureSetting = {
      feature: 'duo_chat',
      title: 'General Chat',
      mainFeature: 'GitLab Duo Chat',
      provider: 'self_hosted',
      selfHostedModel: incompatibleModel,
    };

    createComponent({ props: { selectedFeatureSetting: featureSetting } });

    expect(findBatchUpdateButton().props()).toEqual({
      tooltipTitle: 'This model cannot be applied to all GitLab Duo Chat sub-features',
      disabled: true,
    });
  });

  it('disables batch update button if selected feature setting is disabled', () => {
    const disabledFeatureSetting = {
      feature: 'duo_chat',
      title: 'General Chat',
      provider: 'disabled',
    };

    createComponent({ props: { selectedFeatureSetting: disabledFeatureSetting } });

    expect(findBatchUpdateButton().props()).toEqual({
      tooltipTitle: 'Assign a model to General Chat before applying to all',
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
      const features = mockDuoChatFeatureSettings.map((fs) => fs.feature.toUpperCase());

      expect(updateFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
        input: {
          features,
          provider: 'SELF_HOSTED',
          aiSelfHostedModelId: 'gid://gitlab/Ai::SelfHostedModel/1',
        },
      });
    });

    describe('when the update succeeds', () => {
      it('refetches feature settings data', () => {
        expect(getFeatureSettingsSuccessHandler).toHaveBeenCalled();
      });

      it('triggers a success toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          'Successfully updated all GitLab Duo Chat features',
        );
      });

      it('does not HTML-escape special characters in the toast message', async () => {
        createComponent({
          props: {
            selectedFeatureSetting: {
              ...selectedFeatureSetting,
              mainFeature: 'Agents & flows',
            },
          },
        });

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
              [updateAiFeatureSettings, jest.fn().mockRejectedValue('ERROR')],
              [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
            ],
          });

          findBatchUpdateButton().vm.$emit('batch-update');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the GitLab Duo Chat sub-feature settings. Please try again.',
            }),
          );
        });

        it('does not HTML-escape special characters in the error message', async () => {
          createComponent({
            apolloHandlers: [
              [updateAiFeatureSettings, jest.fn().mockRejectedValue('ERROR')],
              [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
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
        const updateFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
          data: {
            aiFeatureSettingUpdate: {
              errors: ['An error occured'],
            },
          },
        });

        it('displays an error message', async () => {
          createComponent({
            apolloHandlers: [
              [updateAiFeatureSettings, updateFeatureSettingsErrorHandler],
              [getAiFeatureSettingsQuery, getFeatureSettingsSuccessHandler],
            ],
          });

          findBatchUpdateButton().vm.$emit('batch-update');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message:
                'An error occurred while updating the GitLab Duo Chat sub-feature settings. Please try again.',
            }),
          );
        });
      });
    });
  });
});
