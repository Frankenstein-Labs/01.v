import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import MrWidgetPipelineDuoAction from 'ee/vue_merge_request_widget/components/mr_duo_fix_pipeline.vue';
import getFixPipelineWorkflowsQuery from 'ee/vue_merge_request_widget/queries/get_fix_pipeline_workflows.query.graphql';
import { AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';

Vue.use(VueApollo);

describe('MrWidgetPipelineDuoAction', () => {
  let wrapper;
  let apolloProvider;

  const defaultProps = {
    pipeline: {
      id: 172,
      path: '/gitlab-org/gitlab/pipelines/172',
      source: 'merge_request_event',
    },
    targetProjectFullPath: 'gitlab-org/gitlab',
    sourceBranch: 'feature-branch',
    mergeRequestPath: '/gitlab-org/gitlab/-/merge_requests/1',
  };

  const mockEmptyWorkflowsResponse = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowWorkflows: {
          edges: [],
        },
      },
    },
  };

  const mockExistingWorkflowResponse = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowWorkflows: {
          edges: [{ node: { id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/42' } }],
        },
      },
    },
  };

  const emptyWorkflowsHandler = jest.fn().mockResolvedValue(mockEmptyWorkflowsResponse);
  const existingWorkflowHandler = jest.fn().mockResolvedValue(mockExistingWorkflowResponse);

  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  const createMockApolloProvider = (
    requestHandlers = [[getFixPipelineWorkflowsQuery, emptyWorkflowsHandler]],
  ) => {
    return createMockApollo(requestHandlers);
  };

  const createWrapper = ({ props = {}, requestHandlers } = {}) => {
    apolloProvider = createMockApolloProvider(requestHandlers);

    wrapper = shallowMount(MrWidgetPipelineDuoAction, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider,
    });
  };

  beforeEach(() => {
    window.gon = { gitlab_url: 'http://test.host' };
  });

  afterEach(() => {
    delete window.gon;
  });

  describe('rendering', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the DuoWorkflowAction component', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
      expect(findDuoWorkflowAction().text()).toBe('Fix pipeline with Duo');
    });

    it('passes the correct source prop', () => {
      expect(findDuoWorkflowAction().props('source')).toBe('merge_request_fix_pipeline');
    });

    it('passes the expected props to DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().props()).toMatchObject({
        workflowDefinition: 'fix_pipeline/v1',
        goal: 'http://test.host/gitlab-org/gitlab/pipelines/172',
        projectPath: 'gitlab-org/gitlab',
        hoverMessage: 'Fix pipeline with Duo',
        workItemIid: null,
        sourceBranch: 'feature-branch',
        agentPrivileges: [
          AGENT_PRIVILEGES.READ_WRITE_FILES,
          AGENT_PRIVILEGES.READ_ONLY_GITLAB,
          AGENT_PRIVILEGES.READ_WRITE_GITLAB,
          AGENT_PRIVILEGES.RUN_COMMANDS,
          AGENT_PRIVILEGES.USE_GIT,
        ],
        additionalContext: [
          {
            Category: 'merge_request',
            Content: JSON.stringify({
              url: 'http://test.host/gitlab-org/gitlab/-/merge_requests/1',
            }),
          },
          {
            Category: 'pipeline',
            Content: JSON.stringify({
              source_branch: 'feature-branch',
              source: 'merge_request_event',
            }),
          },
        ],
        category: 'primary',
        size: 'small',
        variant: 'default',
        promptValidatorRegex: null,
        renderAs: 'button',
      });
    });
  });

  describe('workflows query', () => {
    it('queries duoWorkflowWorkflows with the project path and pipeline URL on mount', async () => {
      createWrapper();

      await waitForPromises();

      expect(emptyWorkflowsHandler).toHaveBeenCalledTimes(1);
      expect(emptyWorkflowsHandler).toHaveBeenCalledWith({
        projectPath: 'gitlab-org/gitlab',
        search: 'http://test.host/gitlab-org/gitlab/pipelines/172',
      });
    });
  });

  describe('when no workflows exist for this pipeline', () => {
    beforeEach(async () => {
      createWrapper();

      await waitForPromises();
    });

    it('leaves the action enabled', () => {
      expect(findDuoWorkflowAction().attributes('disabled')).toBeUndefined();
    });

    it('passes the default hover message', () => {
      expect(findDuoWorkflowAction().props('hoverMessage')).toBe('Fix pipeline with Duo');
    });
  });

  describe('when a workflow already exists for this pipeline', () => {
    beforeEach(async () => {
      createWrapper({
        requestHandlers: [[getFixPipelineWorkflowsQuery, existingWorkflowHandler]],
      });

      await waitForPromises();
    });

    it('disables the action', () => {
      expect(findDuoWorkflowAction().attributes('disabled')).toBeDefined();
    });

    it('passes the disabled state hover message', () => {
      expect(findDuoWorkflowAction().props('hoverMessage')).toBe(
        'A Fix pipeline session is already running or completed for this pipeline. Push a new commit or re-run the pipeline to try again.',
      );
    });
  });

  describe('when the user starts a flow', () => {
    beforeEach(async () => {
      createWrapper();

      await waitForPromises();
    });

    it('starts with the action enabled', () => {
      expect(findDuoWorkflowAction().attributes('disabled')).toBeUndefined();
    });

    it('disables the action immediately when agent-flow-started is emitted', async () => {
      findDuoWorkflowAction().vm.$emit('agent-flow-started');

      await nextTick();

      expect(findDuoWorkflowAction().attributes('disabled')).toBeDefined();
    });
  });
});
