<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import getDuoAgentSessionsOnMergeRequestQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_merge_request.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';

export default {
  name: 'WidgetAgentSessions',

  components: {
    AgentSessionsList,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    allSessions: {
      query: getDuoAgentSessionsOnMergeRequestQuery,
      variables() {
        return {
          projectPath: this.mr.targetProjectFullPath || this.mr.sourceProjectFullPath,
          iid: String(this.mr.iid),
        };
      },
      skip() {
        return !this.mr.iid;
      },
      update(data) {
        return data?.project?.mergeRequest?.duoWorkflows?.nodes ?? [];
      },
      error(err) {
        createAlert({
          message:
            err?.message ||
            s__('DuoAgentPlatform|Failed to load agent sessions for this merge request.'),
          captureError: true,
          error: err,
        });
      },
    },
  },
  data() {
    return {
      allSessions: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.allSessions.loading;
    },
  },
  created() {
    eventHub.$on(SHOW_SESSION, this.refetchSessions);
  },
  beforeDestroy() {
    eventHub.$off(SHOW_SESSION, this.refetchSessions);
  },
  methods: {
    refetchSessions() {
      this.$apollo.queries.allSessions.refetch();
    },
  },
};
</script>
<template>
  <agent-sessions-list :sessions="allSessions" :is-loading="isLoading" />
</template>
