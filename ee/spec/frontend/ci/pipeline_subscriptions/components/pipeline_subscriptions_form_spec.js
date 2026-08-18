import { GlFormInput, GlLink } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PipelineSubscriptionsForm from 'ee/ci/pipeline_subscriptions/components/pipeline_subscriptions_form.vue';
import AddPipelineSubscription from 'ee/ci/pipeline_subscriptions/graphql/mutations/add_pipeline_subscription.mutation.graphql';

import { addMutationResponse } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Pipeline subscriptions form', () => {
  let wrapper;

  const successHandler = jest.fn().mockResolvedValue(addMutationResponse);
  const failedHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));

  const findInput = () => wrapper.findComponent(GlFormInput);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findSubscribeBtn = () => wrapper.findComponentByTestId('subscribe-button');
  const findCancelBtn = () => wrapper.findComponentByTestId('cancel-button');

  const defaultHandlers = [[AddPipelineSubscription, successHandler]];

  const defaultProvideOptions = {
    projectPath: '/namespace/my-project',
  };

  const upstreamPath = 'root/project';

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = (handlers = defaultHandlers, mountFn = shallowMountExtended) => {
    wrapper = mountFn(PipelineSubscriptionsForm, {
      provide: {
        ...defaultProvideOptions,
      },
      apolloProvider: createMockApolloProvider(handlers),
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the upstream input field', () => {
      expect(findInput().exists()).toBe(true);
    });

    it('subscribes to an upstream project', async () => {
      findInput().vm.$emit('input', upstreamPath);

      findSubscribeBtn().vm.$emit('click');

      await waitForPromises();

      expect(successHandler).toHaveBeenCalledWith({
        input: {
          projectPath: defaultProvideOptions.projectPath,
          upstreamPath,
        },
      });
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Subscription successfully created.',
        variant: 'success',
      });
    });

    it('cancels adding a subscription and emits the canceled event', async () => {
      findInput().vm.$emit('input', upstreamPath);

      await nextTick();

      expect(findInput().attributes('value')).toBe(upstreamPath);

      findCancelBtn().vm.$emit('click');

      await nextTick();

      expect(wrapper.emitted('canceled')).toEqual([[]]);
      expect(findInput().attributes('value')).toBe('');
    });
  });

  describe('errors', () => {
    beforeEach(() => {
      createComponent([[AddPipelineSubscription, failedHandler]]);
    });

    it('shows alert when error occurs', async () => {
      findInput().vm.$emit('input', '');

      findSubscribeBtn().vm.$emit('click');

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while adding a new pipeline subscription.',
      });
    });
  });

  it('displays help link to docs', () => {
    createComponent(defaultHandlers, mountExtended);

    expect(findHelpLink().attributes('href')).toBe(
      '/help/ci/pipelines/_index#trigger-a-pipeline-when-an-upstream-project-is-rebuilt',
    );
  });
});
