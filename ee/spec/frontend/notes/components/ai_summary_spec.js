import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { GlIcon, GlSkeletonLoader } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AiSummary from 'ee/notes/components/ai_summary.vue';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/rest_api');

const showToast = jest.fn();
const mocks = {
  $toast: {
    show: showToast,
  },
};

describe('AiSummary component', () => {
  let wrapper;
  let aiResponseSubscriptionHandler;
  const resourceGlobalId = 'gid://gitlab/Issue/1';
  const clientSubscriptionId = 'someId';
  const userId = 99;
  const LONGER_THAN_MAX_REQUEST_TIMEOUT = 1000 * 20; // 20 seconds

  const findMarkdownRef = () => wrapper.findComponent({ ref: 'markdown' });
  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findIcon = (name) =>
    wrapper.findAllComponents(GlIcon).wrappers.find((icon) => icon.props('name') === name);
  const findCopyButton = () => wrapper.findComponent('[data-testid="copy-ai-summary"]');
  const findRemoveButton = () => wrapper.findComponent('[data-testid="remove-ai-summary"]');

  const createWrapper = (props = { aiLoading: true }) => {
    window.gon = { current_user_id: userId };

    aiResponseSubscriptionHandler = createMockSubscription();
    const mockApollo = createMockApollo();
    mockApollo.defaultClient.setRequestHandler(
      aiResponseSubscription,
      () => aiResponseSubscriptionHandler,
    );

    wrapper = mountExtended(AiSummary, {
      apolloProvider: mockApollo,
      provide: {
        resourceGlobalId,
        summarizeClientSubscriptionId: clientSubscriptionId,
      },
      mocks,
      propsData: props,
    });
  };

  describe('aiLoading', () => {
    it('shows only skeleton loader while loading', () => {
      createWrapper();

      expect(findSkeleton().exists()).toBe(true);
      expect(findIcon('eye-slash')).toBeUndefined();
      expect(wrapper.text()).not.toContain('Only visible to you');
    });

    it('shows alert if request times out', () => {
      createWrapper();

      jest.advanceTimersByTime(LONGER_THAN_MAX_REQUEST_TIMEOUT);

      expect(createAlert).toHaveBeenCalled();
    });
  });

  describe('loaded', () => {
    describe('when receiving chunks', () => {
      beforeEach(() => {
        createWrapper({ aiLoading: false });
      });

      it('renders content correctly when received in order', async () => {
        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: 'Hello',
              chunkId: 1,
            },
          },
        });

        await waitForPromises();
        expect(wrapper.text()).toContain('Hello');

        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: ' World',
              chunkId: 2,
            },
          },
        });

        await waitForPromises();
        expect(wrapper.text()).toContain('Hello World');
      });

      it('renders content correctly when received out of order', async () => {
        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: ' World',
              chunkId: 2,
            },
          },
        });

        await nextTick();
        expect(wrapper.text()).not.toContain('World');

        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: 'Hello',
              chunkId: 1,
            },
          },
        });

        await nextTick();
        expect(wrapper.text()).toContain('Hello World');
      });

      it('renders content correctly when full message after chunk', async () => {
        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: '**Hello',
              chunkId: 1,
            },
          },
        });

        await nextTick();
        expect(wrapper.text()).toContain('Hello');

        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: '**Hello World**',
              contentHtml: '<strong>Hello World</strong>',
            },
          },
        });

        await nextTick();
        expect(wrapper.text()).toContain('Hello World');
      });
    });

    describe('when subscription returns an error', () => {
      beforeEach(() => {
        createWrapper({ aiLoading: false });

        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: '**yay**',
              contentHtml: '<strong>yay</strong>',
              errors: ['Some error'],
            },
          },
        });
      });

      it('stops rendering and shows error message', () => {
        expect(wrapper.emitted('set-ai-loading')).toStrictEqual([[false]]);
        expect(wrapper.text()).toBe('');
        expect(createAlert).toHaveBeenCalledWith({
          captureError: true,
          message: 'Some error',
          error: { message: 'Some error' },
        });
      });
    });

    describe('renders correctly', () => {
      beforeEach(() => {
        createWrapper();

        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: '**yay**',
              contentHtml: '<strong>yay</strong>',
            },
          },
        });

        wrapper.setProps({ aiLoading: false });
      });

      it('does not timeout once it has received a successful response', async () => {
        await waitForPromises();
        jest.advanceTimersByTime(LONGER_THAN_MAX_REQUEST_TIMEOUT);

        expect(createAlert).not.toHaveBeenCalled();
      });

      it('shows "AI-generated summary"', () => {
        expect(findIcon('tanuki-ai').exists()).toBe(true);
        expect(wrapper.text()).toContain('AI-generated summary');
      });

      it('shows the response in a markdown block', () => {
        expect(findMarkdownRef().text()).toContain('yay');
      });

      it('shows "Only visible to you"', () => {
        expect(findIcon('eye-slash').exists()).toBe(true);
        expect(wrapper.text()).toContain('Only visible to you');
      });

      it('can copy summary text to clipboard', () => {
        expect(findCopyButton().attributes('data-clipboard-text')).toBe('**yay**');

        findCopyButton().vm.$emit('action');

        expect(showToast).toHaveBeenCalledWith('Copied');
      });

      it('can remove summary from button', async () => {
        findRemoveButton().vm.$emit('action');

        await nextTick();

        expect(wrapper.text()).toBe('');
      });

      it('resets content when loading again', async () => {
        expect(wrapper.emitted('set-ai-loading')).toStrictEqual([[false]]);
        expect(findMarkdownRef().text()).toContain('yay');

        wrapper.setProps({ aiLoading: true });
        await nextTick();

        aiResponseSubscriptionHandler.next({
          data: {
            aiCompletionResponse: {
              content: 'new content',
              contentHtml: '<strong>new content</strong>',
            },
          },
        });

        expect(wrapper.emitted('set-ai-loading')).toStrictEqual([[false], [false]]);

        wrapper.setProps({ aiLoading: false });
        await nextTick();

        expect(findMarkdownRef().text()).toContain('new content');
      });
    });
  });
});
