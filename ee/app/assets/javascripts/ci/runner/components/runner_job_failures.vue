<script>
import { GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/success-sm.svg?url';

import { captureException } from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { I18N_FETCH_ERROR } from '~/ci/runner/constants';

import runnerFailedJobsQuery from '../graphql/performance/runner_failed_jobs.graphql';
import RunnerJobFailure from './runner_job_failure.vue';

export default {
  name: 'RunnerJobFailures',
  components: {
    GlEmptyState,
    GlSkeletonLoader,
    RunnerJobFailure,
  },
  data() {
    return {
      failedJobs: [],
    };
  },
  apollo: {
    failedJobs: {
      query: runnerFailedJobsQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      update({ jobs }) {
        return jobs?.nodes || [];
      },
      error(error) {
        createAlert({ message: I18N_FETCH_ERROR });

        captureException(error);
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.failedJobs.loading;
    },
  },
  EMPTY_STATE_SVG_URL,
};
</script>
<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <h2 class="gl-mt-0 gl-text-lg">{{ s__('Runners|Most recent failures') }}</h2>

    <gl-skeleton-loader v-if="loading" />
    <gl-empty-state
      v-else-if="!failedJobs.length"
      class="gl-mt-5 @lg/panel:gl-mx-12"
      :svg-path="$options.EMPTY_STATE_SVG_URL"
      :svg-height="72"
      :description="
        s__(
          'Runners|There are no recent runner failures for your instance runners. Error messages will populate here if runners fail.',
        )
      "
    />
    <div v-else class="gl-border-b">
      <runner-job-failure
        v-for="job in failedJobs"
        :key="job.id"
        :job="job"
        class="gl-border-t gl-py-5"
      />
    </div>
  </div>
</template>
