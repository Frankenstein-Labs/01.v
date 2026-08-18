<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import getDuoAgentSessionsOnPipelineQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_pipeline.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';

export default {
  name: 'PipelineAgentSessions',

  components: {
    AgentSessionsList,
  },
  inject: {
    paths: {
      default: {},
    },
    pipelineIid: {
      default: '',
    },
  },
  apollo: {
    allSessions: {
      query: getDuoAgentSessionsOnPipelineQuery,
      variables() {
        return {
          projectPath: this.paths.fullProject,
          iid: String(this.pipelineIid),
        };
      },
      skip() {
        return !this.pipelineIid;
      },
      update(data) {
        return data?.project?.pipeline?.duoWorkflows?.nodes ?? [];
      },
      error(err) {
        createAlert({
          message: s__('DuoAgentPlatform|Failed to load agent sessions for this pipeline.'),
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
