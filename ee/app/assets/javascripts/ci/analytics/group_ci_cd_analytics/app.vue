<script>
import { GlTabs, GlTab, GlLink } from '@gitlab/ui';
import { mergeUrlParams, updateHistory, getParameterValues } from '~/lib/utils/url_utility';
import API from '~/api';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';

import GroupReleaseStatsCard from './components/group_release_stats_card.vue';
import GroupPipelinesDashboard from './components/group_pipelines_dashboard.vue';

export default {
  name: 'GroupCiCdAnalyticsApp',
  components: {
    GlTabs,
    GlTab,
    GlLink,
  },
  mixins: [glLicensedFeaturesMixin(), glFeatureFlagsMixin()],
  inject: {
    pipelineGroupUsageQuotaPath: {
      type: String,
      default: '',
    },
    canViewGroupUsageQuota: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedTabIndex: 0,
    };
  },
  computed: {
    isPipelinesTabAvailable() {
      return (
        // group_ci_cd_analytics_pipelines_ff feature flag
        this.glFeatures.groupCiCdAnalyticsPipelinesFf &&
        this.glLicensedFeatures.groupCiCdAnalyticsPipelines
      );
    },
    isReleasesTabAvailable() {
      return this.glLicensedFeatures.groupCiCdAnalyticsReleases;
    },
    tabs() {
      const tabs = [];

      if (this.isPipelinesTabAvailable) {
        tabs.push({
          key: 'pipelines',
          title: __('Pipelines'),
          componentIs: GroupPipelinesDashboard,
          lazy: true,
        });
      }

      if (this.isReleasesTabAvailable) {
        tabs.push({
          key: 'release-statistics',
          clickCallback: () => {
            API.trackRedisHllUserEvent('g_analytics_ci_cd_release_statistics');
          },
          title: s__('CICDAnalytics|Release statistics'),
          componentIs: GroupReleaseStatsCard,
          lazy: true,
        });
      }

      return tabs;
    },
  },
  created() {
    this.syncSelectedTab();
    window.addEventListener('popstate', this.syncSelectedTab);
  },
  destroyed() {
    window.removeEventListener('popstate', this.syncSelectedTab);
  },
  methods: {
    syncSelectedTab() {
      const [tabQueryParam] = getParameterValues('tab');
      const tabIndex = this.tabs.findIndex((tab) => tab.key === tabQueryParam);
      this.selectedTabIndex = tabIndex >= 0 ? tabIndex : 0;

      const tab = this.tabs[this.selectedTabIndex];
      if (tab) {
        tab.clickCallback?.();
      }
    },
    onTabInput(newIndex) {
      if (newIndex !== this.selectedTabIndex) {
        this.selectedTabIndex = newIndex;

        const tab = this.tabs[this.selectedTabIndex];
        if (tab) {
          const path = mergeUrlParams({ tab: tab.key }, window.location.pathname);
          updateHistory({ url: path, title: window.title });
        }
      }
    },
  },
};
</script>
<template>
  <div>
    <gl-tabs :value="selectedTabIndex" @input="onTabInput">
      <gl-tab
        v-for="tab in tabs"
        :key="tab.key"
        :title="tab.title"
        :lazy="tab.lazy"
        @click="tab.clickCallback && tab.clickCallback()"
      >
        <component :is="tab.componentIs" />
      </gl-tab>
      <template v-if="canViewGroupUsageQuota" #tabs-end>
        <gl-link :href="pipelineGroupUsageQuotaPath" class="gl-ml-auto gl-self-center">{{
          __('View group pipeline usage quota')
        }}</gl-link>
      </template>
    </gl-tabs>
  </div>
</template>
