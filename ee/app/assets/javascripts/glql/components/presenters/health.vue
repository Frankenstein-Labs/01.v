<script>
import IssueHealthStatus from 'ee/issues/components/issue_health_status.vue';
import NullPresenter from '~/glql/components/presenters/null.vue';

export default {
  name: 'HealthPresenterEE',
  components: {
    IssueHealthStatus,
    NullPresenter,
  },
  props: {
    data: {
      required: true,
      type: String,
    },
  },
};
</script>
<template>
  <issue-health-status
    v-if="data"
    :health-status="data"
    display-as-text
    :disable-tooltip="true"
    class="gl-whitespace-nowrap"
  />
  <null-presenter v-else />
</template>
