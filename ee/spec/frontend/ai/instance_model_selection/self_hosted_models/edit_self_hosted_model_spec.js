import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import SelfHostedModelForm from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_model_form.vue';
import updateSelfHostedModelMutation from 'ee/ai/instance_model_selection/self_hosted_models/graphql/mutations/update_self_hosted_model.mutation.graphql';
import EditSelfHostedModel from 'ee/ai/instance_model_selection/self_hosted_models/components/edit_self_hosted_model.vue';
import { SELF_HOSTED_MODEL_MUTATIONS } from 'ee/ai/instance_model_selection/self_hosted_models/constants';
import getSelfHostedModelByIdQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_model_by_id.query.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { mockSelfHostedModel } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('EditSelfHostedModel', () => {
  let wrapper;

  const getSelfHostedModelQueryHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        nodes: [mockSelfHostedModel],
        errors: [],
      },
    },
  });

  const createComponent = async ({
    apolloHandlers = [[getSelfHostedModelByIdQuery, getSelfHostedModelQueryHandler]],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);
    const modelId = getIdFromGraphQLId(mockSelfHostedModel.id);

    wrapper = shallowMount(EditSelfHostedModel, {
      apolloProvider: mockApollo,
      propsData: {
        modelId,
      },
    });

    await waitForPromises();
  };

  const findSelfHostedModelForm = () => wrapper.findComponent(SelfHostedModelForm);

  it('has a title', () => {
    createComponent();

    expect(wrapper.text()).toMatch('Edit self-hosted model');
  });

  it('has a description', () => {
    createComponent();

    expect(wrapper.text()).toMatch(
      'Edit the AI model that can be used for GitLab Duo self-hosted features.',
    );
  });

  it('fetches self-hosted model data', () => {
    createComponent();

    expect(getSelfHostedModelQueryHandler).toHaveBeenCalledWith({
      id: mockSelfHostedModel.id,
    });
  });

  describe('when the API query succeeds', () => {
    it('renders the self-hosted model form and passes the correct props', async () => {
      await createComponent();

      expect(findSelfHostedModelForm().props('initialFormValues')).toEqual(mockSelfHostedModel);
      expect(findSelfHostedModelForm().props('mutationData')).toEqual({
        name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
        mutation: updateSelfHostedModelMutation,
      });
      expect(findSelfHostedModelForm().props('submitButtonText')).toBe('Save changes');
    });
  });

  describe('when the API query is unsuccessful', () => {
    describe('due to a general error', () => {
      it('displays an error message', async () => {
        await createComponent({
          apolloHandlers: [[getSelfHostedModelByIdQuery, jest.fn().mockRejectedValue('ERROR')]],
        });

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the self-hosted model. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getSelfHostedModelErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModels: {
            errors: ['An error occurred'],
          },
        },
      });

      it('displays an error message', async () => {
        await createComponent({
          apolloHandlers: [[getSelfHostedModelByIdQuery, getSelfHostedModelErrorHandler]],
        });

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the self-hosted model. Please try again.',
          }),
        );
      });
    });
  });
});
