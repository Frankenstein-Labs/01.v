import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { ignoreConsoleMessages } from 'helpers/console_watcher';

import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
  AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
} from 'ee/ai/catalog/router/constants';

jest.mock('~/lib/utils/common_utils');

ignoreConsoleMessages([/Runtime directive used on component with non-element root node/]);

describe('AiCatalogNavTabs', () => {
  let wrapper;

  const defaultProps = {
    canAdmin: true,
    canCreate: true,
  };

  const createComponent = ({
    routeName = AI_CATALOG_AGENTS_ROUTE,
    isLoggedInValue = true,
    props = {},
    createAiCatalogMcpServer = false,
    readAiCatalog = false,
    isGlobalNamespace = false,
  } = {}) => {
    isLoggedIn.mockReturnValue(isLoggedInValue);

    wrapper = shallowMountExtended(AiCatalogNavActions, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $route: {
          name: routeName,
        },
      },
      provide: {
        isGlobalNamespace,
        glAbilities: {
          createAiCatalogMcpServer,
          readAiCatalog,
        },
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  describe('when on agents route', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders "New agent" button', () => {
      expect(findButton().props('to')).toEqual({ name: AI_CATALOG_AGENTS_NEW_ROUTE });
      expect(findButton().props('variant')).toBe('confirm');
      expect(findButton().text()).toBe('New agent');
    });

    describe('when user is not authenticated', () => {
      beforeEach(() => {
        createComponent({ isLoggedInValue: false });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when user does not have admin permissions', () => {
      beforeEach(() => {
        createComponent({ props: { canAdmin: false } });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when user does not have permission to create an item', () => {
      beforeEach(() => {
        createComponent({ props: { canCreate: false } });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });

  describe('when on flows route', () => {
    beforeEach(() => {
      createComponent({
        routeName: AI_CATALOG_FLOWS_ROUTE,
        props: { newButtonVariant: 'default' },
      });
    });

    it('renders "New flow" button', () => {
      expect(findButton().props('to')).toEqual({ name: AI_CATALOG_FLOWS_NEW_ROUTE });
      expect(findButton().props('variant')).toBe('default');
      expect(findButton().text()).toBe('New flow');
    });

    describe('when user is not authenticated', () => {
      beforeEach(() => {
        createComponent({
          routeName: AI_CATALOG_FLOWS_ROUTE,
          isLoggedInValue: false,
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when user does not have admin permissions', () => {
      beforeEach(() => {
        createComponent({
          routeName: AI_CATALOG_FLOWS_ROUTE,
          props: { canAdmin: false },
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when user does not have permission to create an item', () => {
      beforeEach(() => {
        createComponent({
          routeName: AI_CATALOG_FLOWS_ROUTE,
          props: { canCreate: false },
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });

  describe('when on MCP servers route', () => {
    describe('when user has create permission', () => {
      beforeEach(() => {
        createComponent({
          routeName: AI_CATALOG_MCP_SERVERS_ROUTE,
          createAiCatalogMcpServer: true,
        });
      });

      it('renders "New MCP server" button', () => {
        expect(findButton().props('to')).toEqual({ name: AI_CATALOG_MCP_SERVERS_NEW_ROUTE });
        expect(findButton().props('variant')).toBe('confirm');
        expect(findButton().text()).toBe('New MCP server');
      });

      describe('when user is not authenticated', () => {
        beforeEach(() => {
          createComponent({
            routeName: AI_CATALOG_MCP_SERVERS_ROUTE,
            isLoggedInValue: false,
            createAiCatalogMcpServer: true,
          });
        });

        it('does not render button', () => {
          expect(findButton().exists()).toBe(false);
        });
      });

      describe('when user does not have permission to create an item', () => {
        beforeEach(() => {
          createComponent({
            routeName: AI_CATALOG_MCP_SERVERS_ROUTE,
            props: { canAdmin: false },
            createAiCatalogMcpServer: true,
          });
        });

        it('does not render button', () => {
          expect(findButton().exists()).toBe(false);
        });
      });
    });

    describe('when user does not have create permission', () => {
      beforeEach(() => {
        createComponent({
          routeName: AI_CATALOG_MCP_SERVERS_ROUTE,
          createAiCatalogMcpServer: false,
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });

  describe('when on other route', () => {
    beforeEach(() => {
      createComponent({ routeName: AI_CATALOG_FLOWS_NEW_ROUTE });
    });

    it('does not render button', () => {
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('when on global namespace (Explore page)', () => {
    describe('when user has readAiCatalog ability', () => {
      beforeEach(() => {
        createComponent({
          isGlobalNamespace: true,
          readAiCatalog: true,
        });
      });

      it('renders "New agent" button', () => {
        expect(findButton().exists()).toBe(true);
        expect(findButton().props('to')).toEqual({ name: AI_CATALOG_AGENTS_NEW_ROUTE });
      });
    });

    describe('when user does not have readAiCatalog ability', () => {
      beforeEach(() => {
        createComponent({
          isGlobalNamespace: true,
          readAiCatalog: false,
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when user is not logged in', () => {
      beforeEach(() => {
        createComponent({
          isGlobalNamespace: true,
          isLoggedInValue: false,
          readAiCatalog: false,
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });
});
