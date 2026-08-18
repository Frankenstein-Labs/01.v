import { GlBadge, GlLink, GlToken, GlTruncateText, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import TriggerField from 'ee/ai/catalog/components/trigger_field.vue';
import { VERSION_LATEST, VISIBILITY_LEVEL_RESTRICTED } from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockAgentVersion,
  mockThirdPartyFlow,
  mockThirdPartyFlowVersion,
  mockThirdPartyFlowConfigurationForProject,
  mockAiCatalogBuiltInToolsNodes,
  mockServiceAccount,
  mockItemConfigurationForGroup,
  mockMcpServers,
} from '../mock_data';

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  // Sorted non-alphabetically to test sorting functionality
  const mockToolNodes = {
    nodes: [
      mockAiCatalogBuiltInToolsNodes[2], // Run Git Command
      mockAiCatalogBuiltInToolsNodes[1], // Gitlab Blob Search
      mockAiCatalogBuiltInToolsNodes[0], // CI Linter
    ],
  };

  const defaultProps = {
    item: {
      ...mockAgent,
      latestVersion: {
        ...mockAgentVersion,
        tools: mockToolNodes,
      },
    },
    versionKey: VERSION_LATEST,
  };

  const createComponent = ({ props, provide } = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide,
      stubs: {
        AiCatalogItemVisibilityField,
        GlSprintf,
      },
    });
  };

  const findAllSections = () => wrapper.findAllComponents(FormSection);
  const findSection = (index) => findAllSections().at(index);
  const findAllFieldsForSection = (index) =>
    findSection(index).findAllComponents(AiCatalogItemField);
  const findVisibilityBadge = () => wrapper.findComponent(GlBadge);
  const findSystemPromptTruncateText = () => wrapper.findComponent(GlTruncateText);
  const findSourceProjectLink = () => wrapper.findComponent(GlLink);
  const findTriggerField = () => wrapper.findComponent(TriggerField);
  const findServiceAccountField = () => wrapper.findComponentByTestId('service-account-field');
  const findManagedByField = () => wrapper.findComponentByTestId('managed-by-field');

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders 2 sections', () => {
      expect(findAllSections()).toHaveLength(2);
      expect(findSection(0).attributes('title')).toBe('Visibility & access');
      expect(findSection(1).attributes('title')).toBe('Configuration');
    });
  });

  describe('renders "Visibility & access" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      createComponent();
      accessRightsDetails = findAllFieldsForSection(0);
    });

    it('renders Visibility', () => {
      expect(accessRightsDetails.at(1).props('title')).toBe('Visibility');
      expect(accessRightsDetails.at(1).text()).toContain('Public');
      expect(findVisibilityBadge().exists()).toBe(true);
    });

    it('passes the item visibility to the visibility field component', () => {
      const visibility = VISIBILITY_LEVEL_RESTRICTED;
      createComponent({ props: { item: { ...mockAgent, visibility } } });

      expect(wrapper.findComponent(AiCatalogItemVisibilityField).props('visibility')).toBe(
        visibility,
      );
    });

    it('renders "Managed by" with link', () => {
      const sourceProjectField = accessRightsDetails.at(0);
      const link = findSourceProjectLink();

      expect(sourceProjectField.props('title')).toBe('Managed by');
      expect(link.attributes('href')).toBe(mockAgent.project.webUrl);
      expect(link.text()).toBe(mockAgent.project.nameWithNamespace);
    });
  });

  describe('renders "Configuration" details', () => {
    let configurationDetails;

    beforeEach(() => {
      createComponent();
      configurationDetails = findAllFieldsForSection(1);
    });

    it('renders "Type" field with "Custom" value', () => {
      expect(configurationDetails.at(0).props()).toMatchObject({
        title: 'Type',
        value: 'Custom',
      });
    });

    it('does not render "Service account" field', () => {
      expect(findServiceAccountField().exists()).toBe(false);
    });

    it('renders "System prompt"', () => {
      expect(configurationDetails.at(2).props()).toMatchObject({
        title: 'System prompt',
      });

      const truncateText = findSystemPromptTruncateText();
      expect(truncateText.props()).toMatchObject({
        lines: 20,
        showMoreText: 'Show more',
        showLessText: 'Show less',
        toggleButtonProps: { class: 'gl-font-regular' },
      });

      expect(configurationDetails.at(2).find('pre').text()).toBe(mockAgentVersion.systemPrompt);
    });

    it('renders "Tools" with sorted values', () => {
      const toolsField = configurationDetails.at(1);
      expect(toolsField.props('title')).toBe('Tools');

      const tokens = toolsField.findAllComponents(GlToken);
      expect(tokens).toHaveLength(3);
      expect(tokens.at(0).text()).toBe('CI Linter');
      expect(tokens.at(1).text()).toBe('Gitlab Blob Search');
      expect(tokens.at(2).text()).toBe('Run Git Command');

      const tokensTooltips = wrapper.findAllByTestId('tool-description-tooltip');
      expect(tokensTooltips).toHaveLength(3);
      expect(tokensTooltips.at(0).attributes('title')).toBe('CI Linter Tool description');
      expect(tokensTooltips.at(1).attributes('title')).toBe('Gitlab Blob Search Tool description');
      expect(tokensTooltips.at(2).attributes('title')).toBe('Run Git Command Tool description');
    });

    describe('when MCP tools are present', () => {
      const mcpToolNames = ['semantic_code_search', 'get_mcp_server_version'];

      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              latestVersion: {
                ...mockAgentVersion,
                tools: mockToolNodes,
                mcpTools: mcpToolNames,
              },
            },
          },
          provide: {
            instanceBetaFeaturesEnabled: true,
          },
        });
      });

      it('renders MCP tools with human-readable titles and Beta badge', () => {
        const tokens = wrapper.findAllComponents(GlToken);
        const tokenTexts = tokens.wrappers.map((t) => t.text().replace(/\s+/g, ' ').trim());
        expect(tokenTexts).toContain('Get Mcp Server Version Beta');
        expect(tokenTexts).toContain('Semantic Code Search Beta');
      });

      it('renders the Beta badge inside the gl-token for MCP tools', () => {
        const toolsField = findAllFieldsForSection(1).at(1);
        expect(toolsField.findComponent(GlBadge).exists()).toBe(true);
        expect(toolsField.text()).toContain('Beta');
        expect(toolsField.text()).not.toContain('Experimental');
      });
    });

    describe('when MCP tools are disabled (beta features off)', () => {
      const mcpToolNames = ['semantic_code_search'];

      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              latestVersion: {
                ...mockAgentVersion,
                tools: [],
                mcpTools: mcpToolNames,
              },
            },
          },
          provide: {
            instanceBetaFeaturesEnabled: false,
          },
        });
      });

      it('strikes through the entire MCP token (icon, title, badge)', () => {
        const tokens = wrapper.findAllComponents(GlToken);
        const mcpToken = tokens.wrappers.find((t) => t.text().includes('Semantic Code Search'));
        const innerWrapper = mcpToken.find('span.gl-flex');
        expect(innerWrapper.classes()).toContain('gl-line-through');
        expect(innerWrapper.classes()).toContain('gl-text-disabled');
      });
    });
  });

  describe('when the item is a third-party flow', () => {
    let configurationDetails;

    beforeEach(() => {
      createComponent({
        props: {
          item: {
            ...mockThirdPartyFlow,
            latestVersion: {
              ...mockThirdPartyFlowVersion,
            },
            configurationForProject: {
              ...mockThirdPartyFlowConfigurationForProject,
            },
          },
        },
      });

      configurationDetails = findAllFieldsForSection(2);
    });

    it('renders 3 sections', () => {
      expect(findAllSections()).toHaveLength(3);
      expect(findSection(0).attributes('title')).toBe('Visibility & access');
      expect(findSection(1).attributes('title')).toBe('Service account');
      expect(findSection(2).attributes('title')).toBe('Configuration');
    });

    it('renders the trigger field', () => {
      expect(findTriggerField().exists()).toBe(true);
    });

    it('renders "Type" field with "External" value', () => {
      expect(configurationDetails.at(0).props()).toMatchObject({
        title: 'Type',
        value: 'External',
      });
    });

    it('renders "Service account" field', () => {
      expect(findServiceAccountField().props()).toMatchObject({
        serviceAccount: mockServiceAccount,
        itemType: 'THIRD_PARTY_FLOW',
      });
    });

    it('renders "Configuration" field', () => {
      const configurationField = configurationDetails.at(1);
      expect(configurationField.props('title')).toBe('Configuration');
      expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
        mockThirdPartyFlowVersion.definition,
      );
    });
  });

  describe('when the item is a foundational agent', () => {
    describe('and has configurationForGroup', () => {
      let configurationDetails;

      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              foundational: true,
              verificationLevel: 'GITLAB_MAINTAINED',
              configurationForGroup: mockItemConfigurationForGroup,
            },
          },
        });

        configurationDetails = findAllFieldsForSection(1);
      });

      it('renders "Type" field with "Foundational" value', () => {
        expect(configurationDetails.at(0).props()).toMatchObject({
          title: 'Type',
          value: 'Foundational',
        });
      });

      it('renders "Tools" field', () => {
        const toolsField = configurationDetails.at(1);
        expect(toolsField.props('title')).toBe('Tools');
        expect(toolsField.text()).toContain(
          'Tools are built and maintained by GitLab. What are tools?',
        );
        expect(toolsField.text()).toContain('None');
      });

      it('renders "System prompt"', () => {
        expect(configurationDetails.at(2).props()).toMatchObject({
          title: 'System prompt',
        });
      });

      it('renders "Managed by" field', () => {
        expect(findManagedByField().props('title')).toBe('Managed by');
        expect(findManagedByField().text()).toBe('GitLab');
      });
    });
  });

  describe('MCP Servers', () => {
    const mockAgentWithMcpServers = {
      ...mockAgent,
      latestVersion: {
        ...mockAgent.latestVersion,
        mcpServers: {
          nodes: [mockMcpServers[1], mockMcpServers[0]], // Unsorted to test sorting
        },
      },
    };

    describe('when user has permission', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: mockAgentWithMcpServers,
          },
          provide: {
            glAbilities: {
              readAiCatalogMcpServer: true,
            },
          },
        });
      });

      it('renders MCP servers field', () => {
        const configurationDetails = findAllFieldsForSection(1);
        const mcpServersField = configurationDetails.at(2);
        expect(mcpServersField.props('title')).toBe('MCP servers');
      });

      it('displays help text', () => {
        const configurationDetails = findAllFieldsForSection(1);
        const mcpServersField = configurationDetails.at(2);
        expect(mcpServersField.text()).toContain(
          'MCP servers allow your agent to connect with external tools.',
        );
      });

      it('displays MCP servers sorted alphabetically', () => {
        const tokens = wrapper.findAllComponents(GlToken);
        const mcpServerTokens = tokens.filter((token) => {
          const text = token.text();
          return text === 'Test MCP Server 1' || text === 'Test MCP Server 2';
        });

        expect(mcpServerTokens).toHaveLength(2);
        expect(mcpServerTokens.at(0).text()).toBe('Test MCP Server 1');
        expect(mcpServerTokens.at(1).text()).toBe('Test MCP Server 2');
      });

      it('displays MCP server descriptions as tooltips', () => {
        const mcpServerTooltips = wrapper.findAllByTestId('mcp-server-description-tooltip');
        expect(mcpServerTooltips).toHaveLength(2);
        expect(mcpServerTooltips.at(0).attributes('title')).toBe('Test MCP Server 1 description');
        expect(mcpServerTooltips.at(1).attributes('title')).toBe('Test MCP Server 2 description');
      });
    });

    describe('when user does not have permission', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: mockAgentWithMcpServers,
          },
          provide: {
            glAbilities: {
              readAiCatalogMcpServer: false,
            },
          },
        });
      });

      it('does not render MCP servers field', () => {
        const configurationDetails = findAllFieldsForSection(1);
        const mcpServersField = configurationDetails.wrappers.find(
          (field) => field.props('title') === 'MCP servers',
        );
        expect(mcpServersField).toBeUndefined();
      });
    });

    describe('when no MCP servers are configured', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: mockAgent,
          },
          provide: {
            glAbilities: {
              readAiCatalogMcpServer: true,
            },
          },
        });
      });

      it('displays "None"', () => {
        const configurationDetails = findAllFieldsForSection(1);
        const mcpServersField = configurationDetails.at(2);
        expect(mcpServersField.text()).toContain('None');
      });
    });
  });
});
