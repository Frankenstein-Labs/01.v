<script>
import { defineAsyncComponent } from 'vue';
import { GlTab, GlTabs } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

const TABS = {
  DASHBOARD: {
    title: s__('AiGovernance|Dashboard'),
    queryParamValue: 'dashboard',
  },
  TOOL_MANAGEMENT: {
    title: s__('AiGovernance|Tool management'),
    queryParamValue: 'tool-management',
  },
  AGENT_ARTIFACTS: {
    title: s__('AiGovernance|Audit events'),
    queryParamValue: 'agent-artifacts',
  },
  MCP_REGISTRY: {
    title: s__('AiGovernance|MCP registry'),
    queryParamValue: 'mcp-registry',
  },
};

export default {
  TABS,
  name: 'GovernanceApp',
  components: {
    GlTabs,
    GlTab,
    PageHeading,
    AiGovernanceDashboardApp: defineAsyncComponent(
      () =>
        import(
          /* webpackChunkName: 'ai_governance_dashboard_app' */ './dashboard/dashboard_app.vue'
        ),
    ),
    AiToolManagementApp: defineAsyncComponent(
      () =>
        import(
          /* webpackChunkName: 'ai_tool_management_app' */ './ai_tool_management/ai_tool_management_app.vue'
        ),
    ),
    AgentArtifactsApp: defineAsyncComponent(
      () =>
        import(
          /* webpackChunkName: 'agent_artifacts_app' */ 'ee/agent_artifacts/components/agent_artifacts_app.vue'
        ),
    ),
    McpRegistryApp: defineAsyncComponent(
      () =>
        import(/* webpackChunkName: 'mcp_registry_app' */ './mcp_registry/mcp_registry_app.vue'),
    ),
  },
  mixins: [glFeatureFlagMixin()],
  data() {
    return {
      activeTabIndex: 0,
    };
  },
  computed: {
    showDashboardTab() {
      return this.glFeatures.aiGovernanceDashboard;
    },
    showAgentArtifactsTab() {
      return this.glFeatures.agentArtifactsPage;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AiGovernance|AI Governance')">
      <template #description>
        {{ s__('AiGovernance|Control how your AI-powered features are used.') }}
      </template>
    </page-heading>

    <gl-tabs v-model="activeTabIndex" content-class="gl-pt-0" sync-active-tab-with-query-params>
      <gl-tab
        v-if="showDashboardTab"
        data-testid="dashboard-tab"
        :title="$options.TABS.DASHBOARD.title"
        :query-param-value="$options.TABS.DASHBOARD.queryParamValue"
        lazy
      >
        <ai-governance-dashboard-app />
      </gl-tab>

      <gl-tab
        data-testid="tool-management-tab"
        :title="$options.TABS.TOOL_MANAGEMENT.title"
        :query-param-value="$options.TABS.TOOL_MANAGEMENT.queryParamValue"
        lazy
      >
        <ai-tool-management-app />
      </gl-tab>

      <gl-tab
        v-if="showAgentArtifactsTab"
        data-testid="agent-artifacts-tab"
        :title="$options.TABS.AGENT_ARTIFACTS.title"
        :query-param-value="$options.TABS.AGENT_ARTIFACTS.queryParamValue"
        lazy
      >
        <agent-artifacts-app />
      </gl-tab>

      <gl-tab
        data-testid="mcp-registry-tab"
        :title="$options.TABS.MCP_REGISTRY.title"
        :query-param-value="$options.TABS.MCP_REGISTRY.queryParamValue"
        lazy
      >
        <mcp-registry-app />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
