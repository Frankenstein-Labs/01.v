<script>
import { InputRequestedMessage } from '@gitlab/duo-ui';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import getWorkflowPermissions from 'ee/ai/duo_agents_platform/graphql/queries/get_workflow_permissions.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import AgentFlowUserApproval from './agent_flow_user_approval.vue';

export default {
  name: 'MessageApprovalRequest',
  components: {
    InputRequestedMessage,
    AgentFlowUserApproval,
  },
  mixins: [glListenersMixin],
  props: {
    message: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      workflowPermissions: {},
    };
  },
  apollo: {
    workflowPermissions: {
      query: getWorkflowPermissions,
      // Read straight from the normalized DuoWorkflow node that the polling
      // getAgentFlow query already caches — this never fetches, and re-emits
      // for free when getAgentFlow writes fresh permissions to the same node.
      fetchPolicy: fetchPolicies.CACHE_ONLY,
      skip() {
        return !this.$route?.params?.id;
      },
      variables() {
        return {
          workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, this.$route.params.id),
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.[0]?.node?.userPermissions || {};
      },
    },
  },
  computed: {
    showApproval() {
      return Boolean(
        this.workflowPermissions.resumeDuoWorkflow &&
        this.workflowPermissions.updateDuoWorkflow &&
        this.message.isLastMessage,
      );
    },
  },
};
</script>
<template>
  <div>
    <input-requested-message :message="message" v-on="glListeners()" />
    <agent-flow-user-approval v-if="showApproval" class="gl-mt-3" />
  </div>
</template>
