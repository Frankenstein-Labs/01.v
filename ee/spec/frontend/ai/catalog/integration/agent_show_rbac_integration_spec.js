import waitForPromises from 'helpers/wait_for_promises';
import * as commonUtils from '~/lib/utils/common_utils';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import aiCatalogProjectsMaintainerQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_projects_maintainer.query.graphql';
import { mockVersionProp } from '../mock_data';
import {
  createIntegrationWrapper,
  openActionsDropdown,
  expectActions,
  ACTION_STATE,
  EXPLORE_PROVIDE,
  PROJECT_PROVIDE,
  GROUP_PROVIDE,
  EXTERNAL_PROJECT_PROVIDE,
  EXTERNAL_GROUP_PROVIDE,
  ROUTE_PRESETS,
} from './helpers';
import { createAgentWithPermissions, createProjectsMaintainerHandler } from './mock_data_factories';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

describe('Agent — show page and RBAC integration', () => {
  describe('Show page — renders details', () => {
    const mountShow = ({ agent, provide = {} } = {}) => {
      const defaultAgent = agent || createAgentWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: { ...PROJECT_PROVIDE, ...provide },
        props: {
          aiCatalogItem: defaultAgent,
          version: mockVersionProp,
        },
        route: ROUTE_PRESETS.agentShow,
      });
    };

    it('renders agent name, description, system prompt, type, and visibility', async () => {
      const { wrapper } = mountShow();
      await waitForPromises();

      expect(wrapper.text()).toContain('Test AI Agent 1');
      expect(wrapper.text()).toContain('A helpful AI assistant for testing purposes');
      expect(wrapper.text()).toContain('The system prompt');
      expect(wrapper.text()).toContain('Custom');
      expect(wrapper.text()).toContain('Visibility');
    });
  });

  describe('Show page RBAC — Explore namespace', () => {
    afterEach(() => {
      commonUtils.isLoggedIn.mockReturnValue(true);
    });

    const mountExplore = ({ agent, permissionOverrides = {} } = {}) => {
      const defaultAgent = agent || createAgentWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: {
          ...EXPLORE_PROVIDE,
          glAbilities: { ...EXPLORE_PROVIDE.glAbilities, ...permissionOverrides },
        },
        props: {
          aiCatalogItem: defaultAgent,
          version: mockVersionProp,
        },
        apolloHandlers: [[aiCatalogProjectsMaintainerQuery, createProjectsMaintainerHandler()]],
        route: ROUTE_PRESETS.agentShow,
      });
    };

    it('user without item permissions sees Enable, Duplicate, and Report', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountExplore({
        agent,
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

    it('user without item permissions does NOT see Enable for foundational agent', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
      });
      const { wrapper } = mountExplore({
        agent,
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'duplicate-button': ACTION_STATE.VISIBLE,
        'enable-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('unauthenticated user sees disabled Enable button with tooltip', async () => {
      commonUtils.isLoggedIn.mockReturnValue(false);

      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountExplore({
        agent,
        permissionOverrides: { reportAiCatalogItem: false },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.DISABLED,
        'more-actions-dropdown': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('private item with existing group config shows active Enable on Explore', async () => {
      const agent = createAgentWithPermissions({
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
        agent,
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

    it('private item without group config shows active Enable on Explore', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        isPublic: false,
        groupConfigEnabled: false,
        // Owning project also not yet enabled — same reason as above.
        projectConfigEnabled: false,
      });
      const { wrapper } = mountExplore({
        agent,
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

  describe('Show page RBAC — Project namespace', () => {
    const mountProject = ({ agent, permissionOverrides = {} } = {}) => {
      const defaultAgent = agent || createAgentWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: { ...PROJECT_PROVIDE, glAbilities: permissionOverrides },
        props: {
          aiCatalogItem: defaultAgent,
          version: mockVersionProp,
        },
        route: ROUTE_PRESETS.agentShow,
      });
    };

    it('item admin sees all actions when enabled', async () => {
      const agent = createAgentWithPermissions({ projectConfigEnabled: true });
      const { wrapper } = mountProject({
        agent,
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
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        projectConfigEnabled: false,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('consumer admin sees Enable and Disable when public item is enabled', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        projectConfigEnabled: true,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: false },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('user with no permissions sees no action buttons', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: false },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'more-actions-dropdown': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.DISABLED,
        'delete-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('instance admin sees hard Delete option', async () => {
      const agent = createAgentWithPermissions();
      const { wrapper } = mountProject({
        agent,
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

    it('user with only reportAiCatalogItem sees Report', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'report-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.DISABLED,
        'delete-button': ACTION_STATE.HIDDEN,
      });
    });

    it('user with reportAiCatalogItem does NOT see Report on foundational agents', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'report-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
    });

    it('private item not enabled — consumer admin sees Enable', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        isPublic: false,
        projectConfigEnabled: false,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: false },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('private item already enabled — consumer admin sees Disable but not Enable', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        isPublic: false,
        projectConfigEnabled: true,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: false },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'disable-button': ACTION_STATE.VISIBLE,
        'enable-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
        'report-button': ACTION_STATE.HIDDEN,
      });
    });

    it('consumer admin does NOT see Enable for foundational agent when disabled', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
        projectConfigEnabled: false,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
      });
    });

    it('consumer admin does NOT see Disable for foundational agent when enabled', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
        projectConfigEnabled: true,
      });
      const { wrapper } = mountProject({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'disable-button': ACTION_STATE.HIDDEN,
        'more-actions-dropdown': ACTION_STATE.HIDDEN,
      });
    });

    it('item admin does NOT see Enable/Disable for foundational agent', async () => {
      const agent = createAgentWithPermissions({
        foundational: true,
        projectConfigEnabled: false,
      });
      const { wrapper } = mountProject({
        agent,
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.VISIBLE,
        'duplicate-button': ACTION_STATE.VISIBLE,
        'delete-button': ACTION_STATE.VISIBLE,
      });
    });
  });

  describe('Show page RBAC — Group namespace', () => {
    const mountGroup = ({ agent, permissionOverrides = {} } = {}) => {
      const defaultAgent = agent || createAgentWithPermissions();
      return createIntegrationWrapper(AiCatalogItemShow, {
        provide: { ...GROUP_PROVIDE, glAbilities: permissionOverrides },
        props: {
          aiCatalogItem: defaultAgent,
          version: mockVersionProp,
        },
        route: ROUTE_PRESETS.agentShow,
      });
    };

    it('consumer admin sees Disable and Report when enabled', async () => {
      const agent = createAgentWithPermissions({ groupConfigEnabled: true });
      const { wrapper } = mountGroup({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'disable-dropdown-item': ACTION_STATE.VISIBLE,
        'report-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
    });

    it('user with reportAiCatalogItem sees only Report', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
      });
      const { wrapper } = mountGroup({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: true },
      });
      await waitForPromises();
      await openActionsDropdown(wrapper);

      await expectActions(wrapper, {
        'report-button': ACTION_STATE.VISIBLE,
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
    });

    it('user with reportAiCatalogItem does NOT see Report on foundational agents', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        foundational: true,
      });
      const { wrapper } = mountGroup({
        agent,
        permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: true },
      });
      await waitForPromises();

      await expectActions(wrapper, {
        'report-button': ACTION_STATE.HIDDEN,
        'edit-button': ACTION_STATE.HIDDEN,
        'enable-button': ACTION_STATE.HIDDEN,
        'duplicate-button': ACTION_STATE.HIDDEN,
        'disable-button': ACTION_STATE.HIDDEN,
        'delete-button': ACTION_STATE.HIDDEN,
      });
    });
  });

  describe('User interacts with an agent from groups and projects that do not own the agent', () => {
    // The agent is owned by group-1, but the user browses from group-2.
    // Item-level actions (Edit, Delete) require ownership of the agent —
    // cross-namespace users never see these.
    // Consumer-level actions (Enable, Disable) depend on the user's role
    // in the browsing namespace, independent of the agent's owner.

    describe('Browsing from a project whose group does not own the agent', () => {
      const mountExternalProject = ({
        agent,
        permissionOverrides = {},
        duoSettingsOverrides = {},
      } = {}) => {
        const defaultAgent = agent || createAgentWithPermissions();
        return createIntegrationWrapper(AiCatalogItemShow, {
          provide: {
            ...EXTERNAL_PROJECT_PROVIDE,
            glAbilities: permissionOverrides,
            duoSettings: {
              ...EXTERNAL_PROJECT_PROVIDE.duoSettings,
              ...duoSettingsOverrides,
            },
          },
          props: {
            aiCatalogItem: defaultAgent,
            version: mockVersionProp,
          },
          route: ROUTE_PRESETS.agentShow,
        });
      };

      it('project maintainer sees Enable, Disable, and Report but not Edit/Delete', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
          projectConfigEnabled: true,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
        });
        await waitForPromises();
        await openActionsDropdown(wrapper);

        await expectActions(wrapper, {
          'enable-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.VISIBLE,
          'report-button': ACTION_STATE.VISIBLE,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
        });
      });

      it('project maintainer sees Enable and Report when not yet enabled', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
          projectConfigEnabled: false,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'enable-button': ACTION_STATE.VISIBLE,
          'report-button': ACTION_STATE.VISIBLE,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.HIDDEN,
        });
      });

      it('user with no permissions sees no actions', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: false },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'report-button': ACTION_STATE.HIDDEN,
          'enable-button': ACTION_STATE.HIDDEN,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.DISABLED,
        });
      });

      it('when custom agents are disabled in duo settings', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: true,
          projectConfigEnabled: false,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: {
            adminAiCatalogItemConsumer: true,
            reportAiCatalogItem: true,
          },
          duoSettingsOverrides: { duoCustomAgentsEnabled: false },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'enable-button': ACTION_STATE.DISABLED,
          'report-button': ACTION_STATE.VISIBLE,
          'edit-button': ACTION_STATE.VISIBLE,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.VISIBLE,
          'disable-button': ACTION_STATE.HIDDEN,
        });
      });

      it('user who can report sees only Report', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: true },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'report-button': ACTION_STATE.VISIBLE,
          'enable-button': ACTION_STATE.HIDDEN,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.DISABLED,
        });
      });

      it('private item already enabled — project maintainer sees Disable but not Enable', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
          isPublic: false,
          projectConfigEnabled: true,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: false },
        });
        await waitForPromises();
        await openActionsDropdown(wrapper);

        await expectActions(wrapper, {
          'disable-button': ACTION_STATE.VISIBLE,
          'enable-button': ACTION_STATE.HIDDEN,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'report-button': ACTION_STATE.HIDDEN,
        });
      });

      it('private item not enabled — project maintainer sees disabled Enable with managing-project tooltip', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
          isPublic: false,
          projectConfigEnabled: false,
        });
        const { wrapper } = mountExternalProject({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'enable-button': ACTION_STATE.DISABLED,
          'report-button': ACTION_STATE.VISIBLE,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.HIDDEN,
        });
        expect(wrapper.findByTestId('enable-button-wrapper').attributes('title')).toBe(
          `This private agent is managed by ${agent.project.nameWithNamespace} and can't be enabled from this project.`,
        );
      });
    });

    describe('Browsing from a group that does not own the agent', () => {
      const mountExternalGroup = ({ agent, permissionOverrides = {} } = {}) => {
        const defaultAgent = agent || createAgentWithPermissions();
        return createIntegrationWrapper(AiCatalogItemShow, {
          provide: { ...EXTERNAL_GROUP_PROVIDE, glAbilities: permissionOverrides },
          props: {
            aiCatalogItem: defaultAgent,
            version: mockVersionProp,
          },
          route: ROUTE_PRESETS.agentShow,
        });
      };

      it('group maintainer sees Disable and Report when enabled but not Edit/Delete/Duplicate', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
          groupConfigEnabled: true,
        });
        const { wrapper } = mountExternalGroup({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: true, reportAiCatalogItem: true },
        });
        await waitForPromises();
        await openActionsDropdown(wrapper);

        await expectActions(wrapper, {
          'disable-dropdown-item': ACTION_STATE.VISIBLE,
          'report-button': ACTION_STATE.VISIBLE,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'enable-button': ACTION_STATE.HIDDEN,
        });
      });

      it('user with no permissions sees no actions', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
          reportAiCatalogItem: false,
        });
        const { wrapper } = mountExternalGroup({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: false },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'report-button': ACTION_STATE.HIDDEN,
          'enable-button': ACTION_STATE.HIDDEN,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.HIDDEN,
        });
      });

      it('user who can report sees only Report', async () => {
        const agent = createAgentWithPermissions({
          adminAiCatalogItem: false,
        });
        const { wrapper } = mountExternalGroup({
          agent,
          permissionOverrides: { adminAiCatalogItemConsumer: false, reportAiCatalogItem: true },
        });
        await waitForPromises();

        await expectActions(wrapper, {
          'report-button': ACTION_STATE.VISIBLE,
          'enable-button': ACTION_STATE.HIDDEN,
          'edit-button': ACTION_STATE.HIDDEN,
          'duplicate-button': ACTION_STATE.HIDDEN,
          'delete-button': ACTION_STATE.HIDDEN,
          'disable-button': ACTION_STATE.HIDDEN,
        });
      });
    });
  });
});
