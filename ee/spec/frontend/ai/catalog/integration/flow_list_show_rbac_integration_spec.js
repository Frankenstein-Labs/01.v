import waitForPromises from 'helpers/wait_for_promises';
import { SkipReason, itSkipVue3 } from 'helpers/vue3_conditional';
import * as commonUtils from '~/lib/utils/common_utils';
import { AI_CATALOG_TYPE_FLOW } from 'ee/ai/catalog/constants';
import AiCatalogItemsIndex from 'ee/ai/catalog/pages/ai_catalog_items_index.vue';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import AiCatalogItemNew from 'ee/ai/catalog/pages/ai_catalog_item_new.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import aiCatalogItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_items.query.graphql';
import aiCatalogProjectsMaintainerQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_projects_maintainer.query.graphql';
import { mockVersionProp, mockCatalogFlowsResponse, mockFlowVersion } from '../mock_data';
import {
  createIntegrationWrapper,
  openActionsDropdown,
  expectActions,
  ACTION_STATE,
  EXPLORE_PROVIDE,
  PROJECT_PROVIDE,
  GROUP_PROVIDE,
  ROUTE_PRESETS,
  SourceEditorStub,
} from './helpers';
import { createFlowWithPermissions, createProjectsMaintainerHandler } from './mock_data_factories';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

