<script>
import groupMostActiveRunnersQuery from 'ee/ci/runner/graphql/performance/group_most_active_runners.query.graphql';
import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';

import { captureException } from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { I18N_FETCH_ERROR } from '~/ci/runner/constants';

export default {
  name: 'GroupRunnerActiveList',
  components: {
    RunnerActiveList,
  },
  props: {
    groupFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      activeRunners: [],
    };
  },
  apollo: {
    activeRunners: {
      query: groupMostActiveRunnersQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update(data) {
        const edges = data?.group?.runners?.edges || [];

        return (
          edges
            .map(({ webUrl, node }) => ({
              webUrl,
              ...node,
            }))
            // The backend does not filter out inactive runners, but
            // showing them can be confusing for users. Ignore runners
            // with no active jobs.
            .filter(({ runningJobCount }) => runningJobCount > 0)
        );
      },
      error(error) {
        createAlert({ message: I18N_FETCH_ERROR });

        captureException(error);
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.activeRunners.loading;
    },
  },
};
</script>
<template>
  <runner-active-list :active-runners="activeRunners" :loading="loading" />
</template>
