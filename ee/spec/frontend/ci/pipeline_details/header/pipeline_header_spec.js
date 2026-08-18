import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import waitForPromises from 'helpers/wait_for_promises';
import PipelineHeader from '~/ci/pipeline_details/header/pipeline_header.vue';
import getPipelineDetailsQuery from '~/ci/pipeline_details/header/graphql/queries/get_pipeline_header_data.query.graphql';
import pipelineHeaderStatusUpdatedSubscription from '~/ci/pipeline_details/header/graphql/subscriptions/pipeline_header_status_updated.subscription.graphql';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';
import DuoWorkflowAction from 'ee_component/ai/shared/widgets/duo_workflow_action.vue';
import PipelineAgentSessions from 'ee/ci/pipeline_details/header/components/pipeline_agent_sessions.vue';
import HeaderMergeTrainsLink from 'ee/ci/pipeline_details/header/components/header_merge_trains_link.vue';
import {
  pipelineHeaderFinishedComputeMinutes,
  pipelineHeaderRunning,
  pipelineHeaderSuccess,
  pipelineHeaderMergeTrain,
  mockPipelineStatusResponse,
  pipelineHeaderFailed,
} from '../mock_data';

Vue.use(VueApollo);

describe('Pipeline header', () => {
  let wrapper;

  const minutesHandler = jest.fn().mockResolvedValue(pipelineHeaderFinishedComputeMinutes);
  const successHandler = jest.fn().mockResolvedValue(pipelineHeaderSuccess);
  const runningHandler = jest.fn().mockResolvedValue(pipelineHeaderRunning);
  const mergeTrainHandler = jest.fn().mockResolvedValue(pipelineHeaderMergeTrain);
  const subscriptionHandler = jest.fn().mockResolvedValue(mockPipelineStatusResponse);
  const failedHandler = jest.fn().mockResolvedValue(pipelineHeaderFailed);
  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  const findComputeMinutes = () => wrapper.findByTestId('compute-minutes');
  const findMergeTrainsLink = () => wrapper.findComponent(HeaderMergeTrainsLink);

  const defaultHandlers = [
    [getPipelineDetailsQuery, minutesHandler],
    [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
  ];

  const defaultProvideOptions = {
    pipelineIid: 1,
    identityVerificationPath: '#',
    identityVerificationRequired: true,
    mergeTrainsAvailable: true,
    mergeTrainsPath: '/namespace/my-project/-/merge_trains',
    canReadMergeTrain: true,
    paths: {
      pipelinesPath: '/namespace/my-project/-/pipelines',
      fullProject: '/namespace/my-project',
      mergeRequestPath: '',
    },
  };

  const defaultProps = {
    yamlErrors: 'errors',
    trigger: false,
  };

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = ({ handlers = defaultHandlers, provideOptions } = {}) => {
    wrapper = shallowMountExtended(PipelineHeader, {
      provide: { ...defaultProvideOptions, ...provideOptions },
      propsData: defaultProps,
      apolloProvider: createMockApolloProvider(handlers),
      stubs: {
        HeaderMergeTrainsLink,
      },
    });

    return waitForPromises();
  };

  // PipelineAccountVerificationAlert handles its own rendering, we just need to check that the component is
  // mounted regardless what the value of identityVerificationRequired is.
  it.each([true, false])(
    'shows pipeline account verification alert',
    async (identityVerificationRequired) => {
      await createComponent({ provideOptions: { identityVerificationRequired } });

      expect(wrapper.findComponent(PipelineAccountVerificationAlert).exists()).toBe(true);
    },
  );

  it('renders pipeline agent sessions component', async () => {
    await createComponent();

    expect(wrapper.findComponent(PipelineAgentSessions).exists()).toBe(true);
  });

  describe('finished pipeline', () => {
    it('displays compute minutes when not zero', async () => {
      await createComponent();

      expect(findComputeMinutes().text()).toBe('25');
    });

    it('does not display compute minutes when zero', async () => {
      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, successHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });

      expect(findComputeMinutes().exists()).toBe(false);
    });
  });

  describe('running pipeline', () => {
    beforeEach(() => {
      return createComponent({
        handlers: [
          [getPipelineDetailsQuery, runningHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });
    });

    it('does not display compute minutes', () => {
      expect(findComputeMinutes().exists()).toBe(false);
    });
  });

  describe('merge trains link', () => {
    it('should display the link', async () => {
      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, mergeTrainHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });

      expect(findMergeTrainsLink().attributes('href')).toBe(defaultProvideOptions.mergeTrainsPath);
    });

    it('should not display the link', async () => {
      await createComponent();

      expect(findMergeTrainsLink().exists()).toBe(false);
    });
  });

  describe('Duo workflow action', () => {
    beforeEach(() => {
      global.gon = {
        gitlab_url: 'https://gitlab.example.com',
      };
    });

    it('displays Duo workflow action for failed pipelines with ref', async () => {
      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, failedHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });

      const duoAction = findDuoWorkflowAction();
      expect(duoAction.exists()).toBe(true);
      expect(duoAction.props()).toMatchObject({
        projectPath: defaultProvideOptions.paths.fullProject,
        workflowDefinition: 'fix_pipeline/v1',
        goal: expect.stringContaining('https://gitlab.example.com'),
        size: 'medium',
        sourceBranch: 'master',
        agentPrivileges: [
          AGENT_PRIVILEGES.READ_WRITE_FILES,
          AGENT_PRIVILEGES.READ_ONLY_GITLAB,
          AGENT_PRIVILEGES.READ_WRITE_GITLAB,
          AGENT_PRIVILEGES.RUN_COMMANDS,
          AGENT_PRIVILEGES.USE_GIT,
        ],
      });

      expect(duoAction.props('additionalContext')).toEqual([
        {
          Category: 'merge_request',
          Content: JSON.stringify({
            url: '',
          }),
        },
        {
          Category: 'pipeline',
          Content: JSON.stringify({
            source_branch: 'master',
            source: 'push',
          }),
        },
      ]);
    });

    it('includes merge request path in additional context when provided', async () => {
      const mergeRequestPath =
        'https://gitlab.example.com/namespace/my-project/-/merge_requests/123';

      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, failedHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
        provideOptions: {
          paths: {
            pipelinesPath: '/namespace/my-project/-/pipelines',
            fullProject: '/namespace/my-project',
            mergeRequestPath,
          },
        },
      });

      const duoAction = findDuoWorkflowAction();
      expect(duoAction.props('additionalContext')).toEqual([
        {
          Category: 'merge_request',
          Content: JSON.stringify({
            url: mergeRequestPath,
          }),
        },
        {
          Category: 'pipeline',
          Content: JSON.stringify({
            source_branch: 'master',
            source: 'push',
          }),
        },
      ]);
    });

    it('does not display Duo workflow action when pipeline has no branch reference', async () => {
      const failedNoBranchHandler = jest.fn().mockResolvedValue({
        data: {
          project: {
            id: 'gid://gitlab/Project/1',
            pipeline: {
              ...pipelineHeaderFailed.data.project.pipeline,
              ref: null,
              merge_request: null,
            },
          },
        },
      });

      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, failedNoBranchHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });

      expect(findDuoWorkflowAction().exists()).toBe(false);
    });

    it('does not display Duo workflow action for successful pipelines', async () => {
      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, successHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });

      expect(findDuoWorkflowAction().exists()).toBe(false);
    });

    it('does not display Duo workflow action for running pipelines', async () => {
      await createComponent({
        handlers: [
          [getPipelineDetailsQuery, runningHandler],
          [pipelineHeaderStatusUpdatedSubscription, subscriptionHandler],
        ],
      });

      expect(findDuoWorkflowAction().exists()).toBe(false);
    });
  });
});
