import { nextTick } from 'vue';
import { GlTabs, GlTab, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CiCdAnalyticsApp from 'ee/ci/analytics/group_ci_cd_analytics/app.vue';
import ReleaseStatsCard from 'ee/ci/analytics/group_ci_cd_analytics/components/group_release_stats_card.vue';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';

import GroupPipelinesDashboard from 'ee/ci/analytics/group_ci_cd_analytics/components/group_pipelines_dashboard.vue';

describe('ee/ci/analytics/group_ci_cd_analytics/components/app.vue', () => {
  let wrapper;

  const quotaPath = '/groups/my-awesome-group/-/usage_quotas#pipelines-quota-tab';

  const createComponent = ({ provide, ...options } = {}) => {
    wrapper = shallowMountExtended(CiCdAnalyticsApp, {
      provide: {
        pipelineGroupUsageQuotaPath: quotaPath,
        canViewGroupUsageQuota: true,
        glLicensedFeatures: {
          groupCiCdAnalyticsReleases: true,
          groupCiCdAnalyticsPipelines: true,
        },
        glFeatures: {
          groupCiCdAnalyticsPipelinesFf: true,
        },
        ...provide,
      },
      ...options,
    });
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findUsageQuotaLink = () => wrapper.findComponent(GlLink);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders pipeline dashboard and release stats tabs', () => {
      expect(findAllTabs().wrappers).toHaveLength(2);

      expect(wrapper.findComponent(GroupPipelinesDashboard).exists()).toBe(true);
      expect(wrapper.findComponent(ReleaseStatsCard).exists()).toBe(true);
    });
  });

  describe('when features are not available', () => {
    it('renders only release stats tab', () => {
      createComponent({
        provide: {
          glLicensedFeatures: {
            groupCiCdAnalyticsPipelines: false,
            groupCiCdAnalyticsReleases: true,
          },
        },
      });
      expect(findAllTabs().wrappers).toHaveLength(1);

      expect(wrapper.findComponent(GroupPipelinesDashboard).exists()).toBe(false);
      expect(wrapper.findComponent(ReleaseStatsCard).exists()).toBe(true);
    });

    it('renders only pipeline stats tab', () => {
      createComponent({
        provide: {
          glLicensedFeatures: {
            groupCiCdAnalyticsPipelines: true,
            groupCiCdAnalyticsReleases: false,
          },
        },
      });
      expect(findAllTabs().wrappers).toHaveLength(1);

      expect(wrapper.findComponent(GroupPipelinesDashboard).exists()).toBe(true);
      expect(wrapper.findComponent(ReleaseStatsCard).exists()).toBe(false);
    });
  });

  describe('when ci_group_pipeline_analytics feature flag is disabled', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          glFeatures: {
            groupCiCdAnalyticsPipelinesFf: false,
          },
        },
      });
    });

    it('renders only release stats tab', () => {
      expect(findAllTabs()).toHaveLength(1);

      expect(wrapper.findComponent(GroupPipelinesDashboard).exists()).toBe(false);
      expect(wrapper.findComponent(ReleaseStatsCard).exists()).toBe(true);
    });
  });

  describe('when provided with a query', () => {
    it.each`
      query                        | activeTabIndex
      ${'?tab=pipelines'}          | ${'0'}
      ${'?tab=release-statistics'} | ${'1'}
      ${'?tab=fake'}               | ${'0'}
      ${'?tab='}                   | ${'0'}
      ${''}                        | ${'0'}
    `('shows the correct tab for "$query"', ({ query, activeTabIndex }) => {
      setWindowLocation(`${TEST_HOST}/groups/gitlab-org/gitlab/-/analytics/ci_cd${query}`);

      createComponent();
      expect(findTabs().attributes('value')).toBe(activeTabIndex);
    });
  });

  it('when navigating back to previous tab', async () => {
    createComponent();
    expect(findTabs().attributes('value')).toBe('0');

    setWindowLocation(
      `${TEST_HOST}/groups/gitlab-org/gitlab/-/analytics/ci_cd?tab=release-statistics`,
    );
    window.dispatchEvent(new Event('popstate'));
    await nextTick();

    expect(findTabs().attributes('value')).toBe('1');
  });

  it('displays link to group pipeline usage quota page', () => {
    createComponent({
      stubs: {
        GlTabs: {
          template: '<div><slot></slot><slot name="tabs-end"></slot></div>',
        },
      },
    });

    expect(findUsageQuotaLink().attributes('href')).toBe(quotaPath);
    expect(findUsageQuotaLink().text()).toBe('View group pipeline usage quota');
  });

  it('hides link to group pipelines usage quota page based on permissions', () => {
    createComponent({
      provide: {
        canViewGroupUsageQuota: false,
      },
      stubs: {
        GlTabs: {
          template: '<div><slot></slot><slot name="tabs-end"></slot></div>',
        },
      },
    });

    expect(findUsageQuotaLink().exists()).toBe(false);
  });
});
