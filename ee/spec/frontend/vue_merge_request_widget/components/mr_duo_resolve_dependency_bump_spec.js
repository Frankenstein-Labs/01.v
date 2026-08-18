import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MrDuoResolveDependencyBump from 'ee/vue_merge_request_widget/components/mr_duo_resolve_dependency_bump.vue';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import { RESOLVE_DEPENDENCY_BUMP_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import getDependencyBumpBreakingChangesAvailable from 'ee/vue_merge_request_widget/queries/get_dependency_bump_breaking_changes_available.query.graphql';

Vue.use(VueApollo);

describe('MrDuoResolveDependencyBump', () => {
  let wrapper;

  const defaultProps = {
    pipeline: { path: '/group/project/-/pipelines/1', source: 'push' },
    mergeRequestPath: '/group/project/-/merge_requests/1',
    targetProjectFullPath: 'group/project',
    sourceBranch: 'feature',
    iid: 1,
  };

  const mockResponse = (available) => ({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/1',
          duoDependencyBumpBreakingChangesAvailable: available,
        },
      },
    },
  });

  let requestHandler;

  const createComponent = ({ available = true, error = false, props = {} } = {}) => {
    requestHandler = error
      ? jest.fn().mockRejectedValue(new Error('GraphQL error'))
      : jest.fn().mockResolvedValue(mockResponse(available));
    const apolloProvider = createMockApollo([
      [getDependencyBumpBreakingChangesAvailable, requestHandler],
    ]);

    wrapper = shallowMountExtended(MrDuoResolveDependencyBump, {
      apolloProvider,
      propsData: { ...defaultProps, ...props },
    });
  };

  const findAction = () => wrapper.findComponent(DuoWorkflowAction);

  beforeEach(() => {
    window.gon = { gitlab_url: 'https://gitlab.example.com' };
  });

  it('renders the Duo workflow action with the correct props when available', async () => {
    createComponent({ available: true });
    await waitForPromises();

    expect(findAction().exists()).toBe(true);
    expect(findAction().props()).toMatchObject({
      workflowDefinition: 'resolve_dependency_bump/experimental',
      goal: 'https://gitlab.example.com/group/project/-/pipelines/1',
      projectPath: 'group/project',
      sourceBranch: 'feature',
      mergeRequestId: 1,
      agentPrivileges: RESOLVE_DEPENDENCY_BUMP_AGENT_PRIVILEGES,
    });
  });

  it('passes the correct source prop', async () => {
    createComponent({ available: true });
    await waitForPromises();

    expect(findAction().props('source')).toBe('merge_request_dependency_bump');
  });

  it('passes the merge request and pipeline additional context', async () => {
    createComponent({ available: true });
    await waitForPromises();

    const context = findAction().props('additionalContext');
    expect(context).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ Category: 'merge_request' }),
        expect.objectContaining({ Category: 'pipeline' }),
      ]),
    );
  });

  it('does not render the action when not available', async () => {
    createComponent({ available: false });
    await waitForPromises();

    expect(findAction().exists()).toBe(false);
  });

  it('does not render the action when the query errors', async () => {
    createComponent({ error: true });
    await waitForPromises();

    expect(findAction().exists()).toBe(false);
  });

  it('queries availability for the specific merge request', async () => {
    createComponent({ available: true });
    await waitForPromises();

    expect(requestHandler).toHaveBeenCalledWith({
      projectPath: 'group/project',
      iid: '1',
    });
  });

  it('skips the query and does not render the action when the iid is missing', async () => {
    createComponent({ props: { iid: null } });
    await waitForPromises();

    expect(requestHandler).not.toHaveBeenCalled();
    expect(findAction().exists()).toBe(false);
  });
});
