import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TargetedMessageBanner from 'ee/targeted_message_banner/components/index.vue';
import getTargetedMessageData from 'ee/targeted_message_banner/graphql/queries/get_targeted_message_data.query.graphql';
import { reportToSentry } from '~/ci/utils';

Vue.use(VueApollo);

jest.mock('~/ci/utils');

describe('TargetedMessageBanner component', () => {
  let wrapper;

  const mockTargetedMessages = [
    {
      __typename: 'TargetedMessage',
      id: '1',
      targetType: 'PROMOTION',
    },
  ];

  const mockQueryHandler = jest.fn().mockResolvedValue({
    data: {
      namespace: {
        __typename: 'Namespace',
        id: 'gid://gitlab/Group/1',
        targetedMessages: mockTargetedMessages,
      },
    },
  });

  const createComponent = (
    queryHandler = mockQueryHandler,
    namespaceFullPath = 'my-namespace',
    glFeatures = {},
  ) => {
    const mockApollo = createMockApollo([[getTargetedMessageData, queryHandler]]);
    wrapper = shallowMountExtended(TargetedMessageBanner, {
      apolloProvider: mockApollo,
      provide: {
        namespaceFullPath,
        glFeatures: {
          targetedMessagesAdminUi: true,
          ...glFeatures,
        },
      },
    });

    return waitForPromises();
  };

  it('renders GlBanner when targeted messages are returned from query', async () => {
    await createComponent();

    expect(wrapper.findComponent({ name: 'GlBanner' }).exists()).toBe(true);
  });

  it('does not render GlBanner when no targeted messages are returned', async () => {
    const emptyQueryHandler = jest.fn().mockResolvedValue({
      data: {
        namespace: {
          __typename: 'Namespace',
          id: 'gid://gitlab/Group/1',
          targetedMessages: [],
        },
      },
    });

    await createComponent(emptyQueryHandler);

    expect(wrapper.findComponent({ name: 'GlBanner' }).exists()).toBe(false);
  });

  it('passes namespaceFullPath to the query', async () => {
    await createComponent(mockQueryHandler, 'test-namespace');

    expect(mockQueryHandler).toHaveBeenCalledWith({
      fullPath: 'test-namespace',
    });
  });

  describe('error handling', () => {
    it('reports error to Sentry when query fails', async () => {
      const mockError = new Error('GraphQL query failed');
      const errorQueryHandler = jest.fn().mockRejectedValue(mockError);

      await createComponent(errorQueryHandler);
      await waitForPromises();

      expect(reportToSentry).toHaveBeenCalledWith('TargetedMessageBanner', mockError);
    });

    it('does not render banner when query returns error', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue(new Error('Network error'));

      await createComponent(errorQueryHandler);
      await waitForPromises();

      expect(wrapper.findComponent({ name: 'GlBanner' }).exists()).toBe(false);
    });
  });

  describe('loading state', () => {
    it('does not render banner while query is loading', async () => {
      const pendingQueryHandler = jest.fn(() => new Promise(() => {})); // Never resolves

      await createComponent(pendingQueryHandler);

      expect(wrapper.findComponent({ name: 'GlBanner' }).exists()).toBe(false);
    });
  });

  describe('feature flag', () => {
    it('does not render banner when feature flag is disabled', async () => {
      await createComponent(mockQueryHandler, 'my-namespace', { targetedMessagesAdminUi: false });

      expect(wrapper.findComponent({ name: 'GlBanner' }).exists()).toBe(false);
    });

    it('does not make Apollo query when feature flag is disabled', async () => {
      const queryHandler = jest.fn();
      await createComponent(queryHandler, 'my-namespace', { targetedMessagesAdminUi: false });

      expect(queryHandler).not.toHaveBeenCalled();
    });
  });
});
