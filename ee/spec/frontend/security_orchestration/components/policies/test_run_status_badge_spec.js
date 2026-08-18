import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TestRunStatusBadge from 'ee/security_orchestration/components/policies/test_run_status_badge.vue';
import spepTestRunUpdatedSubscription from 'ee/security_orchestration/graphql/subscriptions/spep_test_run_updated.subscription.graphql';

Vue.use(VueApollo);

describe('TestRunStatusBadge', () => {
  let wrapper;

  const TEST_RUN_ID = 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/1';

  const createComponent = ({ testRun = null, subscriptionHandler = jest.fn() } = {}) => {
    const mockApollo = createMockApollo([[spepTestRunUpdatedSubscription, subscriptionHandler]]);

    wrapper = shallowMountExtended(TestRunStatusBadge, {
      apolloProvider: mockApollo,
      propsData: { testRun },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);

  describe('when no test run exists', () => {
    it('does not render badge when testRun is null', () => {
      createComponent();

      expect(findBadge().exists()).toBe(false);
    });
  });

  describe('when test run exists', () => {
    it.each`
      state         | expectedVariant | expectedText       | expectedIcon
      ${'PENDING'}  | ${'neutral'}    | ${'Test pending'}  | ${'status_pending'}
      ${'RUNNING'}  | ${'info'}       | ${'Test running'}  | ${'status_running'}
      ${'COMPLETE'} | ${'success'}    | ${'Test complete'} | ${'status_closed'}
      ${'FAILED'}   | ${'danger'}     | ${'Test failed'}   | ${'status_failed'}
    `(
      'renders $state state with $expectedVariant variant, "$expectedText" text, and $expectedIcon icon',
      ({ state, expectedVariant, expectedText, expectedIcon }) => {
        createComponent({
          testRun: { id: TEST_RUN_ID, state, completed: state !== 'RUNNING' },
        });

        expect(findBadge().exists()).toBe(true);
        expect(findBadge().props('variant')).toBe(expectedVariant);
        expect(findBadge().props('icon')).toBe(expectedIcon);
        expect(findBadge().text()).toBe(expectedText);
      },
    );

    it('renders neutral variant for unknown state', () => {
      createComponent({
        testRun: { id: TEST_RUN_ID, state: 'UNKNOWN', completed: true },
      });

      expect(findBadge().exists()).toBe(true);
      expect(findBadge().props('variant')).toBe('neutral');
      expect(findBadge().props('icon')).toBeNull();
    });
  });

  describe('subscription', () => {
    it.each(['RUNNING', 'PENDING'])('subscribes when test run is in %s state', (state) => {
      const subscriptionHandler = jest.fn().mockResolvedValue({});
      createComponent({
        testRun: { id: TEST_RUN_ID, state, completed: false },
        subscriptionHandler,
      });

      expect(subscriptionHandler).toHaveBeenCalledWith({ testRunId: TEST_RUN_ID });
    });

    it('does not subscribe when test run is completed', () => {
      const subscriptionHandler = jest.fn();
      createComponent({
        testRun: { id: TEST_RUN_ID, state: 'COMPLETE', completed: true },
        subscriptionHandler,
      });

      expect(subscriptionHandler).not.toHaveBeenCalled();
    });

    it('does not subscribe when there is no test run', () => {
      const subscriptionHandler = jest.fn();
      createComponent({ testRun: null, subscriptionHandler });

      expect(subscriptionHandler).not.toHaveBeenCalled();
    });

    it('re-subscribes and updates badge when a new run starts after a previous run completed', async () => {
      const RUN_1_ID = 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/1';
      const RUN_2_ID = 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/2';

      let resolveSubscription;
      const subscriptionHandler = jest.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveSubscription = resolve;
        }),
      );

      createComponent({
        testRun: { id: RUN_1_ID, state: 'RUNNING', completed: false },
        subscriptionHandler,
      });

      // Run 1 completes via subscription
      resolveSubscription({
        data: {
          securityPolicyScheduleTestRunUpdated: {
            id: RUN_1_ID,
            state: 'COMPLETE',
            completed: true,
            startedAt: '2024-01-01T00:00:00Z',
            finishedAt: '2024-01-01T00:05:00Z',
            duration: 300,
            errorMessage: null,
            project: { id: 'gid://gitlab/Project/1', fullPath: 'group/project', name: 'Project' },
          },
        },
      });
      await waitForPromises();
      expect(findBadge().props('variant')).toBe('success');

      // Run 2 starts — parent passes a new testRun prop with a different ID.
      // Use a deferred promise so we can check the badge state before
      // the subscription resolves.
      let resolveRun2Subscription;
      subscriptionHandler.mockReturnValue(
        new Promise((resolve) => {
          resolveRun2Subscription = resolve;
        }),
      );
      await wrapper.setProps({ testRun: { id: RUN_2_ID, state: 'RUNNING', completed: false } });
      await nextTick();

      // Before the subscription resolves, badge should reflect the prop (RUNNING).
      expect(findBadge().props('variant')).toBe('info');
      expect(subscriptionHandler).toHaveBeenCalledWith({ testRunId: RUN_2_ID });

      // Subscription resolves — badge should update to COMPLETE.
      resolveRun2Subscription({
        data: {
          securityPolicyScheduleTestRunUpdated: {
            id: RUN_2_ID,
            state: 'COMPLETE',
            completed: true,
            startedAt: '2024-01-01T01:00:00Z',
            finishedAt: '2024-01-01T01:05:00Z',
            duration: 300,
            errorMessage: null,
            project: { id: 'gid://gitlab/Project/1', fullPath: 'group/project', name: 'Project' },
          },
        },
      });
      await waitForPromises();
      expect(findBadge().props('variant')).toBe('success');
    });

    it('hides badge and does not show stale liveTestRun when testRun prop becomes null', async () => {
      let resolveSubscription;
      const subscriptionHandler = jest.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveSubscription = resolve;
        }),
      );

      createComponent({
        testRun: { id: TEST_RUN_ID, state: 'RUNNING', completed: false },
        subscriptionHandler,
      });

      resolveSubscription({
        data: {
          securityPolicyScheduleTestRunUpdated: {
            id: TEST_RUN_ID,
            state: 'COMPLETE',
            completed: true,
            startedAt: '2024-01-01T00:00:00Z',
            finishedAt: '2024-01-01T00:05:00Z',
            duration: 300,
            errorMessage: null,
            project: { id: 'gid://gitlab/Project/1', fullPath: 'group/project', name: 'Project' },
          },
        },
      });
      await waitForPromises();
      expect(findBadge().props('variant')).toBe('success');

      // Parent removes the test run (e.g. query refetch returns no nodes)
      await wrapper.setProps({ testRun: null });
      await nextTick();

      expect(findBadge().exists()).toBe(false);
    });

    it('ignores a stale subscription result for a previous run when a new run is already active', async () => {
      const RUN_1_ID = 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/1';
      const RUN_2_ID = 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/2';

      // Subscription for run 1 is deliberately left pending
      let resolveRun1Subscription;
      const subscriptionHandler = jest.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveRun1Subscription = resolve;
        }),
      );

      createComponent({
        testRun: { id: RUN_1_ID, state: 'RUNNING', completed: false },
        subscriptionHandler,
      });

      // Parent advances to run 2 before run 1's subscription resolves
      subscriptionHandler.mockResolvedValue({});
      await wrapper.setProps({ testRun: { id: RUN_2_ID, state: 'RUNNING', completed: false } });
      await nextTick();

      expect(findBadge().props('variant')).toBe('info');

      // Late-arriving result for run 1 — must NOT update the badge
      resolveRun1Subscription({
        data: {
          securityPolicyScheduleTestRunUpdated: {
            id: RUN_1_ID,
            state: 'COMPLETE',
            completed: true,
            startedAt: '2024-01-01T00:00:00Z',
            finishedAt: '2024-01-01T00:05:00Z',
            duration: 300,
            errorMessage: null,
            project: { id: 'gid://gitlab/Project/1', fullPath: 'group/project', name: 'Project' },
          },
        },
      });
      await waitForPromises();

      // Badge must still show run 2's RUNNING state, not run 1's stale COMPLETE
      expect(findBadge().props('variant')).toBe('info');
    });

    it('updates badge state when subscription fires', async () => {
      const subscriptionHandler = jest.fn().mockResolvedValue({
        data: {
          securityPolicyScheduleTestRunUpdated: {
            id: TEST_RUN_ID,
            state: 'COMPLETE',
            completed: true,
            startedAt: '2024-01-01T00:00:00Z',
            finishedAt: '2024-01-01T00:05:00Z',
            duration: 300,
            errorMessage: null,
            project: { id: 'gid://gitlab/Project/1', fullPath: 'group/project', name: 'Project' },
          },
        },
      });
      createComponent({
        testRun: { id: TEST_RUN_ID, state: 'RUNNING', completed: false },
        subscriptionHandler,
      });

      expect(findBadge().props('variant')).toBe('info');

      await waitForPromises();

      expect(findBadge().props('variant')).toBe('success');
      expect(findBadge().text()).toBe('Test complete');
    });
  });
});
