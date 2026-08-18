import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlButton, GlFormInput, GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TestRunsTab from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/test_runs_tab.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import projectPolicyTestRunsQuery from 'ee/security_orchestration/graphql/queries/project_policy_test_runs.query.graphql';
import groupPolicyTestRunsQuery from 'ee/security_orchestration/graphql/queries/group_policy_test_runs.query.graphql';
import spepTestRunMutation from 'ee/security_orchestration/graphql/mutations/spep_test_run.mutation.graphql';
import spepTestRunUpdatedSubscription from 'ee/security_orchestration/graphql/subscriptions/spep_test_run_updated.subscription.graphql';

Vue.use(VueApollo);

describe('TestRunsTab', () => {
  let wrapper;
  let projectQueryHandler;
  let groupQueryHandler;
  let mutationHandler;

  const mockTestRun = {
    __typename: 'PolicyScheduleTestRun',
    id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/1',
    state: 'COMPLETE',
    completed: true,
    startedAt: '2024-01-01T00:00:00Z',
    finishedAt: '2024-01-01T00:05:00Z',
    duration: 300,
    errorMessage: null,
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      fullPath: 'gitlab-org/gitlab',
      name: 'GitLab',
    },
  };

  const mockPolicy = {
    id: 'gid://gitlab/Security::Policy/1',
    name: 'Test Policy',
    yaml: 'name: Test Policy',
    source: null,
  };

  const mockInheritedPolicy = {
    ...mockPolicy,
    source: { inherited: true, namespace: { id: '1', fullPath: 'gitlab-org', name: 'GitLab Org' } },
  };

  const mockTestRunFromDifferentProject = {
    ...mockTestRun,
    id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/2',
    state: 'RUNNING',
    completed: false,
    finishedAt: null,
    duration: null,
    project: { id: 'gid://gitlab/Project/2', fullPath: 'gitlab-org/other', name: 'Other' },
  };

  const createMockQueryResponse = (
    testRun = null,
    { linkedProjectsCount = null, scheduleTimeWindowSeconds = null } = {},
  ) => ({
    data: {
      namespace: {
        id: '1',
        securityPolicies: {
          nodes: [
            {
              id: 'gid://gitlab/Security::Policy/1',
              name: 'Test Policy',
              linkedProjectsCount,
              policyAttributes: {
                __typename: 'PipelineExecutionScheduledPolicyAttributesType',
                scheduleTimeWindowSeconds,
              },
              testRuns: {
                nodes: testRun ? [testRun] : [],
              },
            },
          ],
        },
      },
    },
  });

  const createMockQueryResponseWithRuns = (testRuns = []) => ({
    data: {
      namespace: {
        id: '1',
        securityPolicies: {
          nodes: [
            {
              id: 'gid://gitlab/Security::Policy/1',
              name: 'Test Policy',
              linkedProjectsCount: null,
              policyAttributes: {
                __typename: 'PipelineExecutionScheduledPolicyAttributesType',
                scheduleTimeWindowSeconds: null,
              },
              testRuns: { nodes: testRuns },
            },
          ],
        },
      },
    },
  });

  const createMockMutationResponse = (testRun = mockTestRun, errors = []) => ({
    data: {
      pipelineExecutionSchedulePolicyTestRun: {
        testRun,
        errors,
      },
    },
  });

  const createComponent = ({
    provide = {},
    policy = mockPolicy,
    testRun = mockTestRun,
    queryResponse = null,
    isGroup = false,
    mutationResponse = createMockMutationResponse(),
    subscriptionHandler = jest.fn(),
    estimateData = {},
    activeTestRun = null,
  } = {}) => {
    const namespaceType = isGroup ? NAMESPACE_TYPES.GROUP : NAMESPACE_TYPES.PROJECT;
    const resolvedQueryResponse = queryResponse ?? createMockQueryResponse(testRun, estimateData);
    projectQueryHandler = jest.fn().mockResolvedValue(resolvedQueryResponse);
    groupQueryHandler = jest.fn().mockResolvedValue(resolvedQueryResponse);
    mutationHandler = jest.fn().mockResolvedValue(mutationResponse);

    const mockApollo = createMockApollo([
      [projectPolicyTestRunsQuery, projectQueryHandler],
      [groupPolicyTestRunsQuery, groupQueryHandler],
      [spepTestRunMutation, mutationHandler],
      [spepTestRunUpdatedSubscription, subscriptionHandler],
    ]);

    wrapper = shallowMountExtended(TestRunsTab, {
      apolloProvider: mockApollo,
      propsData: {
        policy,
        activeTestRun,
      },
      provide: {
        namespaceType,
        namespacePath: isGroup ? 'gitlab-org' : 'gitlab-org/gitlab',
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findTitle = () => wrapper.findByTestId('test-runs-title');
  const findDescription = () => wrapper.findByTestId('test-runs-description');
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTestRunResults = () => wrapper.findByTestId('test-run-results');
  const findTestRunDetails = () => wrapper.findByTestId('test-run-details');
  const findNoTestRun = () => wrapper.findByTestId('no-test-runs');
  const findRunTestButton = () => wrapper.findComponent(GlButton);
  const findProjectSelectorSection = () => wrapper.findByTestId('project-selector-section');
  const findProjectSelector = () => wrapper.findComponent(GroupProjectsDropdown);
  const findProjectPathDisplay = () => wrapper.findComponent(GlFormInput);

  describe('default rendering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the title', () => {
      expect(findTitle().exists()).toBe(true);
      expect(findTitle().text()).toBe('Test runs');
    });

    it('renders the description', () => {
      expect(findDescription().exists()).toBe(true);
    });

    it('renders the run test button', () => {
      expect(findRunTestButton().exists()).toBe(true);
      expect(findRunTestButton().text()).toBe('Begin test run');
    });

    it('does not render error alert initially', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('loading state', () => {
    it('shows loading icon when fetching test run data', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTestRunResults().exists()).toBe(false);
      expect(findNoTestRun().exists()).toBe(false);
    });
  });

  describe('with test run', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders test run results section', () => {
      expect(findTestRunResults().exists()).toBe(true);
    });

    it('displays test run information', () => {
      const testRunText = findTestRunDetails().text();

      expect(testRunText).toContain('Complete');
      expect(testRunText).toContain('gitlab-org/gitlab');
    });

    it('does not show no test run message', () => {
      expect(findNoTestRun().exists()).toBe(false);
    });

    it('does not show loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('without test run', () => {
    it('shows generic message for direct policy', async () => {
      createComponent({ testRun: null });
      await waitForPromises();

      expect(findNoTestRun().text()).toBe('No test runs found for this policy.');
    });

    it('shows project-specific message for inherited policy', async () => {
      createComponent({ testRun: null, policy: mockInheritedPolicy });
      await waitForPromises();

      expect(findNoTestRun().text()).toBe('No test runs found for this policy on this project.');
    });

    it('does not render test run results section', async () => {
      createComponent({ testRun: null });
      await waitForPromises();

      expect(findTestRunResults().exists()).toBe(false);
    });
  });

  describe('with test run error message', () => {
    it('displays error message when provided', async () => {
      createComponent({
        testRun: {
          ...mockTestRun,
          state: 'FAILED',
          errorMessage: 'Pipeline execution failed',
        },
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('Pipeline execution failed');
    });

    it('displays generic error message when errorMessage is null', async () => {
      createComponent({
        testRun: {
          ...mockTestRun,
          state: 'FAILED',
          errorMessage: null,
        },
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain(
        'The test run failed for an unspecified reason',
      );
    });
  });

  describe('when policy is not found in query result', () => {
    it('shows no test runs message', async () => {
      const emptyPoliciesResponse = {
        data: { namespace: { id: '1', securityPolicies: { nodes: [] } } },
      };
      createComponent({ queryResponse: emptyPoliciesResponse });
      await waitForPromises();

      expect(findNoTestRun().exists()).toBe(true);
      expect(findTestRunResults().exists()).toBe(false);
    });
  });

  describe('with activeTestRun prop', () => {
    const pendingTestRun = {
      ...mockTestRun,
      id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/100',
      state: 'PENDING',
      completed: false,
      finishedAt: null,
      duration: null,
    };

    it('renders test run details immediately while the query is loading', () => {
      createComponent({ activeTestRun: pendingTestRun });

      expect(findTestRunResults().exists()).toBe(true);
      expect(findTestRunDetails().text()).toContain('Pending');
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findNoTestRun().exists()).toBe(false);
    });

    it('renders details from activeTestRun when the query response is empty', async () => {
      const emptyResponse = createMockQueryResponseWithRuns([]);
      createComponent({ activeTestRun: pendingTestRun, queryResponse: emptyResponse });
      await waitForPromises();

      expect(findTestRunResults().exists()).toBe(true);
      expect(findTestRunDetails().text()).toContain('Pending');
      expect(findNoTestRun().exists()).toBe(false);
    });

    it('keeps the activeTestRun when the query returns a different (stale) run id', async () => {
      const staleRun = {
        ...mockTestRun,
        id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/1',
        state: 'COMPLETE',
      };
      createComponent({
        activeTestRun: pendingTestRun,
        queryResponse: createMockQueryResponse(staleRun),
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('Pending');
      expect(findTestRunDetails().text()).not.toContain('Complete');
    });

    it('adopts query data when its run id matches activeTestRun (state may be fresher)', async () => {
      const advanced = { ...pendingTestRun, state: 'RUNNING' };
      createComponent({
        activeTestRun: pendingTestRun,
        queryResponse: createMockQueryResponse(advanced),
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('Running');
    });

    it('subscribes to updates for the activeTestRun id without waiting for the query', () => {
      const subscriptionHandler = jest.fn().mockResolvedValue({
        data: { securityPolicyScheduleTestRunUpdated: null },
      });
      createComponent({ activeTestRun: pendingTestRun, subscriptionHandler });

      expect(subscriptionHandler).toHaveBeenCalledWith({ testRunId: pendingTestRun.id });
    });

    it('updates the rendered run when activeTestRun changes to a different id', async () => {
      createComponent({ activeTestRun: null, queryResponse: createMockQueryResponseWithRuns([]) });
      await waitForPromises();
      expect(findNoTestRun().exists()).toBe(true);

      await wrapper.setProps({ activeTestRun: pendingTestRun });

      expect(findTestRunResults().exists()).toBe(true);
      expect(findTestRunDetails().text()).toContain('Pending');
    });
  });

  describe('at project level', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders project selector section with disabled input showing current project', () => {
      expect(findProjectSelectorSection().exists()).toBe(true);
      expect(findProjectSelector().exists()).toBe(false);
      expect(findProjectPathDisplay().exists()).toBe(true);
      expect(findProjectPathDisplay().attributes('value')).toBe('gitlab-org/gitlab');
      expect(findProjectPathDisplay().attributes('disabled')).toBeDefined();
    });

    it('enables run test button by default', () => {
      expect(findRunTestButton().attributes('disabled')).toBeUndefined();
    });

    describe('inherited policy', () => {
      it('only shows test run belonging to the current project', async () => {
        createComponent({
          policy: mockInheritedPolicy,
          queryResponse: createMockQueryResponseWithRuns([
            mockTestRunFromDifferentProject,
            mockTestRun,
          ]),
        });
        await waitForPromises();

        expect(findTestRunDetails().text()).toContain('Complete');
        expect(findTestRunDetails().text()).not.toContain('Running');
      });
    });

    describe('direct policy', () => {
      it('returns the most recent test run without project filtering', async () => {
        createComponent({
          queryResponse: createMockQueryResponseWithRuns([
            mockTestRunFromDifferentProject,
            mockTestRun,
          ]),
        });
        await waitForPromises();

        expect(findTestRunDetails().text()).toContain('Running');
      });
    });
  });

  describe('at group level', () => {
    beforeEach(async () => {
      createComponent({ isGroup: true });
      await waitForPromises();
    });

    it('renders project selector', () => {
      expect(findProjectSelectorSection().exists()).toBe(true);
      expect(findProjectSelector().exists()).toBe(true);
    });

    it('disables run test button when no project selected', () => {
      expect(findRunTestButton().props('disabled')).toBe(true);
    });

    it('enables run test button when project is selected', async () => {
      await findProjectSelector().vm.$emit('select', {
        id: '1',
        name: 'Test Project',
        fullPath: 'gitlab-org/test',
      });

      expect(findRunTestButton().attributes('disabled')).toBeUndefined();
    });
  });

  describe('duration formatting', () => {
    it('formats duration in minutes', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 120 },
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('2 minutes');
    });

    it('formats duration in seconds for short durations', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 30 },
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('30 seconds');
    });

    it('handles zero duration', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 0 },
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('0 seconds');
    });
  });

  describe('state formatting', () => {
    it.each([
      ['PENDING', 'Pending'],
      ['RUNNING', 'Running'],
      ['COMPLETE', 'Complete'],
      ['FAILED', 'Failed'],
    ])('formats %s state as %s', async (state, expected) => {
      createComponent({
        testRun: { ...mockTestRun, state },
      });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain(expected);
    });
  });

  describe('running a test', () => {
    it('shows loading state when test is running', async () => {
      createComponent({ testRun: null });
      await waitForPromises();

      expect(findRunTestButton().attributes('loading')).toBeUndefined();

      await findRunTestButton().vm.$emit('click');

      expect(findRunTestButton().attributes('loading')).toBe('true');
    });

    it('prevents multiple simultaneous test runs', async () => {
      createComponent({ testRun: null });
      await waitForPromises();

      await findRunTestButton().vm.$emit('click');
      expect(findRunTestButton().props('disabled')).toBe(true);
    });

    it.each(['RUNNING', 'PENDING'])(
      'disables button when a test run is already in %s state',
      async (state) => {
        createComponent({ testRun: { ...mockTestRun, state, completed: false } });
        await waitForPromises();

        expect(findRunTestButton().props('disabled')).toBe(true);
      },
    );

    it('calls mutation with correct variables at project level', async () => {
      createComponent({ testRun: null });
      await waitForPromises();

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        policyId: mockPolicy.id,
        projectPath: 'gitlab-org/gitlab',
      });
    });

    it('calls mutation with selected project path at group level', async () => {
      createComponent({ testRun: null, isGroup: true });
      await waitForPromises();

      await findProjectSelector().vm.$emit('select', {
        id: '1',
        name: 'Test Project',
        fullPath: 'gitlab-org/test-project',
      });

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        policyId: mockPolicy.id,
        projectPath: 'gitlab-org/test-project',
      });
    });

    it('updates liveTestRun directly from mutation result without refetching', async () => {
      createComponent({ testRun: null });
      await waitForPromises();

      expect(findTestRunDetails().exists()).toBe(false);
      expect(projectQueryHandler).toHaveBeenCalledTimes(1);

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(findTestRunDetails().exists()).toBe(true);
      expect(projectQueryHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('subscription', () => {
    const mockRunningTestRun = {
      ...mockTestRun,
      state: 'RUNNING',
      completed: false,
      finishedAt: null,
      duration: null,
    };

    const mockPendingTestRun = {
      ...mockTestRun,
      state: 'PENDING',
      completed: false,
      startedAt: null,
      finishedAt: null,
      duration: null,
    };

    it.each([
      ['RUNNING', mockRunningTestRun],
      ['PENDING', mockPendingTestRun],
    ])('subscribes when test run is in %s state', async (state, testRun) => {
      const subscriptionHandler = jest.fn().mockResolvedValue({});
      createComponent({
        testRun,
        subscriptionHandler,
      });
      await waitForPromises();

      expect(subscriptionHandler).toHaveBeenCalledWith({ testRunId: testRun.id });
    });

    it('does not subscribe when test run is already completed', async () => {
      const subscriptionHandler = jest.fn();
      createComponent({ testRun: mockTestRun, subscriptionHandler });
      await waitForPromises();

      expect(subscriptionHandler).not.toHaveBeenCalled();
    });

    it('does not subscribe when there is no test run', async () => {
      const subscriptionHandler = jest.fn();
      createComponent({ testRun: null, subscriptionHandler });
      await waitForPromises();

      expect(subscriptionHandler).not.toHaveBeenCalled();
    });

    it('updates test run data when subscription fires', async () => {
      const completedRun = {
        ...mockTestRun,
        state: 'COMPLETE',
        completed: true,
        finishedAt: '2024-01-01T00:05:00Z',
        duration: 300,
      };
      const subscriptionHandler = jest.fn().mockResolvedValue({
        data: { securityPolicyScheduleTestRunUpdated: completedRun },
      });
      createComponent({ testRun: mockRunningTestRun, subscriptionHandler });
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('Complete');
    });
  });

  describe('time estimate display', () => {
    const findLinkedProjectsCount = () => wrapper.findByTestId('linked-projects-count');
    const findEstimatedTotalDuration = () => wrapper.findByTestId('estimated-total-duration');
    const findPipelinesPerHour = () => wrapper.findByTestId('pipelines-per-hour');

    it('shows all three estimate items when test run is complete and estimate data is available', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 5, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findLinkedProjectsCount().text()).toContain('Linked projects: 5');
      expect(findEstimatedTotalDuration().text()).toContain('Max estimated total run time');
      expect(findPipelinesPerHour().text()).toContain(
        'Max estimated rate: approximately 5 pipelines per hour',
      );
    });

    it('hides all estimate items when linkedProjectsCount is null', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: null, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findLinkedProjectsCount().exists()).toBe(false);
      expect(findEstimatedTotalDuration().exists()).toBe(false);
      expect(findPipelinesPerHour().exists()).toBe(false);
    });

    it('hides all estimate items when linkedProjectsCount is 0', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 0, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findLinkedProjectsCount().exists()).toBe(false);
      expect(findEstimatedTotalDuration().exists()).toBe(false);
      expect(findPipelinesPerHour().exists()).toBe(false);
    });

    it('shows linked projects but hides duration and rate when test run has no duration', async () => {
      createComponent({
        testRun: { ...mockTestRun, state: 'RUNNING', duration: null, finishedAt: null },
        estimateData: { linkedProjectsCount: 5, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findLinkedProjectsCount().text()).toContain('Linked projects: 5');
      expect(findEstimatedTotalDuration().exists()).toBe(false);
      expect(findPipelinesPerHour().exists()).toBe(false);
    });

    it('shows estimated total run time when duration is 0', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 0 },
        estimateData: { linkedProjectsCount: 5, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findEstimatedTotalDuration().exists()).toBe(true);
    });

    it('shows estimates for failed test runs that recorded a duration', async () => {
      createComponent({
        testRun: { ...mockTestRun, state: 'FAILED', duration: 60 },
        estimateData: { linkedProjectsCount: 5, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findEstimatedTotalDuration().exists()).toBe(true);
      expect(findPipelinesPerHour().exists()).toBe(true);
    });

    it('hides pipelines-per-hour when scheduleTimeWindowSeconds is null', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 5, scheduleTimeWindowSeconds: null },
      });
      await waitForPromises();

      expect(findLinkedProjectsCount().text()).toContain('Linked projects: 5');
      expect(findEstimatedTotalDuration().exists()).toBe(true);
      expect(findPipelinesPerHour().exists()).toBe(false);
    });

    it('formats sub-1 pipelines-per-hour rate with one decimal', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 1, scheduleTimeWindowSeconds: 7200 },
      });
      await waitForPromises();

      expect(findPipelinesPerHour().text()).toContain(
        'Max estimated rate: approximately 0.5 pipelines per hour',
      );
    });

    it('rounds integer pipelines-per-hour rates above 1', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 5, scheduleTimeWindowSeconds: 2700 },
      });
      await waitForPromises();

      expect(findPipelinesPerHour().text()).toContain(
        'Max estimated rate: approximately 7 pipelines per hour',
      );
    });

    it('uses singular pipeline label when rate rounds to exactly 1', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 1, scheduleTimeWindowSeconds: 3600 },
      });
      await waitForPromises();

      expect(findPipelinesPerHour().text()).toContain(
        'Max estimated rate: approximately 1 pipeline per hour',
      );
    });

    it('hides pipelines-per-hour row when rate would round to 0.0', async () => {
      createComponent({
        testRun: { ...mockTestRun, duration: 60 },
        estimateData: { linkedProjectsCount: 1, scheduleTimeWindowSeconds: 3600000 },
      });
      await waitForPromises();

      expect(findPipelinesPerHour().exists()).toBe(false);
    });

    it('hides all estimate items when estimate data is absent', async () => {
      createComponent({ testRun: { ...mockTestRun, duration: 60 } });
      await waitForPromises();

      expect(findLinkedProjectsCount().exists()).toBe(false);
      expect(findEstimatedTotalDuration().exists()).toBe(false);
      expect(findPipelinesPerHour().exists()).toBe(false);
    });

    it('prefers liveTestRun over query data when computing the displayed test run', async () => {
      const queryRun = {
        ...mockTestRun,
        id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/old',
        state: 'COMPLETE',
        completed: true,
        project: {
          __typename: 'Project',
          id: 'gid://gitlab/Project/1',
          fullPath: 'cached/query/path',
          name: 'Cached',
        },
      };
      const liveRun = {
        ...mockTestRun,
        id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/live',
        state: 'RUNNING',
        completed: false,
        project: {
          __typename: 'Project',
          id: 'gid://gitlab/Project/2',
          fullPath: 'live/run/path',
          name: 'Live',
        },
      };
      createComponent({
        testRun: queryRun,
        mutationResponse: createMockMutationResponse(liveRun),
      });
      await waitForPromises();
      expect(findTestRunDetails().text()).toContain('cached/query/path');

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(findTestRunDetails().text()).toContain('live/run/path');
      expect(findTestRunDetails().text()).not.toContain('cached/query/path');
    });
  });

  describe('error handling', () => {
    it('shows error alert when mutation returns errors', async () => {
      createComponent({
        testRun: null,
        mutationResponse: createMockMutationResponse(null, ['Policy not found']),
      });
      await waitForPromises();

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Policy not found');
    });

    it('shows error alert when mutation throws', async () => {
      createComponent({ testRun: null });
      mutationHandler.mockRejectedValueOnce(new Error('Network error'));
      await waitForPromises();

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Network error');
    });

    it('can dismiss error alert', async () => {
      createComponent({
        testRun: null,
        mutationResponse: createMockMutationResponse(null, ['Policy not found']),
      });
      await waitForPromises();

      await findRunTestButton().vm.$emit('click');
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);

      await findErrorAlert().vm.$emit('dismiss');

      expect(findErrorAlert().exists()).toBe(false);
    });
  });
});
