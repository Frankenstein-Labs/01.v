import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlExperimentBadge } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import aiCatalogMcpServerCreateMutation from 'ee/ai/catalog/graphql/mutations/ai_catalog_mcp_server_create.mutation.graphql';
import AiCatalogMcpServersNew from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_new.vue';
import AiCatalogMcpServerForm from 'ee/ai/catalog/components/ai_catalog_mcp_server_form.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_MCP_SERVERS_ROUTE } from 'ee/ai/catalog/router/constants';
import { mockCreateMcpServerSuccessMutation, mockCreateMcpServerErrorMutation } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogMcpServersNew', () => {
  let wrapper;

  const createMcpServerMock = jest.fn().mockResolvedValue(mockCreateMcpServerSuccessMutation);
  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = ({ provide = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [aiCatalogMcpServerCreateMutation, createMcpServerMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogMcpServersNew, {
      apolloProvider,
      provide: {
        ...provide,
      },
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
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
      expect(findPageHeading().text()).toContain('New MCP server');
      expect(findPageHeading().text()).toContain(
        'Add a Model Context Protocol server to extend agent capabilities.',
      );
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('experiment');
    });
  });

  describe('Form Rendering', () => {
    it('renders the MCP server form with correct props', () => {
      expect(findForm().exists()).toBe(true);
      expect(findForm().props('isLoading')).toBe(false);
      expect(findForm().props('errors')).toEqual([]);
    });
  });

  describe('Form Submit', () => {
    const formValues = {
      name: 'Test MCP Server',
      description: 'Test description',
      url: 'https://example.com/mcp',
      homepageUrl: 'https://example.com',
      transport: 'HTTP',
      authType: 'OAUTH',
      oauthClientId: 'client-id',
      oauthClientSecret: 'client-secret',
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends a create request', () => {
      submitForm();

      expect(createMcpServerMock).toHaveBeenCalledTimes(1);
      expect(createMcpServerMock).toHaveBeenCalledWith({
        input: formValues,
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

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('MCP server created.');
      });

      it('navigates to MCP servers list page', () => {
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_MCP_SERVERS_ROUTE,
        });
      });

      it('stops loading state', () => {
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createMcpServerMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errors')).toEqual([
          'Could not create MCP server. Please try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-errors');

        expect(findForm().props('errors')).toEqual([]);
      });
    });

    describe('when request succeeds but returns error', () => {
      beforeEach(async () => {
        createMcpServerMock.mockResolvedValue(mockCreateMcpServerErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert with error message', () => {
        expect(findForm().props('errors')).toEqual([
          mockCreateMcpServerErrorMutation.data.aiCatalogMcpServerCreate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('does not show toast', () => {
        expect(mockToast.show).not.toHaveBeenCalled();
      });

      it('does not navigate away', () => {
        expect(mockRouter.push).not.toHaveBeenCalled();
      });
    });
  });

  describe('Form Cancel', () => {
    it('navigates to MCP servers list page when cancel is emitted', () => {
      findForm().vm.$emit('cancel');

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: AI_CATALOG_MCP_SERVERS_ROUTE,
      });
    });
  });

  describe('Error Handling', () => {
    it('resets error messages when dismiss-errors is emitted', async () => {
      // First, create an error state
      createMcpServerMock.mockRejectedValue(new Error());
      findForm().vm.$emit('submit', {
        name: 'Test',
        url: 'https://example.com',
        transport: 'HTTP',
        authType: 'OAUTH',
      });
      await waitForPromises();

      expect(findForm().props('errors')).toEqual([
        'Could not create MCP server. Please try again.',
      ]);

      // Then dismiss the errors
      await findForm().vm.$emit('dismiss-errors');

      expect(findForm().props('errors')).toEqual([]);
    });
  });
});
