import { GlExperimentBadge, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogMcpServersShow from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_show.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import { AI_CATALOG_MCP_SERVERS_EDIT_ROUTE } from 'ee/ai/catalog/router/constants';
import { mockMcpServer } from '../mock_data';

describe('AiCatalogMcpServersShow', () => {
  let wrapper;

  const routeParams = { id: '1' };

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogMcpServersShow, {
      propsData: {
        aiCatalogMcpServer: mockMcpServer,
        ...propsData,
      },
      provide: {
        glAbilities: {
          updateAiCatalogMcpServer: false,
        },
        ...provide,
      },
      mocks: {
        $route: {
          params: routeParams,
        },
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findFormSection = () => wrapper.findComponent(FormSection);
  const findAllItemFields = () => wrapper.findAllComponents(AiCatalogItemField);
  const findAllLinks = () => wrapper.findAllComponents(GlLink);
  const findServerUrlLink = () => findAllLinks().at(0);
  const findHomepageLink = () => findAllLinks().at(1);
  const findEditButton = () => wrapper.findComponentByTestId('edit-mcp-server-button');

  describe('when data is provided via prop', () => {
    beforeEach(() => {
      createComponent({ provide: { glAbilities: { updateAiCatalogMcpServer: true } } });
    });

    it('renders page heading with server name', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(wrapper.text()).toContain('Test MCP Server');
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().props('type')).toBe('experiment');
    });

    it('renders server description', () => {
      expect(wrapper.text()).toContain('A test MCP server');
    });

    it('renders server URL as a link', () => {
      expect(findServerUrlLink().exists()).toBe(true);
      expect(findServerUrlLink().attributes('href')).toBe('https://example.com/mcp');
      expect(findServerUrlLink().attributes('target')).toBe('_blank');
    });

    it('renders homepage URL as a link', () => {
      expect(findHomepageLink().exists()).toBe(true);
      expect(findHomepageLink().attributes('href')).toBe('https://example.com');
      expect(findHomepageLink().attributes('target')).toBe('_blank');
    });

    it('renders configuration section with transport', () => {
      expect(findFormSection().exists()).toBe(true);
      expect(findFormSection().props('title')).toBe('Configuration');
      const itemFields = findAllItemFields();
      expect(itemFields.at(2).props('title')).toBe('Transport');
      expect(itemFields.at(2).props('value')).toBe('HTTP');
    });

    it('renders authentication type as OAuth', () => {
      const itemFields = findAllItemFields();
      expect(itemFields.at(3).props('title')).toBe('Authentication');
      expect(itemFields.at(3).props('value')).toBe('OAuth');
    });

    it('renders edit button when user has update permission', () => {
      expect(findEditButton().exists()).toBe(true);
      expect(findEditButton().props('to')).toEqual({
        name: AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
        params: { id: routeParams.id },
      });
    });
  });

  describe('when user does not have update permission', () => {
    beforeEach(() => {
      createComponent({ provide: { glAbilities: { updateAiCatalogMcpServer: false } } });
    });

    it('does not render edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('when server has NO_AUTH auth type', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          aiCatalogMcpServer: { ...mockMcpServer, authType: 'NO_AUTH' },
        },
      });
    });

    it('displays "No authentication" label', () => {
      const itemFields = findAllItemFields();
      expect(itemFields.at(3).props('title')).toBe('Authentication');
      expect(itemFields.at(3).props('value')).toBe('No authentication');
    });
  });

  describe('when server has no description', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          aiCatalogMcpServer: { ...mockMcpServer, description: null },
        },
      });
    });

    it('does not render description section', () => {
      expect(wrapper.findByText('Description').exists()).toBe(false);
    });
  });

  describe('when server has no homepage URL', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          aiCatalogMcpServer: { ...mockMcpServer, homepageUrl: null },
        },
      });
    });

    it('does not render homepage section', () => {
      expect(wrapper.findByText('Homepage').exists()).toBe(false);
    });
  });
});
