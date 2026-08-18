import { GlBadge, GlSprintf } from '@gitlab/ui';
import mockDeploymentFixture from 'test_fixtures/ee/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import mockEnvironmentFixture from 'test_fixtures/graphql/deployments/graphql/queries/environment.query.graphql.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DeploymentHeader from '~/deployments/components/deployment_header.vue';

const {
  data: {
    project: { deployment },
  },
} = mockDeploymentFixture;
const {
  data: {
    project: { environment },
  },
} = mockEnvironmentFixture;

describe('~/deployments/components/deployment_header.vue', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(DeploymentHeader, {
      propsData: {
        deployment,
        environment,
        loading: false,
        ...propsData,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findNeedsApprovalBadge = () => wrapper.findComponent(GlBadge);

  it('shows a badge when the deployment needs approval', () => {
    createComponent({
      propsData: {
        deployment: {
          ...deployment,
          status: 'RUNNING',
          approvalSummary: { status: 'PENDING_APPROVAL' },
        },
      },
    });

    expect(findNeedsApprovalBadge().text()).toBe('Needs Approval');
  });

  it('hides the  badge when the deployment does not need approval', () => {
    createComponent({
      propsData: {
        deployment: {
          ...deployment,
          status: 'RUNNING',
          approvalSummary: { status: 'APPROVED' },
        },
      },
    });

    expect(findNeedsApprovalBadge().exists()).toBe(false);
  });

  it('hides the  badge when the deployment is finished', () => {
    createComponent({
      propsData: {
        deployment: {
          ...deployment,
          status: 'SUCCESS',
          approvalSummary: { status: 'PENDING_APPROVAL' },
        },
      },
    });

    expect(findNeedsApprovalBadge().exists()).toBe(false);
  });

  describe('when the release tag', () => {
    describe('exists', () => {
      const release = {
        name: 'Test Release',
        descriptionHtml: 'Test Release Description',
        links: {
          selfUrl: 'http://gitlab.test/test/test/-/releases/1.0.0',
        },
      };

      beforeEach(() => {
        createComponent({ propsData: { deployment, release } });
      });

      it('shows the release title', () => {
        const link = wrapper.findByTestId('release-page-link');

        expect(link.text()).toBe(release.name);
        expect(link.attributes('href')).toBe(release.links.selfUrl);
        expect(wrapper.findByText('release notes:').exists()).toBe(true);
      });

      it('shows the release description', () => {
        expect(wrapper.findByTestId('release-description-content').text()).toBe(
          release.descriptionHtml,
        );
      });
    });

    describe('does not exist', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not show the release title', () => {
        expect(wrapper.findByTestId('release-page-link').exists()).toBe(false);
        expect(wrapper.findByText('release notes:').exists()).toBe(false);
      });

      it('does not show the release description', () => {
        expect(wrapper.findByTestId('release-description-content').exists()).toBe(false);
      });
    });
  });
});
