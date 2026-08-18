import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import getPipelineQuery from 'ee/merge_requests/reports/queries/get_pipeline.query.graphql';
import PolicyDrawer from 'ee/merge_requests/reports/components/policy_drawer.vue';

Vue.use(VueApollo);

const createMockPolicy = (data = {}) => {
  return {
    enabled: true,
    name: 'policy name',
    description: '',
    yaml: null,
    actionApprovers: [
      {
        allGroups: [],
        roles: [],
        users: [],
      },
    ],
    source: {
      namespace: {
        name: 'Project',
        webUrl: '/namespace/project',
      },
    },
    ...data,
  };
};

describe('Merge request reports policy drawer component', () => {
  let wrapper;
  let getPipelineQueryMock;

  const findSecurityPolicy = () => wrapper.findByTestId('security-policy');
  const findPipeline = () => wrapper.findByTestId('security-pipeline');
  const findTargetPipeline = () => wrapper.findByTestId('target-branch-pipeline');
  const findSourcePipeline = () => wrapper.findByTestId('source-branch-pipeline');

  function createComponent(propsData = {}) {
    getPipelineQueryMock = jest.fn().mockResolvedValue({
      data: { project: { id: 1, pipeline: { id: 1, iid: 1, path: '/' } } },
    });

    const apolloProvider = createMockApollo(
      [[getPipelineQuery, getPipelineQueryMock]],
      {},
      { typePolicies: { Query: { fields: { project: { merge: false } } } } },
    );

    wrapper = mountExtended(PolicyDrawer, {
      apolloProvider,
      provide: { projectPath: 'gitlab-org/gitlab' },
      propsData: {
        open: false,
        targetBranch: 'main',
        sourceBranch: 'feature',
        ...propsData,
      },
    });
  }

  it('does not render content when not opened', () => {
    createComponent();

    expect(findSecurityPolicy().exists()).toBe(false);
  });

  it('does not render content when opened with no policy', () => {
    createComponent({ open: true });

    expect(findSecurityPolicy().exists()).toBe(false);
  });

  it('renders content when opened with policy', () => {
    createComponent({ open: true, policy: createMockPolicy() });

    expect(findSecurityPolicy().exists()).toBe(true);
  });

  it('renders pipeline ID', () => {
    createComponent({
      open: true,
      policy: createMockPolicy(),
      pipeline: { updatedAt: '2024-01-01', iid: '1' },
    });

    expect(findPipeline().text()).toContain('in pipeline #1');
  });

  describe('with comparison pipelines', () => {
    it('fetches source branch and target branch pipelines', async () => {
      createComponent({
        comparisonPipelines: {
          source: ['1'],
          target: ['2'],
        },
      });

      await waitForPromises();

      expect(getPipelineQueryMock).toHaveBeenCalledWith({
        projectPath: 'gitlab-org/gitlab',
        id: '1',
      });
      expect(getPipelineQueryMock).toHaveBeenCalledWith({
        projectPath: 'gitlab-org/gitlab',
        id: '2',
      });
    });

    it('renders comparison pipelines', async () => {
      createComponent({
        open: true,
        policy: createMockPolicy(),
        comparisonPipelines: {
          source: ['1'],
          target: ['2'],
        },
      });

      await waitForPromises();

      expect(findTargetPipeline().text()).toContain('#1');
      expect(findSourcePipeline().text()).toContain('#1');
    });
  });
});
