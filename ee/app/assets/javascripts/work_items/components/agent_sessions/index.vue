<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import getDuoAgentSessionsOnWorkItemQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_work_item.query.graphql';
import {
  eventHub,
  SHOW_SESSION,
  SCROLL_TO_SESSIONS,
  consumeScrollToSessions,
} from 'ee/ai/events/panel';

export default {
  name: 'WorkItemAgentSessions',

  components: {
    AgentSessionsList,
  },
  props: {
    workItemId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      allSessions: [],
      shouldScrollOnLoad: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.allSessions.loading;
    },
  },
  apollo: {
    allSessions: {
      query: getDuoAgentSessionsOnWorkItemQuery,
      variables() {
        return {
          id: this.workItemId,
        };
      },
      skip() {
        return !this.workItemId;
      },
      update(data) {
        return data?.workItem?.features?.aiSession?.duoWorkflows?.nodes ?? [];
      },
      error(err) {
        createAlert({
          message:
            err?.message ||
            s__('DuoAgentPlatform|Failed to load agent sessions for this work item.'),
          captureError: true,
          error: err,
        });
      },
    },
  },
  watch: {
    allSessions(sessions) {
      if (this.shouldScrollOnLoad && sessions.length > 0) {
        this.$nextTick(() => this.scrollToSelf());
      }
    },
  },
  created() {
    eventHub.$on(SHOW_SESSION, this.refetchSessions);
    eventHub.$on(SCROLL_TO_SESSIONS, this.requestScrollOnLoad);
    if (consumeScrollToSessions()) {
      this.requestScrollOnLoad();
    }
  },
  beforeDestroy() {
    eventHub.$off(SHOW_SESSION, this.refetchSessions);
    eventHub.$off(SCROLL_TO_SESSIONS, this.requestScrollOnLoad);
  },
  methods: {
    requestScrollOnLoad() {
      if (this.allSessions.length > 0) {
        this.$nextTick(() => this.scrollToSelf());
      } else {
        this.shouldScrollOnLoad = true;
      }
    },
    scrollToSelf() {
      this.$el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      this.shouldScrollOnLoad = false;
    },
    refetchSessions() {
      this.$apollo.queries.allSessions.refetch();
    },
  },
};
</script>

<template>
  <agent-sessions-list :sessions="allSessions" :is-loading="isLoading" />
</template>
