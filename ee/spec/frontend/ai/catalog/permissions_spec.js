import { isLoggedIn } from '~/lib/utils/common_utils';
import {
  canAdminItem,
  canAdminAiCatalogItem,
  canCreateAiCatalogAgent,
  canCreateAiCatalogFlow,
  canCreateAiCatalogItem,
  canCreateThirdPartyFlow,
  canEditAiCatalogItem,
  canEditThirdPartyFlow,
  canDuplicateAiCatalogItem,
  canReportAiCatalogItem,
  canDeleteAiCatalogItem,
  canReadMcpServer,
  canEnableAiCatalogItem,
  canEnableAiCatalogItemInCurrentContext,
  canManageAiFlowTriggers,
  isItemTypeEnabledInDuoSettings,
  showTypeSelectionInAgentForm,
} from 'ee/ai/catalog/permissions';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from 'ee/ai/catalog/constants';

jest.mock('~/lib/utils/common_utils');

describe('AI Catalog Permissions', () => {
  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
  });

  describe('canAdminItem', () => {
    it('returns false when item is null or undefined', () => {
      expect(canAdminItem(null)).toBe(false);
      expect(canAdminItem(undefined)).toBe(false);
    });

    it('returns false when adminAiCatalogItem is false', () => {
      expect(canAdminItem({ userPermissions: { adminAiCatalogItem: false } })).toBe(false);
    });

    it('returns true when adminAiCatalogItem is true', () => {
      expect(canAdminItem({ userPermissions: { adminAiCatalogItem: true } })).toBe(true);
    });
  });

  describe('canAdminAiCatalogItem', () => {
    it('returns false when item has no admin permission', () => {
      expect(
        canAdminAiCatalogItem(
          { userPermissions: { adminAiCatalogItem: false } },
          { isGroupNamespace: false },
        ),
      ).toBe(false);
    });

    it('returns false when isGroupNamespace is true even if permission is granted', () => {
      expect(
        canAdminAiCatalogItem(
          { userPermissions: { adminAiCatalogItem: true } },
          { isGroupNamespace: true },
        ),
      ).toBe(false);
    });

    it('returns true when permission is granted and not in group namespace', () => {
      expect(
        canAdminAiCatalogItem(
          { userPermissions: { adminAiCatalogItem: true } },
          { isGroupNamespace: false },
        ),
      ).toBe(true);
    });

    it('defaults isGroupNamespace to false', () => {
      expect(canAdminAiCatalogItem({ userPermissions: { adminAiCatalogItem: true } })).toBe(true);
    });
  });

  describe('canReportAiCatalogItem', () => {
    it('defaults to false when called with no arguments', () => {
      expect(canReportAiCatalogItem()).toBe(false);
    });

    it('returns false when ability is missing', () => {
      expect(canReportAiCatalogItem({ glAbilities: {} })).toBe(false);
    });

    it('returns false when item null even if permission is true', () => {
      expect(
        canReportAiCatalogItem({
          glAbilities: { reportAiCatalogItem: true },
        }),
      ).toBe(false);
    });

    it('returns false when reportAiCatalogItem is false', () => {
      expect(canReportAiCatalogItem({ glAbilities: { reportAiCatalogItem: false } })).toBe(false);
    });

    it('returns false when item is GitLab-maintained even if permission is true', () => {
      expect(
        canReportAiCatalogItem({
          glAbilities: { reportAiCatalogItem: true },
          item: { verificationLevel: 'GITLAB_MAINTAINED' },
        }),
      ).toBe(false);
    });

    it('returns true when reportAiCatalogItem is true and item is not GitLab-maintained', () => {
      expect(
        canReportAiCatalogItem({
          glAbilities: { reportAiCatalogItem: true },
          item: { verificationLevel: 'UNVERIFIED' },
        }),
      ).toBe(true);
    });
  });

  describe('canDeleteAiCatalogItem', () => {
    it('defaults to false when called with no arguments', () => {
      expect(canDeleteAiCatalogItem()).toBe(false);
    });

    it('returns false when ability is missing', () => {
      expect(canDeleteAiCatalogItem({ glAbilities: {} })).toBe(false);
    });

    it('returns false when forceHardDeleteAiCatalogItem is false', () => {
      expect(canDeleteAiCatalogItem({ glAbilities: { forceHardDeleteAiCatalogItem: false } })).toBe(
        false,
      );
    });

    it('returns true when forceHardDeleteAiCatalogItem is true', () => {
      expect(canDeleteAiCatalogItem({ glAbilities: { forceHardDeleteAiCatalogItem: true } })).toBe(
        true,
      );
    });
  });

  describe('canReadMcpServer', () => {
    it('returns true when readAiCatalogMcpServer ability is true', () => {
      expect(canReadMcpServer({ glAbilities: { readAiCatalogMcpServer: true } })).toBe(true);
    });

    it('returns false when readAiCatalogMcpServer ability is false', () => {
      expect(canReadMcpServer({ glAbilities: { readAiCatalogMcpServer: false } })).toBe(false);
    });

    it('returns false when ability is missing', () => {
      expect(canReadMcpServer({ glAbilities: {} })).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(canReadMcpServer()).toBe(false);
    });
  });

  describe('canEditThirdPartyFlow', () => {
    it('returns true when createAiCatalogThirdPartyFlow ability is true', () => {
      expect(
        canEditThirdPartyFlow({
          glAbilities: { createAiCatalogThirdPartyFlow: true },
          glFeatures: {},
        }),
      ).toBe(true);
    });

    it('uses aiCatalogThirdPartyFlows flag as fallback when ability is nullish', () => {
      expect(
        canEditThirdPartyFlow({
          glAbilities: {},
          glFeatures: { aiCatalogThirdPartyFlows: true },
        }),
      ).toBe(true);
    });

    it('does not require aiCatalogCreateThirdPartyFlows flag', () => {
      expect(
        canEditThirdPartyFlow({
          glAbilities: {},
          glFeatures: { aiCatalogThirdPartyFlows: false, aiCatalogCreateThirdPartyFlows: true },
        }),
      ).toBe(false);
    });

    it('ability takes precedence over flags', () => {
      expect(
        canEditThirdPartyFlow({
          glAbilities: { createAiCatalogThirdPartyFlow: false },
          glFeatures: { aiCatalogThirdPartyFlows: true },
        }),
      ).toBe(false);
    });

    it('returns false when ability is false and flag is false', () => {
      expect(
        canEditThirdPartyFlow({
          glAbilities: { createAiCatalogThirdPartyFlow: false },
          glFeatures: { aiCatalogThirdPartyFlows: false },
        }),
      ).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(canEditThirdPartyFlow()).toBe(false);
    });
  });

  describe('canCreateThirdPartyFlow', () => {
    it('returns true when createAiCatalogThirdPartyFlow ability is true', () => {
      expect(
        canCreateThirdPartyFlow({
          glAbilities: { createAiCatalogThirdPartyFlow: true },
          glFeatures: {},
        }),
      ).toBe(true);
    });

    it('returns false when ability is false and no flags are set', () => {
      expect(
        canCreateThirdPartyFlow({
          glAbilities: { createAiCatalogThirdPartyFlow: false },
          glFeatures: {},
        }),
      ).toBe(false);
    });

    it('uses feature flags as fallback when ability is null or undefined', () => {
      expect(
        canCreateThirdPartyFlow({
          glAbilities: {},
          glFeatures: { aiCatalogThirdPartyFlows: true, aiCatalogCreateThirdPartyFlows: true },
        }),
      ).toBe(true);
    });

    it('returns false when ability is nullish and only one flag is true', () => {
      expect(
        canCreateThirdPartyFlow({
          glAbilities: {},
          glFeatures: { aiCatalogThirdPartyFlows: true, aiCatalogCreateThirdPartyFlows: false },
        }),
      ).toBe(false);
      expect(
        canCreateThirdPartyFlow({
          glAbilities: {},
          glFeatures: { aiCatalogThirdPartyFlows: false, aiCatalogCreateThirdPartyFlows: true },
        }),
      ).toBe(false);
    });

    it('ability takes precedence over flags', () => {
      expect(
        canCreateThirdPartyFlow({
          glAbilities: { createAiCatalogThirdPartyFlow: false },
          glFeatures: { aiCatalogThirdPartyFlows: true, aiCatalogCreateThirdPartyFlows: true },
        }),
      ).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(canCreateThirdPartyFlow()).toBe(false);
    });
  });

  describe('showTypeSelectionInAgentForm', () => {
    // Detailed flag/ability rules are covered by canEditThirdPartyFlow and
    // canCreateThirdPartyFlow specs. These tests only verify the dispatch
    // behavior between the two permission helpers.
    it('delegates based on isEditMode', () => {
      // Input where edit and create diverge: only aiCatalogThirdPartyFlows
      // is set (edit: true, create needs both flags: false).
      const opts = {
        glAbilities: {},
        glFeatures: { aiCatalogThirdPartyFlows: true },
      };

      expect(showTypeSelectionInAgentForm({ isEditMode: true, ...opts })).toBe(true);
      expect(showTypeSelectionInAgentForm({ isEditMode: false, ...opts })).toBe(false);
    });

    it('defaults isEditMode to false when omitted', () => {
      // Same input as above; omitting isEditMode should behave like create.
      expect(
        showTypeSelectionInAgentForm({
          glAbilities: {},
          glFeatures: { aiCatalogThirdPartyFlows: true },
        }),
      ).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(showTypeSelectionInAgentForm()).toBe(false);
    });
  });

  describe('canCreateAiCatalogItem', () => {
    describe('when isGlobalNamespace is true', () => {
      it('returns true', () => {
        expect(canCreateAiCatalogItem({ isGlobalNamespace: true })).toBe(true);
        expect(
          canCreateAiCatalogItem({
            isGlobalNamespace: true,
            glAbilities: { adminAiCatalogItem: false },
          }),
        ).toBe(true);
      });
    });

    describe('when isGlobalNamespace is false or not provided', () => {
      it('returns false when glAbilities.adminAiCatalogItem is false', () => {
        expect(canCreateAiCatalogItem({ glAbilities: { adminAiCatalogItem: false } })).toBe(false);
        expect(canCreateAiCatalogItem({})).toBe(false);
      });

      it('returns true when glAbilities.adminAiCatalogItem is true', () => {
        expect(canCreateAiCatalogItem({ glAbilities: { adminAiCatalogItem: true } })).toBe(true);
      });
    });
  });

  describe('canCreateAiCatalogAgent', () => {
    it('returns true when createAiCatalogAgent ability is true', () => {
      expect(canCreateAiCatalogAgent({ glAbilities: { createAiCatalogAgent: true } })).toBe(true);
    });

    it('returns true when createAiCatalogThirdPartyFlow ability is true', () => {
      expect(
        canCreateAiCatalogAgent({ glAbilities: { createAiCatalogThirdPartyFlow: true } }),
      ).toBe(true);
    });

    it('returns true when both abilities are true', () => {
      expect(
        canCreateAiCatalogAgent({
          glAbilities: { createAiCatalogAgent: true, createAiCatalogThirdPartyFlow: true },
        }),
      ).toBe(true);
    });

    it('returns false when both abilities are false', () => {
      expect(
        canCreateAiCatalogAgent({
          glAbilities: { createAiCatalogAgent: false, createAiCatalogThirdPartyFlow: false },
        }),
      ).toBe(false);
    });

    it('returns false when both abilities are missing', () => {
      expect(canCreateAiCatalogAgent({ glAbilities: {} })).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(canCreateAiCatalogAgent()).toBe(false);
    });
  });

  describe('canCreateAiCatalogFlow', () => {
    it('returns true when createAiCatalogFlow ability is true', () => {
      expect(canCreateAiCatalogFlow({ glAbilities: { createAiCatalogFlow: true } })).toBe(true);
    });

    it('returns false when createAiCatalogFlow ability is false', () => {
      expect(canCreateAiCatalogFlow({ glAbilities: { createAiCatalogFlow: false } })).toBe(false);
    });

    it('returns false when ability is missing', () => {
      expect(canCreateAiCatalogFlow({ glAbilities: {} })).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(canCreateAiCatalogFlow()).toBe(false);
    });
  });

  describe('canDuplicateAiCatalogItem', () => {
    it('returns false when user is not logged in', () => {
      isLoggedIn.mockReturnValue(false);

      expect(
        canDuplicateAiCatalogItem(
          {
            itemType: AI_CATALOG_TYPE_AGENT,
            userPermissions: { adminAiCatalogItem: true },
          },
          { isGlobalNamespace: true },
        ),
      ).toBe(false);
    });

    it('returns false when item is null or undefined', () => {
      expect(canDuplicateAiCatalogItem(null)).toBe(false);
      expect(canDuplicateAiCatalogItem(undefined)).toBe(false);
    });

    it.each`
      isGlobalNamespace | adminPermission | expected
      ${true}           | ${false}        | ${true}
      ${true}           | ${true}         | ${true}
      ${false}          | ${false}        | ${false}
      ${false}          | ${true}         | ${true}
    `(
      'with isGlobalNamespace = $isGlobalNamespace and adminAiCatalogItem = $adminPermission returns $expected',
      ({ isGlobalNamespace, adminPermission, expected }) => {
        expect(
          canDuplicateAiCatalogItem(
            {
              itemType: AI_CATALOG_TYPE_AGENT,
              userPermissions: { adminAiCatalogItem: adminPermission },
            },
            { isGlobalNamespace },
          ),
        ).toBe(expected);
      },
    );

    describe('when itemType is THIRD_PARTY_FLOW', () => {
      it.each`
        isGlobalNamespace | createAbility | adminPermission | expected
        ${false}          | ${false}      | ${true}         | ${false}
        ${false}          | ${true}       | ${true}         | ${true}
        ${true}           | ${true}       | ${false}        | ${true}
        ${true}           | ${false}      | ${false}        | ${false}
      `(
        'with isGlobalNamespace = $isGlobalNamespace, createAiCatalogThirdPartyFlow = $createAbility, and adminAiCatalogItem = $adminPermission returns $expected',
        ({ isGlobalNamespace, createAbility, adminPermission, expected }) => {
          expect(
            canDuplicateAiCatalogItem(
              {
                itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
                userPermissions: { adminAiCatalogItem: adminPermission },
              },
              {
                isGlobalNamespace,
                glAbilities: { createAiCatalogThirdPartyFlow: createAbility },
              },
            ),
          ).toBe(expected);
        },
      );

      it('uses glFeatures as fallback when glAbilities is not set', () => {
        expect(
          canDuplicateAiCatalogItem(
            {
              itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
              userPermissions: { adminAiCatalogItem: true },
            },
            {
              isGlobalNamespace: false,
              glFeatures: {
                aiCatalogThirdPartyFlows: true,
                aiCatalogCreateThirdPartyFlows: true,
              },
            },
          ),
        ).toBe(true);
      });
    });

    describe('when itemType is FLOW and item is foundational', () => {
      it.each`
        isGlobalNamespace | adminPermission
        ${true}           | ${true}
        ${true}           | ${false}
        ${false}          | ${true}
        ${false}          | ${false}
      `(
        'returns false with isGlobalNamespace = $isGlobalNamespace and adminAiCatalogItem = $adminPermission',
        ({ isGlobalNamespace, adminPermission }) => {
          expect(
            canDuplicateAiCatalogItem(
              {
                itemType: AI_CATALOG_TYPE_FLOW,
                foundational: true,
                userPermissions: { adminAiCatalogItem: adminPermission },
              },
              { isGlobalNamespace },
            ),
          ).toBe(false);
        },
      );
    });

    describe('when itemType is FOUNDATIONAL_AGENT', () => {
      it.each`
        isGlobalNamespace | adminPermission
        ${true}           | ${true}
        ${true}           | ${false}
        ${false}          | ${true}
        ${false}          | ${false}
      `(
        'returns false with isGlobalNamespace = $isGlobalNamespace and adminAiCatalogItem = $adminPermission',
        ({ isGlobalNamespace, adminPermission }) => {
          expect(
            canDuplicateAiCatalogItem(
              {
                itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
                userPermissions: { adminAiCatalogItem: adminPermission },
              },
              { isGlobalNamespace },
            ),
          ).toBe(false);
        },
      );
    });

    it.each`
      itemType
      ${AI_CATALOG_TYPE_AGENT}
      ${AI_CATALOG_TYPE_FLOW}
    `('when itemType is $itemType ignores glAbilities and glFeatures', ({ itemType }) => {
      expect(
        canDuplicateAiCatalogItem(
          {
            itemType,
            userPermissions: { adminAiCatalogItem: true },
          },
          {
            isGlobalNamespace: false,
            glAbilities: { createAiCatalogThirdPartyFlow: false },
            glFeatures: { aiCatalogThirdPartyFlows: false },
          },
        ),
      ).toBe(true);
    });

    it('defaults isGlobalNamespace to false when not provided', () => {
      expect(
        canDuplicateAiCatalogItem({
          itemType: AI_CATALOG_TYPE_AGENT,
          userPermissions: { adminAiCatalogItem: false },
        }),
      ).toBe(false);
    });

    it('defaults glAbilities and glFeatures to empty objects', () => {
      expect(
        canDuplicateAiCatalogItem(
          {
            itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
            userPermissions: { adminAiCatalogItem: true },
          },
          { isGlobalNamespace: false },
        ),
      ).toBe(false);
    });
  });

  describe('canEditAiCatalogItem', () => {
    it('returns false when item is null or undefined', () => {
      expect(canEditAiCatalogItem(null)).toBe(false);
      expect(canEditAiCatalogItem(undefined)).toBe(false);
    });

    it('returns false when item has no userPermissions', () => {
      expect(canEditAiCatalogItem({})).toBe(false);
      expect(canEditAiCatalogItem({ userPermissions: null })).toBe(false);
    });

    it('returns false when adminAiCatalogItem is false', () => {
      expect(
        canEditAiCatalogItem({
          userPermissions: { adminAiCatalogItem: false },
        }),
      ).toBe(false);
    });

    it('returns true when adminAiCatalogItem is true', () => {
      expect(
        canEditAiCatalogItem({
          userPermissions: { adminAiCatalogItem: true },
        }),
      ).toBe(true);
    });

    it('returns false when adminAiCatalogItem is missing', () => {
      expect(
        canEditAiCatalogItem({
          userPermissions: { otherPermission: true },
        }),
      ).toBe(false);
    });

    it('handles items with additional properties', () => {
      expect(
        canEditAiCatalogItem({
          id: '123',
          name: 'Test Agent',
          userPermissions: { adminAiCatalogItem: true },
        }),
      ).toBe(true);
    });
  });

  describe('canEnableAiCatalogItem', () => {
    describe('when isGlobalNamespace is true', () => {
      it('returns true when user is maintainer of at least one project', () => {
        expect(
          canEnableAiCatalogItem({
            projectsIsUserMaintainer: [{ id: '1' }],
            isGlobalNamespace: true,
          }),
        ).toBe(true);
      });

      it('returns false when user has no maintainer projects', () => {
        expect(
          canEnableAiCatalogItem({
            projectsIsUserMaintainer: [],
            isGlobalNamespace: true,
          }),
        ).toBe(false);
      });
    });

    describe('when isGlobalNamespace is false', () => {
      it('returns true when canAdminConsumer is true', () => {
        expect(
          canEnableAiCatalogItem({
            canAdminConsumer: true,
            isGlobalNamespace: false,
          }),
        ).toBe(true);
      });

      it('returns false when canAdminConsumer is false', () => {
        expect(
          canEnableAiCatalogItem({
            canAdminConsumer: false,
            isGlobalNamespace: false,
          }),
        ).toBe(false);
      });
    });

    it('defaults all options to false/empty', () => {
      expect(canEnableAiCatalogItem()).toBe(false);
    });

    it('returns false when isOutsideOwningProject is true, regardless of other permissions', () => {
      expect(
        canEnableAiCatalogItem({
          projectsIsUserMaintainer: [{ id: '1' }],
          canAdminConsumer: true,
          isGlobalNamespace: true,
          isOutsideOwningProject: true,
        }),
      ).toBe(false);
      expect(
        canEnableAiCatalogItem({
          canAdminConsumer: true,
          isGlobalNamespace: false,
          isOutsideOwningProject: true,
        }),
      ).toBe(false);
    });
  });

  describe('canEnableAiCatalogItemInCurrentContext', () => {
    const publicItem = { public: true };
    const privateItemFromProject1 = {
      public: false,
      project: { id: 'gid://gitlab/Project/1', nameWithNamespace: 'Group 1 / Project 1' },
    };

    it('returns false when the user is not logged in', () => {
      isLoggedIn.mockReturnValue(false);
      expect(canEnableAiCatalogItemInCurrentContext(publicItem, { readAiCatalog: true })).toBe(
        false,
      );
    });

    it('returns false in global namespace when readAiCatalog is false', () => {
      expect(
        canEnableAiCatalogItemInCurrentContext(publicItem, {
          isGlobalNamespace: true,
          readAiCatalog: false,
        }),
      ).toBe(false);
    });

    it('returns false in project namespace when the item is already enabled', () => {
      expect(
        canEnableAiCatalogItemInCurrentContext(publicItem, {
          isProjectNamespace: true,
          isEnabled: true,
          readAiCatalog: true,
        }),
      ).toBe(false);
    });

    it('returns false for a private item viewed from a different project', () => {
      expect(
        canEnableAiCatalogItemInCurrentContext(privateItemFromProject1, {
          isProjectNamespace: true,
          projectId: '99',
          readAiCatalog: true,
        }),
      ).toBe(false);
    });

    it('returns true for a private item viewed from Explore (not gated)', () => {
      expect(
        canEnableAiCatalogItemInCurrentContext(privateItemFromProject1, {
          isGlobalNamespace: true,
          readAiCatalog: true,
        }),
      ).toBe(true);
    });

    it('returns true for a private item viewed from its managing project', () => {
      expect(
        canEnableAiCatalogItemInCurrentContext(privateItemFromProject1, {
          isProjectNamespace: true,
          projectId: '1',
          readAiCatalog: true,
        }),
      ).toBe(true);
    });

    it('returns true for a public item in a namespace with read access', () => {
      expect(
        canEnableAiCatalogItemInCurrentContext(publicItem, {
          isGlobalNamespace: true,
          readAiCatalog: true,
        }),
      ).toBe(true);
    });
  });

  describe('isItemTypeEnabledInDuoSettings', () => {
    it.each`
      itemType                            | settingKey                    | expected
      ${AI_CATALOG_TYPE_AGENT}            | ${'duoCustomAgentsEnabled'}   | ${true}
      ${AI_CATALOG_TYPE_FLOW}             | ${'duoCustomFlowsEnabled'}    | ${true}
      ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${'duoExternalAgentsEnabled'} | ${true}
    `(
      'returns $expected for itemType $itemType when $settingKey is true',
      ({ itemType, settingKey, expected }) => {
        expect(
          isItemTypeEnabledInDuoSettings({
            duoSettings: { [settingKey]: true },
            itemType,
          }),
        ).toBe(expected);
      },
    );

    it.each`
      itemType                            | settingKey
      ${AI_CATALOG_TYPE_AGENT}            | ${'duoCustomAgentsEnabled'}
      ${AI_CATALOG_TYPE_FLOW}             | ${'duoCustomFlowsEnabled'}
      ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${'duoExternalAgentsEnabled'}
    `(
      'returns false for itemType $itemType when $settingKey is false',
      ({ itemType, settingKey }) => {
        expect(
          isItemTypeEnabledInDuoSettings({
            duoSettings: { [settingKey]: false },
            itemType,
          }),
        ).toBe(false);
      },
    );

    it.each`
      itemType
      ${AI_CATALOG_TYPE_AGENT}
      ${AI_CATALOG_TYPE_FLOW}
      ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW}
    `('returns false for itemType $itemType when duoSettings is empty', ({ itemType }) => {
      expect(isItemTypeEnabledInDuoSettings({ duoSettings: {}, itemType })).toBe(false);
    });

    it('returns false for an unknown itemType', () => {
      expect(
        isItemTypeEnabledInDuoSettings({
          duoSettings: {
            duoCustomAgentsEnabled: true,
            duoCustomFlowsEnabled: true,
            duoExternalAgentsEnabled: true,
          },
          itemType: 'unknown_type',
        }),
      ).toBe(false);
    });

    it('returns false when itemType is null (default)', () => {
      expect(
        isItemTypeEnabledInDuoSettings({
          duoSettings: {
            duoCustomAgentsEnabled: true,
            duoCustomFlowsEnabled: true,
            duoExternalAgentsEnabled: true,
          },
        }),
      ).toBe(false);
    });

    it('returns false when called with an empty object', () => {
      expect(isItemTypeEnabledInDuoSettings({})).toBe(false);
    });

    it('only enables the matching itemType', () => {
      const duoSettings = {
        duoCustomAgentsEnabled: true,
        duoCustomFlowsEnabled: false,
        duoExternalAgentsEnabled: false,
      };

      expect(isItemTypeEnabledInDuoSettings({ duoSettings, itemType: AI_CATALOG_TYPE_AGENT })).toBe(
        true,
      );
      expect(isItemTypeEnabledInDuoSettings({ duoSettings, itemType: AI_CATALOG_TYPE_FLOW })).toBe(
        false,
      );
      expect(
        isItemTypeEnabledInDuoSettings({ duoSettings, itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW }),
      ).toBe(false);
    });
  });

  describe('canManageAiFlowTriggers', () => {
    it('returns true when manageAiFlowTriggers ability is true', () => {
      expect(canManageAiFlowTriggers({ glAbilities: { manageAiFlowTriggers: true } })).toBe(true);
    });

    it('returns false when manageAiFlowTriggers ability is false', () => {
      expect(canManageAiFlowTriggers({ glAbilities: { manageAiFlowTriggers: false } })).toBe(false);
    });

    it('returns false when ability is missing', () => {
      expect(canManageAiFlowTriggers({ glAbilities: {} })).toBe(false);
    });

    it('defaults to false when called with no arguments', () => {
      expect(canManageAiFlowTriggers()).toBe(false);
    });
  });
});
