import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import { createMockSubscription } from 'mock-apollo-client';
import CommentTemperature from 'ee/ai/components/comment_temperature.vue';
import { COMMENT_TEMPERATURE_EVENTS } from 'ee/ai/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/lib/logger');
jest.mock('~/alert');

describe('AiCommentTemperature', () => {
  let wrapper;
  let aiActionMutationHandler;
  let aiResponseSubscriptionHandler;
  let mockSubscription;
  let trackEventSpy;
  const issues = ['Issue 1', 'Issue 2'];

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const defaultProps = {
    userId: 1,
    itemType: 'Issue',
    itemId: 123,
    value: 'Test comment',
  };

  const createComponent = ({ props = {}, data = {} } = {}) => {
    aiActionMutationHandler = jest.fn();
    mockSubscription = createMockSubscription();
    aiResponseSubscriptionHandler = jest.fn().mockReturnValue(mockSubscription);
    const mockApollo = createMockApollo([[aiActionMutation, aiActionMutationHandler]]);
    mockApollo.defaultClient.setRequestHandler(
      aiResponseSubscription,
      aiResponseSubscriptionHandler,
    );

    wrapper = shallowMount(CommentTemperature, {
      propsData: { ...defaultProps, ...props },
      apolloProvider: mockApollo,
      data() {
        return {
          ...data,
        };
      },
      stubs: {
        GlAlert,
      },
    });

    trackEventSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findIssues = () => findAlert().findAll('ul li');
  const findCommentAnywayButton = () => wrapper.findComponent('[data-testid="bad-button"]');
  const findCheckAgainButton = () => wrapper.findComponent('[data-testid="good-button"]');
  const findTheFeedbackLink = () => wrapper.findComponent('[data-testid="feedback-link"]');

  describe('initial state', () => {
    it('does not show the alert', () => {
      createComponent();
      expect(findAlert().exists()).toBe(false);
    });

    it('logs the correct event when measuring the temperature', () => {
      createComponent();
      wrapper.vm.measureCommentTemperature();
      expect(trackEventSpy).toHaveBeenCalledWith(
        COMMENT_TEMPERATURE_EVENTS.MEASUREMENT_REQUESTED,
        {},
        undefined,
      );
    });
  });

  describe('when clicking', () => {
    beforeEach(async () => {
      createComponent({
        data: {
          commentTemperatureIssues: issues,
        },
      });
      await nextTick();
      aiActionMutationHandler.mockResolvedValue({ data: { aiAction: { errors: [] } } });
    });

    it('accepts a well-formatted gid as `itemId`', async () => {
      createComponent({
        props: {
          itemId: 'gid://gitlab/Issue/123',
        },
      });
      await nextTick();
      wrapper.vm.measureCommentTemperature();
      expect(aiActionMutationHandler).toHaveBeenCalledWith({
        input: {
          measureCommentTemperature: {
            content: defaultProps.value,
            resourceId: 'gid://gitlab/Issue/123',
          },
          clientSubscriptionId: expect.any(String),
        },
      });
    });

    it('correctly renders the feedback issue link', () => {
      expect(findTheFeedbackLink().exists()).toBe(true);
      expect(findTheFeedbackLink().attributes('href')).toBe(
        'https://gitlab.com/gitlab-org/gitlab/-/issues/511508',
      );
      expect(findTheFeedbackLink().props('target')).toBe('_blank');
    });

    describe('the check-again button', () => {
      it('calls the aiActionMutation with correct variables', () => {
        findCheckAgainButton().vm.$emit('click');
        expect(aiActionMutationHandler).toHaveBeenCalledWith({
          input: {
            measureCommentTemperature: {
              content: defaultProps.value,
              resourceId: expect.any(String),
            },
            clientSubscriptionId: expect.any(String),
          },
        });
      });

      it('triggers the loading state of the button', async () => {
        const btn = findCheckAgainButton();
        btn.vm.$emit('click');
        await nextTick();
        expect(btn.props('loading')).toBe(true);
      });

      it('subscribes to temperature updates on successful mutation', async () => {
        findCheckAgainButton().vm.$emit('click');
        await waitForPromises();
        expect(aiResponseSubscriptionHandler).toHaveBeenCalled();
      });

      it('handles mutation errors', async () => {
        aiActionMutationHandler.mockRejectedValue(new Error('Mutation error'));
        findCheckAgainButton().vm.$emit('click');
        await waitForPromises();
        expect(logError).toHaveBeenCalledWith(new Error('Mutation error'));
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to measure the comment temperature. Please try again.',
        });
      });
    });

    describe('the comment-anyway button', () => {
      it('does not run the mutation and saves the comment right away', () => {
        findCommentAnywayButton().vm.$emit('click');
        expect(aiActionMutationHandler).not.toHaveBeenCalled();
        expect(wrapper.emitted('save')).toEqual([[]]);
      });

      it('resets the comment temperature issues', () => {
        findCommentAnywayButton().vm.$emit('click');
        expect(findIssues()).toHaveLength(2);
      });

      it('logs the correct event', () => {
        findCommentAnywayButton().vm.$emit('click');
        expect(trackEventSpy).toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.FORCED_COMMENT,
          {},
          undefined,
        );
      });
    });
  });

  describe('subscription handling', () => {
    beforeEach(() => {
      createComponent({
        data: {
          subscribedToTemperatureUpdates: true,
        },
      });
    });

    describe('correctly unwraps the data from the response', () => {
      it.each([
        `<temperature_rating>{"rating": 2, "issues": ${JSON.stringify(issues)}}</temperature_rating>`,
        `<temperature_rating>{"rating": 2,"issues": ${JSON.stringify(issues)}}</temperature_rating>`,
        `<temperature_rating>\n{"rating": 2, "issues": ${JSON.stringify(issues)}}\n</temperature_rating>`,
        `<temperature_rating>\n{"rating": 2,"issues": ${JSON.stringify(issues)}}\n</temperature_rating>`,
        `Foo bar <temperature_rating>{"rating": 2, "issues": ${JSON.stringify(issues)}}</temperature_rating> blah-blah`,
        `Foo bar <temperature_rating>\n{"rating": 2, "issues": ${JSON.stringify(issues)}}\n</temperature_rating> blah-blah`,
        `Foo bar\n<temperature_rating>{"rating": 2, "issues": ${JSON.stringify(issues)}}</temperature_rating>\nblah-blah`,
        `Foo bar\n<temperature_rating>\n{"rating": 2, "issues": ${JSON.stringify(issues)}}\n</temperature_rating>\nblah-blah`,
        `{"rating": 2, "issues": ${JSON.stringify(issues)}}`,
        `{"rating": 2,"issues": ${JSON.stringify(issues)}}`,
        `{"rating": 2, "issues": ${JSON.stringify(issues)}}\n`,
      ])('correctly unwraps the response data from "%s"', async (string) => {
        mockSubscription.next({
          data: {
            aiCompletionResponse: {
              content: string,
            },
          },
        });
        await nextTick();
        expect(findAlert().exists()).toBe(true);
        expect(findIssues()).toHaveLength(issues.length);
      });
    });

    describe('events logging', () => {
      it('logs the correct event if the temperature is high', () => {
        mockSubscription.next({
          data: {
            aiCompletionResponse: {
              content: `<temperature_rating>{"rating": 2, "issues": ${JSON.stringify(issues)}}</temperature_rating>`,
            },
          },
        });
        expect(trackEventSpy).toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.HIGH_TEMP,
          {},
          undefined,
        );
        expect(trackEventSpy).not.toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.REPEATED_HIGH_TEMP,
          {},
          undefined,
        );
      });

      it('logs the correct event if the temperature is high repeatedly', () => {
        createComponent({
          data: {
            subscribedToTemperatureUpdates: true,
            commentTemperatureIssues: issues,
          },
        });
        mockSubscription.next({
          data: {
            aiCompletionResponse: {
              content: `<temperature_rating>{"rating": 2, "issues": ${JSON.stringify(issues)}}</temperature_rating>`,
            },
          },
        });
        expect(trackEventSpy).toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.REPEATED_HIGH_TEMP,
          {},
          undefined,
        );
        expect(trackEventSpy).not.toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.HIGH_TEMP,
          {},
          undefined,
        );
      });

      it('does not log any events beyond normal when the temperature is not high', () => {
        mockSubscription.next({
          data: {
            aiCompletionResponse: {
              content: `<temperature_rating>${JSON.stringify({ rating: 1, issues: [] })}</temperature_rating>`,
            },
          },
        });
        expect(trackEventSpy).not.toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.HIGH_TEMP,
          {},
          undefined,
        );
        expect(trackEventSpy).not.toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.REPEATED_HIGH_TEMP,
          {},
          undefined,
        );
        expect(trackEventSpy).not.toHaveBeenCalledWith(
          COMMENT_TEMPERATURE_EVENTS.FORCED_COMMENT,
          {},
          undefined,
        );
      });
    });

    it('catches the errors when parsing JSON', async () => {
      // In this test, we intentionally provide an invalid JSON object as an argument to JSON.parse.
      mockSubscription.next({
        data: {
          aiCompletionResponse: {
            content: `<temperature_rating>{rating: 2, issues: ${issues}}</temperature_rating>`,
          },
        },
      });
      await nextTick();
      expect(logError).toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occured while parsing comment temperature. Please try again.',
      });
    });

    it('emits `save` when rating is 1 (good) and does not render anything', async () => {
      mockSubscription.next({
        data: {
          aiCompletionResponse: {
            content: `<temperature_rating>${JSON.stringify({ rating: 1, issues: [] })}</temperature_rating>`,
          },
        },
      });
      await nextTick();
      expect(findAlert().exists()).toBe(false);
      expect(wrapper.emitted('save')).toEqual([[]]);
    });

    it('handles subscription errors', async () => {
      mockSubscription.error(new Error('Subscription error'));
      await nextTick();
      expect(logError).toHaveBeenCalledWith(new Error('Subscription error'));
      expect(createAlert).toHaveBeenCalledWith({
        message:
          'An error occured when subscribing to the comment temperature updates. Please try again.',
      });
    });
  });
});
