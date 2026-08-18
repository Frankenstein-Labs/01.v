import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import AiResponseSubscription from 'ee/ai/tanuki_bot/components/tanuki_bot_subscriptions.vue';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResponseStreamSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response_stream.subscription.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/state';

import {
  MOCK_USER_ID,
  GENERATE_MOCK_TANUKI_RES,
  MOCK_CHUNK_MESSAGE,
  MOCK_CLIENT_SUBSCRIPTION_ID,
} from '../mock_data';

Vue.use(VueApollo);

describe('Ai Response Subscriptions', () => {
  let wrapper;

  let mockSubscriptionComplete;
  let mockSubscriptionStream;
  let aiResponseSubscriptionHandler;
  let aiResponseStreamSubscriptionHandler;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    const apolloProvider = createMockApollo();

    apolloProvider.defaultClient.setRequestHandler(
      aiResponseSubscription,
      aiResponseSubscriptionHandler,
    );

    apolloProvider.defaultClient.setRequestHandler(
      aiResponseStreamSubscription,
      aiResponseStreamSubscriptionHandler,
    );

    wrapper = shallowMountExtended(AiResponseSubscription, {
      apolloProvider,
      propsData: {
        userId: MOCK_USER_ID,
        clientSubscriptionId: MOCK_CLIENT_SUBSCRIPTION_ID,
        activeThreadId: 'thread-1',
        ...propsData,
      },
      provide: {
        ...provide,
      },
    });
  };

  beforeEach(() => {
    mockSubscriptionComplete = createMockSubscription();
    mockSubscriptionStream = createMockSubscription();
    // Return a fresh subscription on resubscribe: under Vue 3, vue-apollo
    // resubscribes after an error, and handing back the already-errored mock
    // would error again immediately, looping forever.
    aiResponseSubscriptionHandler = jest
      .fn()
      .mockImplementationOnce(() => mockSubscriptionComplete)
      .mockImplementation(() => createMockSubscription());
    aiResponseStreamSubscriptionHandler = jest
      .fn()
      .mockImplementationOnce(() => mockSubscriptionStream)
      .mockImplementation(() => createMockSubscription());
  });

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.commands = [];
  });

  // Helper functions to reduce duplication
  const createResponseData = (requestId, threadId = 'thread-1', isStream = false) => ({
    data: {
      aiCompletionResponse: {
        ...(isStream
          ? MOCK_CHUNK_MESSAGE('first chunk', 1, requestId)
          : GENERATE_MOCK_TANUKI_RES('', requestId)),
        threadId,
      },
    },
  });

  const testMessageEmission = async ({
    eventName,
    isStream = false,
    threadId = 'thread-1',
    shouldEmit = true,
  }) => {
    const requestId = '123';
    const response = createResponseData(requestId, threadId, isStream);

    createComponent();
    await waitForPromises();

    const subscription = isStream ? mockSubscriptionStream : mockSubscriptionComplete;
    subscription.next(response);
    await waitForPromises();

    const emittedEvents = wrapper.emitted(eventName);

    if (shouldEmit) {
      expect(emittedEvents).toHaveLength(1);
      expect(emittedEvents[0]).toEqual([response.data.aiCompletionResponse]);
    } else {
      expect(emittedEvents).toBe(undefined);
    }
  };

  describe('Subscriptions', () => {
    it('passes the correct variables to the subscription queries', async () => {
      createComponent();
      await waitForPromises();

      expect(aiResponseSubscriptionHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: MOCK_USER_ID,
          aiAction: 'CHAT',
        }),
      );

      expect(aiResponseStreamSubscriptionHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: MOCK_USER_ID,
          clientSubscriptionId: MOCK_CLIENT_SUBSCRIPTION_ID,
        }),
      );
    });

    it.each([
      ['aiCompletionResponse', () => mockSubscriptionComplete],
      ['aiCompletionResponseStream', () => mockSubscriptionStream],
    ])('emits `error` when the %s subscription errors', async (_, getSubscription) => {
      const error = new Error('subscription failed');

      createComponent();
      await waitForPromises();

      getSubscription().error(error);
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    describe('aiCompletionResponseStream', () => {
      it('emits message stream event', () => {
        return testMessageEmission({ eventName: 'message-stream', isStream: true });
      });

      it('emits response-received event', async () => {
        const requestId = '123';
        const response = createResponseData(requestId, 'thread-1', true);

        createComponent();
        await waitForPromises();

        mockSubscriptionStream.next(response);
        await waitForPromises();

        const emittedEvents = wrapper.emitted('response-received');
        expect(emittedEvents).toHaveLength(1);
        expect(emittedEvents[0]).toEqual([requestId]);
      });

      it('does not emit message-stream event when threadId does not match', () => {
        return testMessageEmission({
          eventName: 'message-stream',
          isStream: true,
          threadId: 'thread-2',
          shouldEmit: false,
        });
      });

      it('emits message-stream event when activeThreadId is not yet set and message has a threadId', async () => {
        const requestId = '123';
        const response = createResponseData(requestId, 'thread-1', true);

        createComponent({ propsData: { activeThreadId: '' } });
        await waitForPromises();

        mockSubscriptionStream.next(response);
        await waitForPromises();

        expect(wrapper.emitted('message-stream')).toHaveLength(1);
        expect(wrapper.emitted('message-stream')[0]).toEqual([response.data.aiCompletionResponse]);
      });

      it('does not emit message-stream event when activeThreadId is set and threadId does not match', () => {
        return testMessageEmission({
          eventName: 'message-stream',
          isStream: true,
          threadId: 'thread-2',
          shouldEmit: false,
        });
      });
    });

    describe('aiCompletionResponse', () => {
      it('emits message event', () => {
        return testMessageEmission({ eventName: 'message' });
      });

      it('does not emit message event when threadId does not match', () => {
        return testMessageEmission({
          eventName: 'message',
          threadId: 'thread-2',
          shouldEmit: false,
        });
      });

      it('emits message event when activeThreadId is not yet set and message has a threadId', async () => {
        const requestId = '123';
        const response = createResponseData(requestId, 'thread-1', false);

        createComponent({ propsData: { activeThreadId: '' } });
        await waitForPromises();

        mockSubscriptionComplete.next(response);
        await waitForPromises();

        expect(wrapper.emitted('message')).toHaveLength(1);
        expect(wrapper.emitted('message')[0]).toEqual([response.data.aiCompletionResponse]);
      });

      it('does not emit message event when activeThreadId is set and threadId does not match', () => {
        return testMessageEmission({
          eventName: 'message',
          threadId: 'thread-2',
          shouldEmit: false,
        });
      });
    });
  });
});
