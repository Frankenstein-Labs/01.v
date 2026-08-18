<script>
import { GlCard, GlSkeletonLoader } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, n__, s__ } from '~/locale';
import groupReleaseStatsQuery from '../graphql/group_release_stats.query.graphql';

const STAT_ERROR_PLACEHOLDER = '-';

export default {
  name: 'ReleaseStatsCard',
  components: {
    GlCard,
    GlSkeletonLoader,
  },
  inject: {
    groupFullPath: {
      default: '',
    },
  },
  apollo: {
    rawStats: {
      query: groupReleaseStatsQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      update(data) {
        return data.group?.stats?.releaseStats || {};
      },
      error(error) {
        this.errored = true;

        createAlert({
          message: s__('CICDAnalytics|Something went wrong while fetching release statistics'),
          captureError: true,
          error,
        });
      },
    },
  },
  data() {
    return {
      rawStats: null,
      errored: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.rawStats.loading;
    },
    releasesCountStat() {
      if (this.errored) {
        return STAT_ERROR_PLACEHOLDER;
      }

      return this.rawStats?.releasesCount.toString() || '';
    },
    releasesPercentageStat() {
      if (this.errored) {
        return STAT_ERROR_PLACEHOLDER;
      }

      if (this.rawStats?.releasesPercentage != null) {
        return sprintf(s__('CICDAnalytics|%{percent}%{percentSymbol}'), {
          percent: this.rawStats?.releasesPercentage,
          percentSymbol: '%',
        });
      }

      return '';
    },
    formattedStats() {
      return [
        {
          id: 'releases-count',
          stat: this.releasesCountStat,
          title: n__(
            'CICDAnalytics|Release',
            'CICDAnalytics|Releases',
            this.rawStats?.releasesCount || 0,
          ),
        },
        {
          id: 'releases-percentage',
          stat: this.releasesPercentageStat,
          title: s__('CICDAnalytics|Projects with releases'),
        },
      ];
    },
  },
};
</script>
<template>
  <gl-card class="gl-mt-5" data-testid="release-stats-card">
    <template #header>
      <header class="gl-flex gl-items-baseline">
        <h1 class="gl-m-0 gl-mr-5 gl-text-lg">{{ s__('CICDAnalytics|Releases') }}</h1>
        <h2 class="gl-m-0 gl-text-base gl-font-normal gl-text-subtle">
          {{ s__('CICDAnalytics|All time') }}
        </h2>
      </header>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-4 @sm/panel:gl-flex-row" data-testid="stats-container">
      <div
        v-for="stat of formattedStats"
        :key="stat.id"
        class="gl-flex gl-h-11 gl-grow gl-basis-0 gl-flex-col gl-items-center"
      >
        <gl-skeleton-loader v-if="isLoading">
          <rect x="0" y="21" rx="3" ry="3" width="400" height="48" />
          <rect x="50" y="94" rx="3" ry="3" width="300" height="31" />
        </gl-skeleton-loader>
        <template v-else>
          <span class="gl-text-size-h-display gl-leading-42">{{ stat.stat }}</span>
          {{ stat.title }}
        </template>
      </div>
    </div>
  </gl-card>
</template>
