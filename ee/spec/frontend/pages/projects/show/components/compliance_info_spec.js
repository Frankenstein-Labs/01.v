import Vue from 'vue';
import VueApollo from 'vue-apollo';
import ComplianceInfo from 'ee_component/pages/projects/show/components/compliance_info.vue';
import projectsComplianceFrameworks from 'ee_component/pages/projects/show/graphql/project_compliance_frameworks.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import FrameworkBadge from 'ee_component/compliance_dashboard/components/shared/framework_badge.vue';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { mockComplianceFrameworks } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ComplianceInfo', () => {
  let wrapper;

  const projectPath = '/mock/project/path/';

  const createMockApolloProvider = (resolverMock) => {
    Vue.use(VueApollo);
    return createMockApollo([[projectsComplianceFrameworks, resolverMock]]);
  };

  const findFrameworkBadges = () => wrapper.findAllComponents(FrameworkBadge);
  const frameworkBadgeAtIndex = (index) =>
    wrapper.findComponentByTestId(`framework-badge-${index}`);
  const findHeading = () => wrapper.find('h5');

  const createComponent = async ({ apolloMock, props = {} } = {}) => {
    const apolloProvider = createMockApolloProvider(apolloMock);
    wrapper = shallowMountExtended(ComplianceInfo, {
      apolloProvider,
      propsData: {
        projectPath,
        complianceCenterPath: `${projectPath}-/security/compliance_dashboard/frameworks`,
        canViewDashboard: true,
        ...props,
      },
    });
    await waitForPromises();
  };

  describe('when compliance frameworks exist', () => {
    describe('when user can view dashboard', () => {
      beforeEach(async () => {
        await createComponent({
          apolloMock: jest.fn().mockResolvedValue({ data: mockComplianceFrameworks }),
          props: { canViewDashboard: true },
        });
      });

      it('renders the heading', () => {
        expect(findHeading().text()).toBe('Compliance frameworks applied');
      });

      it('renders a FrameworkBadge for each framework with details mode', () => {
        expect(findFrameworkBadges()).toHaveLength(2);
        expect(frameworkBadgeAtIndex(0).props()).toMatchObject({
          framework: {
            id: 'gid://gitlab/ComplianceManagement::Framework/1',
            name: 'Framework 1',
            color: '#009966',
            default: false,
          },
          popoverMode: 'details',
          viewDetailsUrl:
            'http://test.host/mock/project/path/-/security/compliance_dashboard/frameworks?id=1',
        });

        expect(frameworkBadgeAtIndex(1).props()).toMatchObject({
          framework: {
            id: 'gid://gitlab/ComplianceManagement::Framework/2',
            name: 'Framework 2',
            color: '#336699',
            default: true,
          },
          popoverMode: 'details',
          viewDetailsUrl:
            'http://test.host/mock/project/path/-/security/compliance_dashboard/frameworks?id=2',
        });
      });
    });

    describe('when user cannot view dashboard', () => {
      beforeEach(async () => {
        await createComponent({
          apolloMock: jest.fn().mockResolvedValue({ data: mockComplianceFrameworks }),
          props: { canViewDashboard: false },
        });
      });

      it('renders framework badges in disabled mode', () => {
        findFrameworkBadges().wrappers.forEach((badge) => {
          expect(badge.props('popoverMode')).toBe('disabled');
        });
      });
    });
  });

  describe('when no compliance frameworks exist', () => {
    jest.spyOn(Sentry, 'captureException');
    beforeEach(async () => {
      await createComponent({
        apolloMock: jest.fn().mockResolvedValue({
          data: {
            project: {
              id: 'project-1',
              complianceFrameworks: {
                nodes: [],
              },
            },
          },
        }),
      });
    });

    it('does not render the heading', () => {
      expect(findHeading().exists()).toBe(false);
    });

    it('does not render any FrameworkBadge components', () => {
      expect(findFrameworkBadges()).toHaveLength(0);
    });
  });

  describe('when Apollo query fails', () => {
    it('logs an error and does not render any FrameworkBadge components', async () => {
      const mockError = new Error('Apollo query failed');

      await createComponent({
        apolloMock: jest.fn().mockRejectedValue(mockError),
      });
      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      expect(findFrameworkBadges()).toHaveLength(0);
    });
  });
});
