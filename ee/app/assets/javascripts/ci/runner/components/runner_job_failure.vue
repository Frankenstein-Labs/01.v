<script>
import { GlLink } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { s__ } from '~/locale';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { getTypeFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';

import RunnerFullName from './runner_full_name.vue';

export default {
  name: 'RunnerJobFailure',
  components: {
    GlLink,
    TimeAgo,
    CiIcon,
    RunnerFullName,
  },
  directives: {
    SafeHtml,
  },
  props: {
    job: {
      type: Object,
      required: true,
      validator(val) {
        return getTypeFromGraphQLId(val.id) === TYPENAME_CI_BUILD;
      },
    },
  },
  computed: {
    runner() {
      return this.job?.runner;
    },
    traceSummary() {
      return this.job.trace?.htmlSummary || s__('Job|No job log');
    },
  },
};
</script>
<template>
  <div>
    <time-ago v-if="job.finishedAt" :time="job.finishedAt" class="gl-text-sm gl-text-subtle" />
    <div class="gl-mb-3 gl-mt-1">
      <ci-icon v-if="job.detailedStatus" :status="job.detailedStatus" show-status-text />
      <gl-link v-if="runner" :href="runner.adminUrl" data-testid="runner-link">
        <runner-full-name :runner="runner" />
      </gl-link>
    </div>
    <pre
      v-if="job.userPermissions.readBuild"
      class="gl-m-0 gl-w-full gl-border-none gl-bg-inherit gl-p-0"
    ><code v-safe-html="traceSummary" class="gl-bg-inherit gl-p-0"></code></pre>
  </div>
</template>
