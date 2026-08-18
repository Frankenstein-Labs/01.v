<script>
import { GlCollapse, GlTooltipDirective } from '@gitlab/ui';
import isMaximizedQuery from 'ee/ai/graphql/get_ai_panel_is_maximized.query.graphql';
import infoToggleStatesQuery from 'ee/ai/graphql/get_ai_panel_info_toggle_states.query.graphql';
import { AGENT_PLATFORM_STATUS_FAILED } from 'ee/ai/duo_agents_platform/constants';
import NoCreditsBanner from '../../../components/common/no_credits_banner.vue';
import UsageBillingForbiddenBanner from '../../../components/common/usage_billing_forbidden_banner.vue';
import AgentFlowHeader from './agent_flow_header.vue';
import AgentFlowInfo from './agent_flow_info.vue';
import AgentActivityLogs from './agent_activity_logs.vue';
import AgentFlowErrorAlert from './agent_flow_error_alert.vue';

export default {
  name: 'AgentFlowDetails',
  components: {
    AgentFlowHeader,
    AgentFlowInfo,
    AgentActivityLogs,
    AgentFlowErrorAlert,
    NoCreditsBanner,
    UsageBillingForbiddenBanner,
    GlCollapse,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    isSidePanelView: { default: false },
    creditsAvailable: { default: true },
    billingForbidden: { default: false },
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    humanStatus: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
    modelName: {
      type: String,
      required: false,
      default: '',
    },
    modelIdentifier: {
      type: String,
      required: false,
      default: '',
    },
    title: {
      required: true,
      type: String,
    },
    duoMessages: {
      type: Array,
      required: true,
    },
    allExecutorUrls: {
      type: Array,
      required: false,
      default: () => [],
    },
    createdAt: {
      type: String,
      required: true,
    },
    updatedAt: {
      type: String,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
    user: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    workflowId: {
      type: String,
      required: true,
    },
    canUpdateWorkflow: {
      type: Boolean,
      required: true,
    },
    summary: {
      type: String,
      required: false,
      default: '',
    },
    workItem: {
      type: Object,
      required: false,
      default: null,
    },
    mergeRequest: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['cancel-session'],
  apollo: {
    isMaximized: {
      query: isMaximizedQuery,
      result({ data }) {
        this.isMaximized = data?.isMaximized ?? false;
      },
    },
    infoToggleStates: {
      query: infoToggleStatesQuery,
      result({ data }) {
        this.infoToggleStates = data?.infoToggleStates ?? {};
      },
    },
  },
  data() {
    return {
      isMaximized: false,
      infoToggleStates: {},
      isErrorDismissed: false,
    };
  },
  computed: {
    collapseId() {
      return `agent-flow-info-collapse-${this.workflowId}`;
    },
    isInfoVisible() {
      if (!this.isSidePanelView) {
        return false;
      }
      return this.infoToggleStates[`ai_panel:${this.workflowId}`] ?? false;
    },
    agentFlowInfoProps() {
      return {
        isLoading: this.isLoading,
        status: this.status,
        humanStatus: this.humanStatus,
        agentFlowDefinition: this.agentFlowDefinition,
        modelName: this.modelName,
        modelIdentifier: this.modelIdentifier,
        createdAt: this.createdAt,
        project: this.project,
        updatedAt: this.updatedAt,
        allExecutorUrls: this.allExecutorUrls,
        workflowId: this.workflowId,
        user: this.user,
        canUpdateWorkflow: this.canUpdateWorkflow,
        workItem: this.workItem,
        mergeRequest: this.mergeRequest,
        isSidePanelView: this.isSidePanelView,
        duoMessages: this.duoMessages,
      };
    },
    hasDuoMessages() {
      return Boolean(this.duoMessages.length);
    },
    isInfoSidebarExpanded() {
      return !this.isSidePanelView || this.isMaximized;
    },
    sessionFailed() {
      return this.status === AGENT_PLATFORM_STATUS_FAILED;
    },
    isBillingForbidden() {
      return !this.creditsAvailable && this.billingForbidden;
    },
    showErrorAlert() {
      return this.sessionFailed && !this.isErrorDismissed && !this.isBillingForbidden;
    },
  },
  methods: {
    dismissError() {
      this.isErrorDismissed = true;
    },
  },
};
</script>
<template>
  <div>
    <agent-flow-header
      v-if="!isSidePanelView"
      :is-loading="isLoading"
      :title="title"
      :agent-flow-definition="agentFlowDefinition"
    />
    <usage-billing-forbidden-banner v-if="isBillingForbidden" />
    <no-credits-banner v-else-if="!creditsAvailable" />
    <agent-flow-error-alert
      v-if="showErrorAlert"
      :has-messages="hasDuoMessages"
      :error-summary="summary"
      @dismiss="dismissError"
    />
    <div
      class="gl-flex"
      :class="{
        'gl-flex-col-reverse gl-justify-between xl:gl-flex-row': !isSidePanelView,
        'gl-flex-col': isSidePanelView && !isMaximized,
        'gl-flex-col gl-justify-end lg:gl-flex-row-reverse': isSidePanelView && isMaximized,
      }"
      data-testid="agent-flow-details-wrapper"
    >
      <gl-collapse
        v-if="isSidePanelView"
        :id="collapseId"
        ref="infoCollapse"
        :class="{ 'lg:gl-min-w-[30%]': isInfoSidebarExpanded }"
        :visible="isInfoVisible"
      >
        <agent-flow-info
          class="gl-mt-3"
          v-bind="agentFlowInfoProps"
          @cancel-session="$emit('cancel-session')"
        />
      </gl-collapse>
      <agent-activity-logs
        class="gl-overflow-auto"
        :is-loading="isLoading"
        :duo-messages="duoMessages"
        :created-at="createdAt"
        :status="status"
        :updated-at="updatedAt"
        :user="user"
      />
      <agent-flow-info
        v-if="!isSidePanelView"
        class="gl-mt-3 gl-pt-3"
        :class="{ 'lg:gl-min-w-[30%]': isInfoSidebarExpanded }"
        v-bind="agentFlowInfoProps"
        @cancel-session="$emit('cancel-session')"
      />
    </div>
  </div>
</template>
