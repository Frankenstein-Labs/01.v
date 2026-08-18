import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import testSelfHostedModelConnectionMutation from 'ee/ai/instance_model_selection/self_hosted_models/graphql/mutations/test_self_hosted_model_connection.mutation.graphql';
import TestConnectionButton from 'ee/ai/instance_model_selection/self_hosted_models/components/test_connection_button.vue';
import { mockModelConnectionTestInput } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('TestConnectionButton', () => {
  let wrapper;

  const modelTestConnectionSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelConnectionCheck: {
        result: {
          success: true,
          message: 'Self-hosted model connection was successful',
          errors: [],
        },
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[testSelfHostedModelConnectionMutation, modelTestConnectionSuccessHandler]],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = shallowMount(TestConnectionButton, {
      apolloProvider: mockApollo,
      propsData: {
        connectionTestInput: mockModelConnectionTestInput,
        disabled: false,
        ...props,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  it('renders the model test connection button', () => {
    createComponent();

    expect(findButton().text()).toBe('Test connection');
  });

  describe('button submit', () => {
    it('invokes the test connection mutation with correct input', async () => {
      createComponent();

      findButton().vm.$emit('click', new MouseEvent('click'));
      await waitForPromises();

      expect(modelTestConnectionSuccessHandler).toHaveBeenCalledWith({
        input: mockModelConnectionTestInput,
      });
    });

    describe('when the connection test succeeds', () => {
      it('displays a success alert', async () => {
        createComponent();

        findButton().vm.$emit('click', new MouseEvent('click'));
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Self-hosted model connection was successful',
            variant: 'success',
          }),
        );
      });
    });

    describe('when the connection test does not succeed', () => {
      const modelTestConnectionErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelConnectionCheck: {
            result: {
              success: false,
              message: 'Self-hosted model connection was unsuccessful',
              errors: ['Self-hosted model connection was unsuccessful'],
            },
          },
        },
      });

      it('displays an error alert', async () => {
        createComponent({
          apolloHandlers: [
            [testSelfHostedModelConnectionMutation, modelTestConnectionErrorHandler],
          ],
        });

        findButton().vm.$emit('click', new MouseEvent('click'));
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Self-hosted model connection was unsuccessful',
          }),
        );
      });
    });
  });
});
