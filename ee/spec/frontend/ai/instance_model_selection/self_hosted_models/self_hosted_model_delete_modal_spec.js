import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlButton, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import { createAlert } from '~/alert';

import getSelfHostedModelsQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import getAiFeatureSettingsQuery from 'ee/ai/instance_model_selection/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import deleteSelfHostedModelMutation from 'ee/ai/instance_model_selection/self_hosted_models/graphql/mutations/delete_self_hosted_model.mutation.graphql';
import DeleteModal from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_model_delete_modal.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { mockSelfHostedModelsList } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

const MOCK_MODAL_ID = 'delete-mock-model-modal';
const mockModel = mockSelfHostedModelsList[1]; // without feature settings

describe('DeleteModal', () => {
  let wrapper;

  const getAiFeatureSettingsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        errors: [],
      },
    },
  });

  const getSelfHostedModelsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        errors: [],
      },
    },
  });

  const deleteMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelDelete: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[deleteSelfHostedModelMutation, deleteMutationSuccessHandler]],
  } = {}) => {
    const mockApollo = createMockApollo([
      [getSelfHostedModelsQuery, getSelfHostedModelsQueryHandler],
      [getAiFeatureSettingsQuery, getAiFeatureSettingsQueryHandler],
      ...apolloHandlers,
    ]);

    wrapper = extendedWrapper(
      shallowMount(DeleteModal, {
        apolloProvider: mockApollo,
        propsData: {
          id: MOCK_MODAL_ID,
          model: mockModel,
        },
        stubs: { GlModal, GlButton, GlSprintf },
      }),
    );
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findModalText = () => wrapper.findByTestId('delete-model-confirmation-message').text();
  const findSecondaryButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findDeleteButton = () => wrapper.findAllComponents(GlButton).at(1);

  beforeEach(() => {
    createComponent();
  });

  it('displays the correct title', () => {
    expect(findModal().props('title')).toBe('Delete self-hosted model');
  });

  it('sets modal id', () => {
    expect(findModal().props('modalId')).toBe(MOCK_MODAL_ID);
  });

  it('displays the correct body', () => {
    expect(findModalText()).toMatchInterpolatedText(
      `You are about to delete the ${mockModel.name} self-hosted model. This action cannot be undone.`,
    );
  });

  it('has a delete button', () => {
    expect(findDeleteButton().text()).toBe('Delete');
  });

  it('has a cancel button', () => {
    expect(findSecondaryButton().text()).toBe('Cancel');
  });

  describe('deleting a self-hosted model', () => {
    it('invokes delete mutation', () => {
      findModal().vm.$emit('primary');

      expect(deleteMutationSuccessHandler).toHaveBeenCalledWith({
        input: { id: mockModel.id },
      });
    });

    describe('when a deletion succeeds', () => {
      beforeEach(async () => {
        createComponent();

        findModal().vm.$emit('primary');

        await waitForPromises();
      });

      it('refreshes self-hosted model data', () => {
        expect(getSelfHostedModelsQueryHandler).toHaveBeenCalledTimes(1);
      });

      it('refetches AI feature settings data', () => {
        expect(getAiFeatureSettingsQueryHandler).toHaveBeenCalledTimes(1);
      });

      it('shows a success message', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Your self-hosted model was successfully deleted.',
          }),
        );
      });
    });

    describe('when a deletion fails', () => {
      const deleteMutationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelDelete: {
            errors: ['Self-hosted model not found'],
          },
        },
      });

      beforeEach(() => {
        createComponent({
          apolloHandlers: [[deleteSelfHostedModelMutation, deleteMutationErrorHandler]],
        });
      });

      it('shows an error message', async () => {
        findModal().vm.$emit('primary');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Self-hosted model not found',
          }),
        );
      });
    });
  });
});
