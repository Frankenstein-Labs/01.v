import { GlLink } from '@gitlab/ui';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import StatsCard from 'ee/usage_quotas/pages/components/stats.vue';
import { DOCS_URL } from '~/constants';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  groupViewStatsData,
  projectViewNamespaceDomainStatsData,
  projectViewUniqueDomainStatsData,
} from './mock_data';

describe('PagesDeploymentsStats', () => {
  let wrapper;

  const createComponent = (provide) => {
    wrapper = shallowMountExtended(StatsCard, {
      propsData: {
        title: 'Parallel Deployments',
      },
      provide,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const expectedSectionsGroupView = [
    {
      id: 0,
      label: 'Project 1',
      value: 35,
      formattedValue: '35',
    },
    {
      id: 1,
      label: 'Project 2',
      value: 15,
      formattedValue: '15',
    },
    {
      id: 'free',
      label: 'Remaining deployments',
      color: 'var(--gray-50)',
      value: 450,
      formattedValue: '450',
      hideLabel: true,
    },
  ];

  const expectedSectionsProjectViewNamespaceDomain = [
    {
      id: 'projectDeployments',
      label: 'This project',
      value: 17,
      formattedValue: '17',
      color: expect.any(String),
      hideLabel: false,
    },
    {
      id: 'otherDeployments',
      label: 'Other projects in namespace',
      value: 43,
      formattedValue: '43',
      color: 'var(--gray-400)',
    },
    {
      id: 'free',
      label: 'Remaining deployments',
      color: 'var(--gray-50)',
      value: 440,
      formattedValue: '440',
      hideLabel: true,
    },
  ];

  const expectedSectionsProjectViewUniqueDomain = [
    {
      id: 'projectDeployments',
      label: 'This project',
      value: 19,
      formattedValue: '19',
      color: expect.any(String),
      hideLabel: true,
    },
    {
      id: 'free',
      label: 'Remaining deployments',
      color: 'var(--gray-50)',
      value: 481,
      formattedValue: '481',
      hideLabel: true,
    },
  ];

  describe.each`
    description                                           | statsData                              | count         | expectedSections                              | description
    ${'namespace view'}                                   | ${groupViewStatsData}                  | ${'50 / 500'} | ${expectedSectionsGroupView}                  | ${'Active parallel deployments'}
    ${'project view with project using namespace domain'} | ${projectViewNamespaceDomainStatsData} | ${'60 / 500'} | ${expectedSectionsProjectViewNamespaceDomain} | ${'This project is using the namespace domain "pages.example.com". The usage quota includes parallel deployments for all projects in the namespace that use this domain.'}
    ${'project view with project using unique domain'}    | ${projectViewUniqueDomainStatsData}    | ${'19 / 500'} | ${expectedSectionsProjectViewUniqueDomain}    | ${'Active parallel deployments'}
  `('$description', ({ statsData, count, expectedSections, description }) => {
    beforeEach(() => {
      createComponent(statsData);
    });

    it('displays the title', () => {
      expect(wrapper.find('h2').text()).toEqual('Parallel Deployments');
    });

    it('displays the count', () => {
      expect(wrapper.findByTestId('count').text()).toEqual(count);
    });

    it('passes the expected sections to SectionedPercentageBar', () => {
      const percentageBar = wrapper.findComponent(SectionedPercentageBar);
      expect(percentageBar.props('sections')).toEqual(expectedSections);
    });

    it('displays the description', () => {
      expect(wrapper.text()).toContain(description);
    });

    it('displays the help link', () => {
      const link = wrapper.getComponent(GlLink);

      expect(link.attributes('href')).toBe(
        `${DOCS_URL}/user/project/pages/parallel_deployments#limits`,
      );
      expect(link.attributes('title')).toBe('Learn about limits for Pages deployments');
      expect(link.attributes('aria-label')).toBe('Learn about limits for Pages deployments');
    });
  });
});
