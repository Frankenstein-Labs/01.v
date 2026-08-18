<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { getAgentFlow } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flow.query.graphql';
import {
  DUO_AGENTS_PLATFORM_POLLING_INTERVAL,
  WORKFLOW_TERMINAL_STATUSES,
  STALE_ROUTE_ERROR_CODES,
  SIDE_PANEL_ROUTE_CONTEXT,
} from 'ee/ai/duo_agents_platform/constants';
import { clearRouteState, getStorageKey } from 'ee/ai/duo_agents_platform/utils/navigation_state';
import {
  formatAgentDefinition,
  formatAgentStatus,
  formatAgentFlowTitleWithId,
} from 'ee/ai/duo_agents_platform/utils';
import { cancelWorkflow } from 'ee/rest_api';
import { setAgentSessionStatus, setPanelTitle, setPanelSubtitle } from 'ee/ai/graphql';
import AgentFlowDetails from './components/agent_flow_details.vue';
import AgentFlowCancelationModal from './components/agent_flow_cancelation_modal.vue';

export default {
  name: 'DuoAgentsPlatformShow',
  components: {
    AgentFlowDetails,
    AgentFlowCancelationModal,
  },
  inject: {
    isFlyout: { default: false },
    isSidePanelView: { default: false },
  },
  provide() {
    return {
      lastExecutorLogUrl: () => this.agentFlow?.lastExecutorLogsUrl || '',
    };
  },
  data() {
    return {
      agentFlow: null,
      showCancelConfirmation: false,
      isCancelling: false,
    };
  },
  apollo: {
    agentFlow: {
      query: getAgentFlow,
      pollInterval: DUO_AGENTS_PLATFORM_POLLING_INTERVAL,
      variables() {
        return {
          workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, this.$route.params.id),
        };
      },
      context: {
        featureCategory: 'duo_agent_platform',
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.[0]?.node || {};
      },
      result() {
        if (this.isSidePanelView) {
          setAgentSessionStatus(this.agentFlow?.status);
          setPanelTitle(this.agentFlow?.project?.name);
          setPanelSubtitle(
            formatAgentFlowTitleWithId(
              this.agentFlow?.title,
              this.agentFlow?.workflowDefinition,
              this.$route?.params?.id,
            ),
          );
        }

        if (WORKFLOW_TERMINAL_STATUSES.includes(this.agentFlow?.status)) {
          this.$apollo.queries.agentFlow.stopPolling();
        }
      },
      error(err) {
        const hasStaleRouteError = (err?.graphQLErrors || []).some((e) =>
          STALE_ROUTE_ERROR_CODES.includes(e?.extensions?.code),
        );

        if (hasStaleRouteError) {
          this.$apollo.queries.agentFlow.stopPolling();

          if (this.isSidePanelView) {
            clearRouteState(getStorageKey(SIDE_PANEL_ROUTE_CONTEXT));
          }
        }

        createAlert({
          message:
            err?.message ||
            s__('DuoAgentsPlatform|Something went wrong while fetching Agent Flows'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.agentFlow.loading;
    },
    agentFlowDetailsProps() {
      return {
        isLoading: this.isLoading,
        status: this.agentFlow?.status || '',
        humanStatus: formatAgentStatus(this.agentFlow?.humanStatus),
        title: this.agentFlow?.title || '',
        agentFlowDefinition: formatAgentDefinition(this.agentFlow?.workflowDefinition),
        modelName: this.agentFlow?.modelMetadataName || '',
        modelIdentifier: this.agentFlow?.modelMetadataIdentifier || '',
        duoMessages: this.agentFlow?.latestCheckpoint?.duoMessages || [],
        allExecutorUrls: this.agentFlow?.allExecutorLogsUrls || [],
        createdAt: this.agentFlow?.createdAt || '',
        updatedAt: this.agentFlow?.updatedAt || '',
        project: this.agentFlow?.project || {},
        user: this.agentFlow?.user || {},
        workflowId: this.$route.params.id?.toString() || '',
        canUpdateWorkflow: this.agentFlow?.userPermissions?.updateDuoWorkflow || false,
        summary: this.agentFlow?.summary || '',
        workItem: this.agentFlow?.workItem ?? null,
        mergeRequest: this.agentFlow?.mergeRequest ?? null,
      };
    },
  },
  beforeDestroy() {
    // Clear the panel title/subtitle/status reactive vars so the next mount
    // (e.g. returning to this route for the same workflow) is guaranteed to
    // produce a value change in `result()` and re-emit through Apollo. Without
    // this, Apollo's `makeVar` skips notifying subscribers when the new value
    // matches the previous one, leaving the panel header stuck in its
    // loading state.
    if (this.isSidePanelView) {
      setAgentSessionStatus(null);
      setPanelTitle(null);
      setPanelSubtitle(null);
    }
  },
  methods: {
    async confirmCancelSession() {
      this.isCancelling = true;
      this.showCancelConfirmation = false;

      try {
        await cancelWorkflow(this.$route.params.id);

        createAlert({
          message: s__('DuoAgentsPlatform|Session has been cancelled successfully.'),
          variant: 'success',
        });
      } catch (error) {
        const errorMessage =
          error.response?.data?.message ||
          s__('DuoAgentsPlatform|Failed to cancel session. Please try again.');

        createAlert({
          message: errorMessage,
          captureError: true,
          variant: 'danger',
        });
      } finally {
        this.isCancelling = false;
      }
    },
  },
};
</script>
<template>
  <div>
    <agent-flow-details
      :class="isFlyout ? 'gl-mx-3' : ''"
      v-bind="agentFlowDetailsProps"
      @cancel-session="showCancelConfirmation = true"
    />

    <agent-flow-cancelation-modal
      :visible="showCancelConfirmation"
      :loading="isCancelling"
      @hide="showCancelConfirmation = false"
      @confirm="confirmCancelSession"
    />
  </div>
</template>
