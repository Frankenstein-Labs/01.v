<script>
import { GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { INSTANCE_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';
import RunnerListHeader from '~/ci/runner/components/runner_list_header.vue';

import RunnerDashboardStatStatus from '../components/runner_dashboard_stat_status.vue';
import RunnerUsage from '../components/runner_usage.vue';
import RunnerJobFailures from '../components/runner_job_failures.vue';

import AdminRunnersActiveList from './admin_runners_active_list.vue';
import AdminRunnersWaitTimes from './admin_runners_wait_times.vue';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'AdminRunnersDashboardApp',
  components: {
    GlButton,
    AdminRunnersActiveList,
    AdminRunnersWaitTimes,
    RunnerListHeader,
    RunnerDashboardStatStatus,
    RunnerUsage,
    RunnerJobFailures,
  },
  mixins: [trackingMixin],
  inject: {
    clickhouseCiAnalyticsAvailable: {
      default: false,
    },
  },
  props: {
    adminRunnersPath: {
      type: String,
      required: true,
    },
    newRunnerPath: {
      type: String,
      required: true,
    },
    canAdminRunners: {
      type: Boolean,
      required: true,
    },
  },
  mounted() {
    this.trackEvent('view_runner_fleet_dashboard_pageload', {
      label: 'instance',
    });
  },
  INSTANCE_TYPE,
  STATUS_ONLINE,
  STATUS_OFFLINE,
};
</script>
<template>
  <div>
    <runner-list-header class="gl-mb-5">
      <template #title>{{ s__('Runners|Fleet dashboard') }}</template>
      <template #description>{{
        s__('Runners|Use the dashboard to view performance statistics of your runner fleet.')
      }}</template>
      <template #actions>
        <gl-button variant="link" :href="adminRunnersPath" class="gl-mr-2">{{
          s__('Runners|View runners list')
        }}</gl-button>
        <gl-button v-if="canAdminRunners" variant="confirm" :href="newRunnerPath">
          {{ s__('Runners|Create instance runner') }}
        </gl-button>
      </template>
    </runner-list-header>

    <div class="gl-justify-between gl-gap-x-4 @sm/panel:gl-flex">
      <div class="gl-w-full gl-justify-between gl-gap-x-4 @sm/panel:gl-flex">
        <div
          class="runners-dashboard-two-thirds-gap-4 gl-mb-4 gl-flex gl-flex-wrap gl-justify-between gl-gap-4"
        >
          <runner-dashboard-stat-status
            :status="$options.STATUS_ONLINE"
            :scope="$options.INSTANCE_TYPE"
            class="runners-dashboard-half-gap-4"
          />
          <runner-dashboard-stat-status
            :status="$options.STATUS_OFFLINE"
            :scope="$options.INSTANCE_TYPE"
            class="runners-dashboard-half-gap-4"
          />

          <!-- we use job failures as fallback, when clickhouse is not available -->
          <runner-usage
            v-if="clickhouseCiAnalyticsAvailable"
            :scope="$options.INSTANCE_TYPE"
            class="gl-basis-full"
          />
          <runner-job-failures v-else class="gl-basis-full" />
        </div>

        <admin-runners-active-list class="runners-dashboard-third-gap-4 gl-mb-4" />
      </div>
    </div>
    <admin-runners-wait-times class="gl-mb-4" />
  </div>
</template>
