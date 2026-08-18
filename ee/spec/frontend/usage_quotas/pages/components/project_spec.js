import { GlBadge, GlAvatar } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { removeWhitespace } from 'helpers/text_helper';
import ProjectView from 'ee/usage_quotas/pages/components/project.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { GROUP_VIEW_TYPE, PROFILE_VIEW_TYPE, PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';

describe('ProjectView', () => {
  let wrapper;
  const mockProject = {
    name: 'Test Project',
    fullPath: 'group/test-project',
    avatarUrl: 'http://example.com/avatar.png',
    pagesDeployments: {
      count: 100,
      nodes: [
        {
          id: '1',
          active: true,
          pathPrefix: '/foo',
          url: 'http://example.com/foo',
          createdAt: '2023-01-01T00:00:00Z',
          ciBuildId: '100',
          size: 1024,
        },
        {
          id: '2',
          active: false,
          pathPrefix: '/bar',
          url: 'http://example.com/bar',
          createdAt: '2023-01-02T00:00:00Z',
          ciBuildId: '101',
          size: 2048,
        },
      ],
    },
  };

  const findProjectName = () => wrapper.findByTestId('project-name');
  const findAllStatusBadges = () => wrapper.findAllComponents(GlBadge);
  const findAllPathPrefixes = () => wrapper.findAllByTestId('path-prefix');
  const findAllUrls = () => wrapper.findAllByTestId('url');
  const findAllCiBuilds = () => wrapper.findAllByTestId('ci-build');
  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findViewAllLink = () => wrapper.findComponentByTestId('view-all-link');

  const createComponent = (viewType) => {
    wrapper = mountExtended(ProjectView, {
      propsData: {
        project: mockProject,
      },
      provide: {
        viewType,
      },
    });
  };

  describe.each([GROUP_VIEW_TYPE, PROFILE_VIEW_TYPE, PROJECT_VIEW_TYPE])(
    'with viewType=%s',
    (_, viewType) => {
      beforeEach(() => {
        createComponent(viewType);
      });

      it('renders the correct number of deployment rows', () => {
        expect(wrapper.findAll('.deployments-table tbody tr')).toHaveLength(2);
      });

      it('shows the correct state for active and inactive deployments', () => {
        const badges = findAllStatusBadges();
        expect(badges.at(0).text()).toContain('Active');
        expect(badges.at(1).text()).toContain('Stopped');
      });

      it('displays the correct path prefix for each deployment', () => {
        const pathPrefixes = findAllPathPrefixes();
        expect(pathPrefixes.at(0).text()).toContain('/foo');
        expect(pathPrefixes.at(1).text()).toContain('/bar');
      });

      it('renders active URLs as links and inactive URLs as text', () => {
        const urls = findAllUrls();
        expect(urls.at(0).element.tagName).toBe('A');
        expect(urls.at(0).attributes('href')).toBe('http://example.com/foo');
        expect(urls.at(1).element.tagName).not.toBe('A');
      });

      it('passes the creation date correctly to UserDate', () => {
        const dates = wrapper.findAllComponents(UserDate);
        expect(dates.at(0).props('date')).toBe('2023-01-01T00:00:00Z');
        expect(dates.at(1).props('date')).toBe('2023-01-02T00:00:00Z');
      });

      it('generates correct build URLs', () => {
        const buildLinks = findAllCiBuilds();
        expect(buildLinks.at(0).attributes('href')).toContain('/group/test-project/-/jobs/100');
        expect(buildLinks.at(1).attributes('href')).toContain('/group/test-project/-/jobs/101');
      });

      it('renders the size of deployments using NumberToHumanSize component', () => {
        const sizes = wrapper.findAllComponents(NumberToHumanSize);
        expect(sizes.at(0).props('value')).toBe(1024);
        expect(sizes.at(1).props('value')).toBe(2048);
      });

      it('shows "View all" link when there are more deployments', () => {
        expect(wrapper.text()).toContain('+ 98 more deployments');
        expect(findViewAllLink().text()).toBe('View all');
        expect(findViewAllLink().props('href')).toBe('/group/test-project/pages');
      });

      it('does not show "View all" link when all deployments are displayed', async () => {
        await wrapper.setProps({
          project: {
            ...mockProject,
            pagesDeployments: {
              count: 2,
              nodes: mockProject.pagesDeployments.nodes,
            },
          },
        });
        expect(wrapper.text()).not.toContain('more deployments');
        expect(findViewAllLink().exists()).toBe(false);
      });
    },
  );

  describe.each([GROUP_VIEW_TYPE, PROFILE_VIEW_TYPE])('namespace view', (_, viewType) => {
    beforeEach(() => {
      createComponent(viewType);
    });

    it('renders the project name and avatar', () => {
      const projectName = findProjectName();
      const avatar = findAvatar();
      expect(projectName.text()).toContain('Test Project');
      expect(avatar.props('src')).toBe('http://example.com/avatar.png');
      expect(projectName.find('a').attributes('href')).toBe('/group/test-project/pages');
    });

    it('displays the correct number of total deployments', () => {
      expect(removeWhitespace(wrapper.text())).toContain('Parallel deployments: 100');
    });
  });

  describe('project view', () => {
    beforeEach(() => {
      createComponent(PROJECT_VIEW_TYPE);
    });

    it('does not render the project name and avatar', () => {
      const projectName = findProjectName();
      const avatar = findAvatar();
      expect(avatar.exists()).toBe(false);
      expect(projectName.exists()).toBe(false);
    });

    it('does not display the number of total deployments', () => {
      expect(removeWhitespace(wrapper.text())).not.toContain('Parallel deployments');
    });
  });
});
