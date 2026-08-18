import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GovernanceApp from 'ee/ai/governance/components/governance_app.vue';
import AiGovernanceDashboardApp from 'ee/ai/governance/components/dashboard/dashboard_app.vue';
import AgentArtifactsApp from 'ee/agent_artifacts/components/agent_artifacts_app.vue';
import getMcpServersQuery from 'ee/ai/governance/graphql/queries/get_mcp_servers.query.graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';

Vue.use(VueApollo);

describe('GovernanceApp', () => {
  let wrapper;

  const createComponent = ({ glFeatures = {} } = {}) => {
    // The lazy tabs resolve their async components after waitForPromises; provide a
    // client so the Apollo-backed MCP registry tab does not error when it mounts.
    const apolloProvider = createMockApollo([
      [
        getMcpServersQuery,
        jest.fn().mockResolvedValue({
          data: {
            aiCatalogMcpServers: {
              nodes: [],
              pageInfo: { hasNextPage: false, hasPreviousPage: false, __typename: 'PageInfo' },
              __typename: 'AiCatalogMcpServerConnection',
            },
          },
        }),
      ],
    ]);

    wrapper = shallowMountExtended(GovernanceApp, {
      apolloProvider,
      provide: {
        glFeatures,
        groupFullPath: 'gitlab-org',
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findToolManagementTab = () => wrapper.findByTestId('tool-management-tab');
  const findAgentArtifactsTab = () => wrapper.findByTestId('agent-artifacts-tab');
  const findDashboardTab = () => wrapper.findByTestId('dashboard-tab');
  const findMcpRegistryTab = () => wrapper.findByTestId('mcp-registry-tab');

  describe('page heading', () => {
    it('renders the page heading', () => {
      createComponent();

      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('Control how your AI-powered features are used.');
    });
  });

  describe('tabs', () => {
    it('renders the GlTabs component', () => {
      createComponent();

      expect(findTabs().exists()).toBe(true);
    });

    it('renders the Tool management tab', () => {
      createComponent();

      expect(findToolManagementTab().exists()).toBe(true);
    });

    it('renders the MCP registry tab', () => {
      createComponent();

      expect(findMcpRegistryTab().exists()).toBe(true);
    });
  });

  describe('when agentArtifactsPage feature flag is enabled', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { agentArtifactsPage: true } });
    });

    it('renders the Audit events tab', () => {
      expect(findAgentArtifactsTab().exists()).toBe(true);
    });

    it('renders AgentArtifactsApp when the Audit events tab is active', async () => {
      await findTabs().vm.$emit('input', 1);
      await waitForPromises();

      expect(wrapper.findComponent(AgentArtifactsApp).exists()).toBe(true);
    });
  });

  describe('when agentArtifactsPage feature flag is disabled', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { agentArtifactsPage: false } });
    });

    it('does not render the Audit events tab', () => {
      expect(findAgentArtifactsTab().exists()).toBe(false);
    });
  });

  describe('when aiGovernanceDashboard feature flag is enabled', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { aiGovernanceDashboard: true } });
    });

    it('renders the Dashboard tab', () => {
      expect(findDashboardTab().exists()).toBe(true);
    });

    it('renders AiGovernanceDashboardApp when the Dashboard tab is active', async () => {
      await waitForPromises();

      expect(wrapper.findComponent(AiGovernanceDashboardApp).exists()).toBe(true);
    });
  });

  describe('when aiGovernanceDashboard feature flag is disabled', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { aiGovernanceDashboard: false } });
    });

    it('does not render the Dashboard tab', () => {
      expect(findDashboardTab().exists()).toBe(false);
    });
  });
});