describe('Flow — list, show, and RBAC integration', () => {
  describe('List page — renders flows', () => {
    const mountList = ({ queryHandler, searchTerm = '' } = {}) => {
      const handler = queryHandler || jest.fn().mockResolvedValue(mockCatalogFlowsResponse);
      return createIntegrationWrapper(AiCatalogItemsIndex, {
        props: { itemType: AI_CATALOG_TYPE_FLOW },
        provide: PROJECT_PROVIDE,
        apolloHandlers: [[aiCatalogItemsQuery, handler]],
        route: {
          ...ROUTE_PRESETS.flowList,
          query: searchTerm ? { search: searchTerm } : {},
        },
      });
    };

    it('renders flow items from query response', async () => {
      const { wrapper } = mountList();
      await waitForPromises();

      const items = wrapper.findAllByTestId('ai-catalog-item');
      expect(items).toHaveLength(3);
      expect(items.at(0).text()).toContain('Test AI Flow 1');
      expect(items.at(1).text()).toContain('Test AI Flow 2');
      expect(items.at(2).text()).toContain('Test AI Flow 3');
    });

    it('shows empty state when no flows exist', async () => {
      const emptyResponse = {
        data: {
          aiCatalogItems: {
            nodes: [],
            pageInfo: {
              hasNextPage: false,
              hasPreviousPage: false,
              startCursor: null,
              endCursor: null,
            },
            __typename: 'AiCatalogItemConnection',
          },
        },
      };

      const { wrapper } = mountList({
        queryHandler: jest.fn().mockResolvedValue(emptyResponse),
      });
      await waitForPromises();

      const items = wrapper.findAllByTestId('ai-catalog-item');
      expect(items).toHaveLength(0);
      expect(wrapper.text()).toContain('Get started with the AI Catalog');
    });

    it('passes search term from route to GraphQL query variables', async () => {
      const handler = jest.fn().mockResolvedValue(mockCatalogFlowsResponse);
      mountList({ queryHandler: handler, searchTerm: 'Flow 1' });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(expect.objectContaining({ search: 'Flow 1' }));
    });
  });

  describe('Show page — renders details', () => {
    const mountShow = ({ flow, provide = {}, apolloHandlers = [] } = {}) => {
      const defaultFlow = flow || createFlowWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: { ...PROJECT_PROVIDE, ...provide },
        props: {
          aiCatalogItem: defaultFlow,
          version: mockVersionProp,
        },
        apolloHandlers,
        route: ROUTE_PRESETS.flowShow,
        stubs: { SourceEditor: SourceEditorStub },
      });
    };

    it('displays flow name, description, YAML definition, visibility, and version metadata', async () => {
      const { wrapper } = mountShow();
      await waitForPromises();

      const heading = wrapper.findByTestId('page-heading');
      const description = wrapper.findByTestId('page-heading-description');
      expect(heading.text()).toContain('Test AI Flow 1');
      expect(description.text()).toContain('A helpful AI flow for testing purposes');
      expect(wrapper.findByTestId('configuration-field').find('textarea').element.value).toBe(
        mockFlowVersion.definition,
      );
      expect(wrapper.findByTestId('metadata-version').text()).toContain('v1.0.0-draft');
      expect(wrapper.text()).toContain('Public');
    });
  });

  describe('Show page RBAC — Explore namespace', () => {
    afterEach(() => {
      commonUtils.isLoggedIn.mockReturnValue(true);
    });

    const mountExplore = ({ flow, permissionOverrides = {} } = {}) => {
      const defaultFlow = flow || createFlowWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: {
          ...EXPLORE_PROVIDE,
          glAbilities: { ...EXPLORE_PROVIDE.glAbilities, ...permissionOverrides },
        },
        props: {
          aiCatalogItem: defaultFlow,
          version: mockVersionProp,
        },
        apolloHandlers: [[aiCatalogProjectsMaintainerQuery, createProjectsMaintainerHandler()]],
        route: ROUTE_PRESETS.flowShow,
      });
    };

    it('user without item permissions sees Enable, Duplicate, and Report', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountExplore({
        flow,
        permissionOverrides: { reportAiCatalogItem: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
        'duplicate-button': ACTION_STATE.VISIBLE,
        'report-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
    });

    it('user without item permissions does NOT see Duplicate for foundational flow', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
      });
      const { wrapper } = mountExplore({
        flow,
        permissionOverrides: { reportAiCatalogItem: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'duplicate-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('unauthenticated user sees disabled Enable button with tooltip', async () => {
      commonUtils.isLoggedIn.mockReturnValue(false);

      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountExplore({
        flow,
        permissionOverrides: { reportAiCatalogItem: false },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'more-actions-dropdown': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.DISABLED,
      });
    });

    it('private flow with existing group config shows active Enable on Explore', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        isPublic: false,
        groupConfigEnabled: true,
        // Not yet enabled in the owning project — only the group has a config.
        // Without this, the factory's default `projectConfigEnabled: true`
        // would imply the owning project is already enabled and the Enable
        // button would be disabled with an "already enabled" tooltip.
        projectConfigEnabled: false,
      });
      const { wrapper } = mountExplore({
        flow,
        permissionOverrides: { reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
        'duplicate-button': ACTION_STATE.VISIBLE,
        'report-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
      expect(wrapper.findByTestId('enable-button-wrapper').attributes('title')).toBe(undefined);
    });

    it('private flow without group config shows active Enable on Explore', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        isPublic: false,
        groupConfigEnabled: false,
        // Owning project also not yet enabled — same reason as above.
        projectConfigEnabled: false,
      });
      const { wrapper } = mountExplore({
        flow,
        permissionOverrides: { reportAiCatalogItem: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
        'duplicate-button': ACTION_STATE.VISIBLE,
        'report-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
      expect(wrapper.findByTestId('enable-button-wrapper').attributes('title')).toBe(undefined);
    });
  });

  describe('Show page RBAC — Group namespace', () => {
    const mountGroup = ({ flow, permissionOverrides = {} } = {}) => {
      const defaultFlow = flow || createFlowWithPermissions({ withProjectConfig: false });
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: { ...GROUP_PROVIDE, glAbilities: permissionOverrides },
        props: {
          aiCatalogItem: defaultFlow,
          version: mockVersionProp,
        },
        route: ROUTE_PRESETS.flowShow,
      });
    };

    it('consumer admin sees Disable and Report when enabled but not Edit/Delete/Duplicate', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        withProjectConfig: false,
        groupConfigEnabled: true,
      });
      const { wrapper } = mountGroup({
        flow,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'disable-dropdown-item': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.VISIBLE,
      });
    });

    it('user with reportAiCatalogItem sees Report', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        withProjectConfig: false,
      });
      const { wrapper } = mountGroup({ flow, permissionOverrides: { reportAiCatalogItem: true } });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'report-button': ACTION_STATE.VISIBLE,
      });
    });

    it('user with reportAiCatalogItem does NOT see Report on foundational flows', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
        withProjectConfig: false,
      });
      const { wrapper } = mountGroup({ flow, permissionOverrides: { reportAiCatalogItem: true } });
      await waitForPromises();

      await expectActions(wrapper, {
        'report-button': ACTION_STATE.HIDDEN,
      });
    });
  });

  describe('Show page RBAC — Project namespace', () => {
    const mountProject = ({ flow, permissionOverrides = {} } = {}) => {
      const defaultFlow = flow || createFlowWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: { ...PROJECT_PROVIDE, glAbilities: permissionOverrides },
        props: {
          aiCatalogItem: defaultFlow,
          version: mockVersionProp,
        },
        route: ROUTE_PRESETS.flowShow,
      });
    };

    it('item admin sees all actions when public flow is enabled', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: true,
        projectConfigEnabled: true,
        isPublic: true,
      });
      const { wrapper } = mountProject({
        flow,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'edit-button': ACTION_STATE.VISIBLE,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.VISIBLE,
        'delete-button': ACTION_STATE.VISIBLE,
        'disable-button': ACTION_STATE.VISIBLE,
        'report-button': ACTION_STATE.VISIBLE,
      });
    });

    it('consumer admin (non-item-admin) sees Enable when not enabled', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        projectConfigEnabled: false,
        isPublic: false,
      });
      const { wrapper } = mountProject({
        flow,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.VISIBLE,
      });
    });

    it('consumer admin sees Enable and Disable when public flow is enabled', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
        projectConfigEnabled: true,
      });
      const { wrapper } = mountProject({
        flow,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.VISIBLE,
      });
    });

    it('user with no permissions sees no action buttons', async () => {
      const flow = createFlowWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountProject({
        flow,
        permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: false },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'more-actions-dropdown': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.DISABLED,
        'enable-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('instance admin sees hard Delete option', async () => {
      const flow = createFlowWithPermissions();
      const { wrapper } = mountProject({
        flow,
        permissionOverrides: {
          adminAiCatalogItemConsumer: true,
          forceHardDeleteAiCatalogItem: true,
          reportAiCatalogItem: true,
        },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'edit-button': ACTION_STATE.VISIBLE,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.VISIBLE,
        'delete-button': ACTION_STATE.VISIBLE,
        'disable-button': ACTION_STATE.VISIBLE,
        'report-button': ACTION_STATE.VISIBLE,
      });
      expect(wrapper.findByTestId('delete-button').text()).toContain('Delete');
    });
  });

  describe('Protected page redirects — unauthorized users', () => {
    it('user without item admin permission is redirected away from create page', async () => {
      const { router } = createIntegrationWrapper(AiCatalogItemNew, {
        provide: {
          ...PROJECT_PROVIDE,
          glAbilities: { adminAiCatalogItem: false },
        },
        props: {
          itemType: AI_CATALOG_TYPE_FLOW,
        },
        apolloHandlers: [],
        route: ROUTE_PRESETS.flowNew,
        stubs: { SourceEditor: SourceEditorStub },
      });
      await waitForPromises();

      expect(router.currentRoute.name).toBe('ai-catalog-flows');
    });

    itSkipVue3(
      new SkipReason({
        name: 'user without item admin permission is redirected away from edit page',
        reason: '$route.params.id unavailable in created() with Vue Router 4',
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/593908',
      }),
      async () => {
        const flow = createFlowWithPermissions({ adminAiCatalogItem: false });
        const { router } = createIntegrationWrapper(AiCatalogItemEdit, {
          provide: PROJECT_PROVIDE,
          props: {
            aiCatalogItem: flow,
            version: mockVersionProp,
          },
          apolloHandlers: [],
          route: ROUTE_PRESETS.flowEdit,
          stubs: { SourceEditor: SourceEditorStub },
        });
        await waitForPromises();

        // eslint-disable-next-line jest/no-standalone-expect
        expect(router.currentRoute.name).toBe('ai-catalog-flows-show');
      },
    );

    itSkipVue3(
      new SkipReason({
        name: 'user without item admin permission is redirected away from duplicate page',
        reason: '$route.params.id unavailable in created() with Vue Router 4',
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/593908',
      }),
      async () => {
        const flow = createFlowWithPermissions({ adminAiCatalogItem: false });
        const { router } = createIntegrationWrapper(AiCatalogItemDuplicate, {
          provide: {
            ...PROJECT_PROVIDE,
            glAbilities: { adminAiCatalogItem: false },
            glFeatures: {},
          },
          props: { aiCatalogItem: flow },
          apolloHandlers: [],
          route: ROUTE_PRESETS.flowDuplicate,
          stubs: { SourceEditor: SourceEditorStub },
        });
        await waitForPromises();

        // eslint-disable-next-line jest/no-standalone-expect
        expect(router.currentRoute.name).toBe('ai-catalog-flows-show');
      },
    );
  });
});
