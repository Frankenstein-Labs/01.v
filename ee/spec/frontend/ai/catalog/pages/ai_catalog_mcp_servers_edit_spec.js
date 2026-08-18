import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlExperimentBadge } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import aiCatalogMcpServerUpdateMutation from 'ee/ai/catalog/graphql/mutations/ai_catalog_mcp_server_update.mutation.graphql';
import AiCatalogMcpServersEdit from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_edit.vue';
import AiCatalogMcpServerForm from 'ee/ai/catalog/components/ai_catalog_mcp_server_form.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_MCP_SERVERS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockMcpServer,
  mockUpdateMcpServerSuccessMutation,
  mockUpdateMcpServerErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogMcpServersEdit', () => {
  let wrapper;

  const updateMcpServerMock = jest.fn().mockResolvedValue(mockUpdateMcpServerSuccessMutation);
  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };
  const routeParams = { id: '1' };

  const createComponent = ({ props = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [aiCatalogMcpServerUpdateMutation, updateMcpServerMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogMcpServersEdit, {
      apolloProvider,
      propsData: {
        aiCatalogMcpServer: mockMcpServer,
        ...props,
      },
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
        $route: { params: routeParams },
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogMcpServerForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);

  beforeEach(() => {
    createComponent();
  });

  describe('Page Heading', () => {
    it('renders page heading with correct title and description', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('Edit MCP server');
      expect(findPageHeading().text()).toContain('Update the settings for this MCP server.');
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('experiment');
    });
  });

  describe('Form Rendering', () => {
    it('renders the MCP server form in edit mode', () => {
      expect(findForm().exists()).toBe(true);
      expect(findForm().props('mode')).toBe('edit');
      expect(findForm().props('isLoading')).toBe(false);
      expect(findForm().props('errors')).toEqual([]);
    });

    it('passes initial values from the MCP server prop', () => {
      expect(findForm().props('initialValues')).toEqual({
        name: mockMcpServer.name,
        description: mockMcpServer.description,
        url: mockMcpServer.url,
        homepageUrl: mockMcpServer.homepageUrl,
        transport: mockMcpServer.transport,
        authType: mockMcpServer.authType,
        oauthClientId: mockMcpServer.oauthClientId,
      });
    });
  });

  describe('Form Submit', () => {
    const formValues = {
      name: 'Updated MCP Server',
      description: 'Updated description',
      url: 'https://example.com/mcp-updated',
      homepageUrl: 'https://example.com/updated',
      transport: 'HTTP',
      authType: 'OAUTH',
      oauthClientId: 'new-client-id',
      oauthClientSecret: 'new-client-secret',
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends an update request with the MCP server ID', () => {
      submitForm();

      expect(updateMcpServerMock).toHaveBeenCalledTimes(1);
      expect(updateMcpServerMock).toHaveBeenCalledWith({
        input: { id: mockMcpServer.id, ...formValues },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows a success toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('MCP server updated.');
      });

      it('navigates to MCP server show page', () => {
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
          params: { id: routeParams.id },
        });
      });

      it('stops loading state', () => {
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request fails with a network error', () => {
      beforeEach(async () => {
        updateMcpServerMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception in Sentry', () => {
        expect(findForm().props('errors')).toEqual([
          'Could not update MCP server. Please try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-errors');

        expect(findForm().props('errors')).toEqual([]);
      });
    });

    describe('when request succeeds but returns errors', () => {
      beforeEach(async () => {
        updateMcpServerMock.mockResolvedValue(mockUpdateMcpServerErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert with the error message', () => {
        expect(findForm().props('errors')).toEqual([
          mockUpdateMcpServerErrorMutation.data.aiCatalogMcpServerUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('does not show a toast', () => {
        expect(mockToast.show).not.toHaveBeenCalled();
      });

      it('does not navigate away', () => {
        expect(mockRouter.push).not.toHaveBeenCalled();
      });
    });
  });
});
