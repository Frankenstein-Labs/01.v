import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMount } from '@vue/test-utils';
import mockDeploymentFixture from 'test_fixtures/ee/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import mockEnvironmentFixture from 'test_fixtures/graphql/deployments/graphql/queries/environment.query.graphql.json';
import ShowDeployment from '~/deployments/components/show_deployment.vue';
import deploymentQuery from '~/deployments/graphql/queries/deployment.query.graphql';
import environmentQuery from '~/deployments/graphql/queries/environment.query.graphql';
import releaseQuery from '~/deployments/graphql/queries/release.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import DeploymentTimeline from 'ee/deployments/components/deployment_timeline.vue';
import DeploymentApprovals from 'ee/deployments/components/deployment_approvals.vue';

Vue.use(VueApollo);

const { deployment } = mockDeploymentFixture.data.project;
const PROJECT_PATH = 'group/project';
const ENVIRONMENT_NAME = mockEnvironmentFixture.data.project.environment.name;
const DEPLOYMENT_IID = deployment.iid;
const GRAPHQL_ETAG_KEY = 'project/environments';
const RELEASE_QUERY_RESPONSE_MOCK = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      release: {
        id: 'gid://gitlab/Release/1',
        name: 'Test Release',
        descriptionHtml: '<p>Test Release Description</p>',
        links: {
          selfUrl: 'http://gitlab.test/test/test/-/releases/1.0.0',
        },
      },
    },
  },
};

describe('~/deployments/components/show_deployment.vue', () => {
  let wrapper;
  let mockApollo;
  let deploymentQueryResponse;
  let environmentQueryResponse;
  let releaseQueryResponse;

  beforeEach(() => {
    deploymentQueryResponse = jest.fn();
    environmentQueryResponse = jest.fn();
    releaseQueryResponse = jest.fn();
  });

  const createComponent = () => {
    mockApollo = createMockApollo([
      [deploymentQuery, deploymentQueryResponse],
      [environmentQuery, environmentQueryResponse],
      [releaseQuery, releaseQueryResponse],
    ]);
    wrapper = shallowMount(ShowDeployment, {
      apolloProvider: mockApollo,
      provide: {
        projectPath: PROJECT_PATH,
        environmentName: ENVIRONMENT_NAME,
        deploymentIid: DEPLOYMENT_IID,
        graphqlEtagKey: GRAPHQL_ETAG_KEY,
      },
      stubs: {
        DeploymentApprovals,
        DeploymentTimeline,
      },
    });
    return waitForPromises();
  };

  describe('default behavior', () => {
    beforeEach(async () => {
      deploymentQueryResponse.mockResolvedValue(mockDeploymentFixture);
      environmentQueryResponse.mockResolvedValue(mockEnvironmentFixture);
      await createComponent();
    });

    it('shows the deployment approval table', () => {
      expect(wrapper.findComponent(DeploymentApprovals).props()).toEqual({
        approvalSummary: deployment.approvalSummary,
        deployment,
      });
    });

    it('shows the deployment approvals timeline', () => {
      expect(wrapper.findComponent(DeploymentTimeline).props()).toEqual({
        approvalSummary: deployment.approvalSummary,
      });
    });

    it('refetches the deployment on approval change', async () => {
      deploymentQueryResponse.mockClear();
      wrapper.findComponent(DeploymentApprovals).vm.$emit('change');
      await waitForPromises();

      expect(deploymentQueryResponse).toHaveBeenCalled();
    });
  });

  describe('when the deployment release tag', () => {
    beforeEach(() => {
      environmentQueryResponse.mockResolvedValue(mockEnvironmentFixture);
    });

    describe('is absent', () => {
      it('does not fetch the release data', async () => {
        deploymentQueryResponse.mockResolvedValue(mockDeploymentFixture);

        createComponent();
        await waitForPromises();

        expect(releaseQueryResponse).not.toHaveBeenCalled();
      });
    });

    describe('is present', () => {
      it('fetches the release data', async () => {
        mockDeploymentFixture.data.project.deployment.tag = true;
        deploymentQueryResponse.mockResolvedValue(mockDeploymentFixture);
        releaseQueryResponse.mockResolvedValue(RELEASE_QUERY_RESPONSE_MOCK);

        createComponent();
        await waitForPromises();

        expect(releaseQueryResponse).toHaveBeenCalled();
      });
    });
  });
});
