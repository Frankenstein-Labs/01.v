<script>
import { buildClient } from '~/observability/client';
import LogsList from './list/logs_list.vue';

export default {
  components: {
    LogsList,
  },
  props: {
    apiConfig: {
      type: Object,
      required: true,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
    createIssueUrl: {
      required: true,
      type: String,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      observabilityClient: buildClient(this.apiConfig),
    };
  },
};
</script>

<template>
  <logs-list
    :observability-client="observabilityClient"
    :tracing-index-url="tracingIndexUrl"
    :create-issue-url="createIssueUrl"
    :project-full-path="projectFullPath"
  />
</template>
