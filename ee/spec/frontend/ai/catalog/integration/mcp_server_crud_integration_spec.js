import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import AiCatalogMcpServersNew from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_new.vue';
import AiCatalogMcpServersEdit from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_edit.vue';
import aiCatalogMcpServerCreateMutation from 'ee/ai/catalog/graphql/mutations/ai_catalog_mcp_server_create.mutation.graphql';
import aiCatalogMcpServerUpdateMutation from 'ee/ai/catalog/graphql/mutations/ai_catalog_mcp_server_update.mutation.graphql';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import {
  mockMcpServer,
  mockCreateMcpServerSuccessMutation,
  mockCreateMcpServerErrorMutation,
  mockUpdateMcpServerSuccessMutation,
  mockUpdateMcpServerErrorMutation,
} from '../mock_data';
import { createIntegrationWrapper, EXPLORE_PROVIDE, ROUTE_PRESETS } from './helpers';

jest.mock('~/sentry/sentry_browser_wrapper');

const mockFormValues = {
  name: mockMcpServer.name,
  description: mockMcpServer.description,
  url: mockMcpServer.url,
  homepageUrl: mockMcpServer.homepageUrl,
  transport: mockMcpServer.transport,
  authType: mockMcpServer.authType,
  oauthClientId: mockMcpServer.oauthClientId,
  oauthClientSecret: '',
};

describe('MCP server — create page integration', () => {
  const mountCreatePage = (mutationHandler) =>
    createIntegrationWrapper(AiCatalogMcpServersNew, {
      provide: EXPLORE_PROVIDE,
      apolloHandlers: [[aiCatalogMcpServerCreateMutation, mutationHandler]],
      route: ROUTE_PRESETS.mcpServerNew,
    });

  const submitForm = (wrapper) =>
    wrapper.findComponent({ name: 'AiCatalogMcpServerForm' }).vm.$emit('submit', mockFormValues);

  it('fires create mutation, shows toast, and redirects to list', async () => {
    const handler = jest.fn().mockResolvedValue(mockCreateMcpServerSuccessMutation);
    const { wrapper, router } = mountCreatePage(handler);

    submitForm(wrapper);
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith({ input: mockFormValues });
    expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('MCP server created.');
    expect(router.currentRoute.name).toBe(ROUTE_PRESETS.mcpServerList.name);
  });

  it('shows error alert when mutation returns errors', async () => {
    const handler = jest.fn().mockResolvedValue(mockCreateMcpServerErrorMutation);
    const { wrapper, router } = mountCreatePage(handler);

    submitForm(wrapper);
    await waitForPromises();

    expect(wrapper.findComponent(ErrorsAlert).text()).toContain(
      mockCreateMcpServerErrorMutation.data.aiCatalogMcpServerCreate.errors[0],
    );
    expect(router.currentRoute.name).toBe(ROUTE_PRESETS.mcpServerNew.name);
  });

  it('shows error alert and captures exception on network failure', async () => {
    const error = new Error('Network error');
    const handler = jest.fn().mockRejectedValue(error);
    const { wrapper, router } = mountCreatePage(handler);

    submitForm(wrapper);
    await waitForPromises();

    expect(wrapper.findComponent(ErrorsAlert).text()).toContain(
      'Could not create MCP server. Please try again.',
    );
    expect(router.currentRoute.name).toBe(ROUTE_PRESETS.mcpServerNew.name);
    expect(Sentry.captureException).toHaveBeenCalledWith(error);
  });
});

describe('MCP server — edit page integration', () => {
  const mountEditPage = (mutationHandler) =>
    createIntegrationWrapper(AiCatalogMcpServersEdit, {
      provide: EXPLORE_PROVIDE,
      props: { aiCatalogMcpServer: mockMcpServer },
      apolloHandlers: [[aiCatalogMcpServerUpdateMutation, mutationHandler]],
      route: ROUTE_PRESETS.mcpServerEdit,
    });

  it('pre-populates form with current server values', async () => {
    const handler = jest.fn().mockResolvedValue(mockUpdateMcpServerSuccessMutation);
    const { wrapper } = mountEditPage(handler);
    await waitForPromises();

    const form = wrapper.findComponent({ name: 'AiCatalogMcpServerForm' });
    expect(form.props('initialValues')).toEqual({
      name: mockMcpServer.name,
      description: mockMcpServer.description,
      url: mockMcpServer.url,
      homepageUrl: mockMcpServer.homepageUrl,
      transport: mockMcpServer.transport,
      authType: mockMcpServer.authType,
      oauthClientId: mockMcpServer.oauthClientId,
    });
  });

  it('fires update mutation, shows toast, and redirects to show page', async () => {
    const handler = jest.fn().mockResolvedValue(mockUpdateMcpServerSuccessMutation);
    const { wrapper, router } = mountEditPage(handler);

    await waitForPromises(); // let initial router.push() settle (Vue Router 4 is async)
    const updateValues = { ...mockFormValues, name: 'Updated Name' };
    wrapper.findComponent({ name: 'AiCatalogMcpServerForm' }).vm.$emit('submit', updateValues);
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith({
      input: { id: mockMcpServer.id, ...updateValues },
    });
    expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('MCP server updated.');
    expect(router.currentRoute.name).toBe(ROUTE_PRESETS.mcpServerShow.name);
  });

  it('shows error alert when mutation returns errors', async () => {
    const handler = jest.fn().mockResolvedValue(mockUpdateMcpServerErrorMutation);
    const { wrapper, router } = mountEditPage(handler);

    wrapper.findComponent({ name: 'AiCatalogMcpServerForm' }).vm.$emit('submit', mockFormValues);
    await waitForPromises();

    expect(wrapper.findComponent(ErrorsAlert).text()).toContain(
      mockUpdateMcpServerErrorMutation.data.aiCatalogMcpServerUpdate.errors[0],
    );
    expect(router.currentRoute.name).toBe(ROUTE_PRESETS.mcpServerEdit.name);
  });

  it('shows error alert on network failure', async () => {
    const handler = jest.fn().mockRejectedValue(new Error('Network error'));
    const { wrapper, router } = mountEditPage(handler);

    wrapper.findComponent({ name: 'AiCatalogMcpServerForm' }).vm.$emit('submit', mockFormValues);
    await waitForPromises();

    expect(wrapper.findComponent(ErrorsAlert).text()).toContain(
      'Could not update MCP server. Please try again.',
    );
    expect(router.currentRoute.name).toBe(ROUTE_PRESETS.mcpServerEdit.name);
  });
});
