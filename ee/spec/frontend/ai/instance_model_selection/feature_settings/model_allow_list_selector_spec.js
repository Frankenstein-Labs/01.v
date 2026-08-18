import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ModelAllowListSelector from 'ee/ai/instance_model_selection/feature_settings/components/model_allow_list_selector.vue';
import AvailableModelsModal from 'ee/ai/shared/feature_settings/available_models_modal.vue';
import updateModelAllowlist from 'ee/ai/instance_model_selection/feature_settings/graphql/mutations/update_model_allowlist.mutation.graphql';
import getAiFeatureSettingsQuery from 'ee/ai/instance_model_selection/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import { mockAgenticChatFeatureSetting } from './mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

describe('ModelAllowListSelector', () => {
  let wrapper;

  const mockSavePayload = { enabled: true, allowedModelRefs: ['claude_sonnet_4_20250514'] };

  const updateSuccessHandler = jest.fn().mockResolvedValue({
    data: { aiFeatureSettingModelAllowlistUpdate: { errors: [] } },
  });
  const getAiFeatureSettingsHandler = jest.fn().mockResolvedValue({
    data: { aiFeatureSettings: { nodes: [] } },
  });

  const mockToastShow = jest.fn();

  const createComponent = ({ props = {}, updateHandler = updateSuccessHandler } = {}) => {
    const mockApollo = createMockApollo([
      [updateModelAllowlist, updateHandler],
      [getAiFeatureSettingsQuery, getAiFeatureSettingsHandler],
    ]);

    wrapper = shallowMountExtended(ModelAllowListSelector, {
      apolloProvider: mockApollo,
      propsData: {
        aiFeatureSetting: mockAgenticChatFeatureSetting,
        visible: true,
        ...props,
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });
  };

  const findModal = () => wrapper.findComponent(AvailableModelsModal);
  const save = (payload = mockSavePayload) => findModal().vm.$emit('save', payload);

  beforeEach(() => {
    createComponent();
  });

  it('renders AvailableModelsModal with the allow-list as its source of truth', () => {
    expect(findModal().props()).toEqual({
      availableModels: mockAgenticChatFeatureSetting.allowList.models.nodes,
      featureTitle: mockAgenticChatFeatureSetting.title,
      chosenModelForFeature: mockAgenticChatFeatureSetting.gitlabModel,
      allowListEnabled: true,
      visible: true,
      loading: false,
      errorMessage: '',
    });
  });

  describe('when there is no user chosen model', () => {
    it('passes the default GitLab model to `chosenModelForFeature`', () => {
      createComponent({
        props: {
          aiFeatureSetting: {
            ...mockAgenticChatFeatureSetting,
            gitlabModel: null,
          },
        },
      });

      expect(findModal().props('chosenModelForFeature')).toEqual(
        mockAgenticChatFeatureSetting.defaultGitlabModel,
      );
    });
  });

  it('forwards the `visible` prop to AvailableModelsModal', () => {
    expect(findModal().props('visible')).toBe(true);
  });

  it('does not render AvailableModelsModal when not visible', () => {
    createComponent({ props: { visible: false } });

    expect(findModal().exists()).toBe(false);
  });

  it('forwards `update:visible` event to parent', () => {
    findModal().vm.$emit('update:visible', false);

    expect(wrapper.emitted('update:visible')).toEqual([[false]]);
  });

  it('clears the error when the modal emits `update:error-message`', async () => {
    findModal().vm.$emit('update:error-message', '');
    await nextTick();

    expect(findModal().props('errorMessage')).toBe('');
  });

  describe('when the modal emits `save`', () => {
    it('sets the modal `loading` prop while saving', async () => {
      expect(findModal().props('loading')).toBe(false);

      await save();

      expect(findModal().props('loading')).toBe(true);
    });

    it('calls the mutation with the correct input', () => {
      save();

      expect(updateSuccessHandler).toHaveBeenCalledWith({
        input: {
          feature: 'DUO_AGENT_PLATFORM_AGENTIC_CHAT',
          allowlistEnabled: true,
          allowlistModelRefs: ['claude_sonnet_4_20250514'],
        },
      });
    });

    describe('on success', () => {
      beforeEach(async () => {
        save();
        await waitForPromises();
      });

      it('shows a success toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          'Successfully updated available models for GitLab Duo Agentic Chat',
        );
      });

      it('refetches the feature settings query', () => {
        expect(getAiFeatureSettingsHandler).toHaveBeenCalled();
      });

      it('closes the modal', () => {
        expect(wrapper.emitted('update:visible')).toEqual([[false]]);
      });

      it('shows no error on the modal', () => {
        expect(findModal().props('errorMessage')).toBe('');
      });
    });

    describe('on error with a payload', () => {
      const updateErrorInPayloadHandler = jest.fn().mockResolvedValue({
        data: { aiFeatureSettingModelAllowlistUpdate: { errors: ['Something went wrong'] } },
      });

      beforeEach(async () => {
        createComponent({ updateHandler: updateErrorInPayloadHandler });
        save();
        await waitForPromises();
      });

      it('passes the returned error to the modal', () => {
        expect(findModal().props('errorMessage')).toBe('Something went wrong');
      });

      it('keeps the modal open', () => {
        expect(wrapper.emitted('update:visible')).toBeUndefined();
      });
    });

    describe('on error without a payload', () => {
      const updateNullPayloadHandler = jest.fn().mockResolvedValue({
        data: { aiFeatureSettingModelAllowlistUpdate: null },
      });

      beforeEach(async () => {
        createComponent({ updateHandler: updateNullPayloadHandler });
        save();
        await waitForPromises();
      });

      it('shows the default error message instead of crashing', () => {
        expect(findModal().props('errorMessage')).toBe(
          'An error occurred while updating the available models. Please try again.',
        );
      });

      it('keeps the modal open', () => {
        expect(wrapper.emitted('update:visible')).toBeUndefined();
      });
    });

    describe('when the mutation request fails', () => {
      const updateNetworkErrorHandler = jest.fn().mockRejectedValue(new Error('Network error'));

      beforeEach(async () => {
        createComponent({ updateHandler: updateNetworkErrorHandler });
        save();
        await waitForPromises();
      });

      it('passes the error message to the modal', () => {
        expect(findModal().props('errorMessage')).toBe('Network error');
      });

      it('keeps the modal open', () => {
        expect(wrapper.emitted('update:visible')).toBeUndefined();
      });
    });
  });
});
