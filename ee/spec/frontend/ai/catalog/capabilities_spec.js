import {
  getAiCatalogItemOwningProjectId,
  getAiCatalogItemOwningProjectName,
  isAiCatalogItemEnabledInGroup,
  isAiCatalogItemEnabledInProject,
  isAiCatalogItemEnabledInManagedByProject,
  isAiCatalogItemEnabled,
  isAiCatalogItemOutsideOwningProject,
  showEnableFromGlobalAction,
  getAiCatalogItemVisibilityLevel,
  isAiCatalogItemRestricted,
} from 'ee/ai/catalog/capabilities';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';

describe('AI Catalog Capabilities', () => {
  describe('isAiCatalogItemEnabledInGroup', () => {
    it('returns true when configurationForGroup.enabled is true', () => {
      expect(isAiCatalogItemEnabledInGroup({ configurationForGroup: { enabled: true } })).toBe(
        true,
      );
    });

    it('returns false when configurationForGroup.enabled is false', () => {
      expect(isAiCatalogItemEnabledInGroup({ configurationForGroup: { enabled: false } })).toBe(
        false,
      );
    });

    it('returns false when configurationForGroup is missing', () => {
      expect(isAiCatalogItemEnabledInGroup({})).toBe(false);
    });

    it('returns false when item is null or undefined', () => {
      expect(isAiCatalogItemEnabledInGroup(null)).toBe(false);
      expect(isAiCatalogItemEnabledInGroup(undefined)).toBe(false);
    });
  });

  describe('isAiCatalogItemEnabledInProject', () => {
    it('returns true when configurationForProject.enabled is true', () => {
      expect(isAiCatalogItemEnabledInProject({ configurationForProject: { enabled: true } })).toBe(
        true,
      );
    });

    it('returns false when configurationForProject.enabled is false', () => {
      expect(isAiCatalogItemEnabledInProject({ configurationForProject: { enabled: false } })).toBe(
        false,
      );
    });

    it('returns false when configurationForProject is missing', () => {
      expect(isAiCatalogItemEnabledInProject({})).toBe(false);
    });

    it('returns false when item is null or undefined', () => {
      expect(isAiCatalogItemEnabledInProject(null)).toBe(false);
      expect(isAiCatalogItemEnabledInProject(undefined)).toBe(false);
    });
  });

  describe('isAiCatalogItemEnabledInManagedByProject', () => {
    it('returns true when isEnabledInManagedByProject is true', () => {
      expect(isAiCatalogItemEnabledInManagedByProject({ isEnabledInManagedByProject: true })).toBe(
        true,
      );
    });

    it('returns false when isEnabledInManagedByProject is false', () => {
      expect(isAiCatalogItemEnabledInManagedByProject({ isEnabledInManagedByProject: false })).toBe(
        false,
      );
    });

    it('returns false when isEnabledInManagedByProject is missing', () => {
      expect(isAiCatalogItemEnabledInManagedByProject({})).toBe(false);
    });

    it('returns false when item is null or undefined', () => {
      expect(isAiCatalogItemEnabledInManagedByProject(null)).toBe(false);
      expect(isAiCatalogItemEnabledInManagedByProject(undefined)).toBe(false);
    });
  });

  describe('isAiCatalogItemEnabled', () => {
    const publicItem = {
      public: true,
      configurationForProject: { enabled: true },
      configurationForGroup: { enabled: false },
    };

    describe('for a public item', () => {
      it('reads configurationForProject when isProjectNamespace is true', () => {
        expect(isAiCatalogItemEnabled(publicItem, { isProjectNamespace: true })).toBe(true);
      });

      it('reads configurationForGroup when isProjectNamespace is false', () => {
        expect(isAiCatalogItemEnabled(publicItem, { isProjectNamespace: false })).toBe(false);
      });

      it('defaults to group namespace when isProjectNamespace is not provided', () => {
        expect(isAiCatalogItemEnabled(publicItem)).toBe(false);
      });
    });

    describe('for a private item', () => {
      it.each`
        isEnabledInManagedByProject | isProjectNamespace | expected
        ${true}                     | ${false}           | ${true}
        ${true}                     | ${true}            | ${true}
        ${false}                    | ${false}           | ${false}
        ${false}                    | ${true}            | ${false}
        ${undefined}                | ${false}           | ${false}
      `(
        'returns $expected when isEnabledInManagedByProject=$isEnabledInManagedByProject and isProjectNamespace=$isProjectNamespace',
        ({ isEnabledInManagedByProject, isProjectNamespace, expected }) => {
          const item = {
            public: false,
            isEnabledInManagedByProject,
            // legacy fields should be ignored for private items
            configurationForProject: { enabled: false },
            configurationForGroup: { enabled: false },
          };

          expect(isAiCatalogItemEnabled(item, { isProjectNamespace })).toBe(expected);
        },
      );

      it('ignores configurationForProject for private items', () => {
        // Private items are always evaluated against the owning project via
        // isEnabledInManagedByProject, regardless of namespace context.
        const item = {
          public: false,
          isEnabledInManagedByProject: false,
          configurationForProject: { enabled: true },
        };

        expect(isAiCatalogItemEnabled(item, { isProjectNamespace: true })).toBe(false);
      });
    });

    describe('for a restricted item (flag on)', () => {
      const restrictedItem = {
        public: false,
        visibility: VISIBILITY_LEVEL_RESTRICTED,
        isEnabledInManagedByProject: true,
        configurationForProject: { enabled: false },
        configurationForGroup: { enabled: true },
      };
      const glFeatures = { aiCatalogInternalVisibility: true };

      it('reads configurationForProject (not isEnabledInManagedByProject) when in project namespace', () => {
        expect(
          isAiCatalogItemEnabled(restrictedItem, { isProjectNamespace: true, glFeatures }),
        ).toBe(false);
      });

      it('reads configurationForGroup when not in project namespace', () => {
        expect(
          isAiCatalogItemEnabled(restrictedItem, { isProjectNamespace: false, glFeatures }),
        ).toBe(true);
      });
    });

    describe('for a restricted item (flag off)', () => {
      const restrictedItem = {
        public: false,
        visibility: VISIBILITY_LEVEL_RESTRICTED,
        isEnabledInManagedByProject: true,
        configurationForProject: { enabled: false },
      };

      it('falls back to isEnabledInManagedByProject when flag is off', () => {
        expect(isAiCatalogItemEnabled(restrictedItem, { isProjectNamespace: true })).toBe(true);
      });
    });

    it('returns false when item is null or undefined', () => {
      expect(isAiCatalogItemEnabled(null)).toBe(false);
      expect(isAiCatalogItemEnabled(undefined)).toBe(false);
    });

    it('returns false when configuration is missing on a public item', () => {
      expect(isAiCatalogItemEnabled({ public: true }, { isProjectNamespace: true })).toBe(false);
      expect(isAiCatalogItemEnabled({ public: true }, { isProjectNamespace: false })).toBe(false);
    });
  });

  describe('showEnableFromGlobalAction', () => {
    it('returns true when isGlobalNamespace and item is not foundational', () => {
      expect(
        showEnableFromGlobalAction(
          { foundational: false, itemType: AI_CATALOG_TYPE_AGENT },
          { isGlobalNamespace: true },
        ),
      ).toBe(true);
    });

    it('returns false when not in global namespace', () => {
      expect(
        showEnableFromGlobalAction(
          { foundational: false, itemType: AI_CATALOG_TYPE_AGENT },
          { isGlobalNamespace: false },
        ),
      ).toBe(false);
    });

    it('returns false when item is foundational and not a third-party flow', () => {
      expect(
        showEnableFromGlobalAction(
          { foundational: true, itemType: AI_CATALOG_TYPE_FLOW },
          { isGlobalNamespace: true },
        ),
      ).toBe(false);
    });

    it('returns true when item is foundational but is a third-party flow', () => {
      expect(
        showEnableFromGlobalAction(
          { foundational: true, itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW },
          { isGlobalNamespace: true },
        ),
      ).toBe(true);
    });
  });

  describe('getAiCatalogItemOwningProjectId', () => {
    it('extracts the numeric project id from a GraphQL global id', () => {
      expect(getAiCatalogItemOwningProjectId({ project: { id: 'gid://gitlab/Project/42' } })).toBe(
        42,
      );
    });

    it('returns null when the item has no project', () => {
      expect(getAiCatalogItemOwningProjectId({})).toBeNull();
      expect(getAiCatalogItemOwningProjectId(null)).toBeNull();
    });

    it('returns null when the project has no id', () => {
      expect(getAiCatalogItemOwningProjectId({ project: { id: null } })).toBeNull();
    });
  });

  describe('getAiCatalogItemOwningProjectName', () => {
    it('returns the project nameWithNamespace', () => {
      expect(
        getAiCatalogItemOwningProjectName({
          project: { nameWithNamespace: 'Group 1 / Project 1' },
        }),
      ).toBe('Group 1 / Project 1');
    });

    it('returns null when the field is missing', () => {
      expect(getAiCatalogItemOwningProjectName({})).toBeNull();
      expect(getAiCatalogItemOwningProjectName(null)).toBeNull();
    });
  });

  describe('isAiCatalogItemOutsideOwningProject', () => {
    const privateItem = {
      public: false,
      project: { id: 'gid://gitlab/Project/42', nameWithNamespace: 'Group 1 / Project 1' },
    };

    it('returns false for public items regardless of namespace', () => {
      expect(
        isAiCatalogItemOutsideOwningProject(
          { ...privateItem, public: true },
          { isProjectNamespace: true, projectId: '99' },
        ),
      ).toBe(false);
    });

    it('returns false when the item has no owning project id (fail open)', () => {
      expect(
        isAiCatalogItemOutsideOwningProject(
          { public: false, project: { id: null } },
          { isProjectNamespace: true, projectId: '99' },
        ),
      ).toBe(false);
    });

    it('returns false for a private item viewed from Explore (not a project namespace)', () => {
      expect(
        isAiCatalogItemOutsideOwningProject(privateItem, {
          isProjectNamespace: false,
          projectId: null,
        }),
      ).toBe(false);
    });

    it('returns false for a private item viewed from a group namespace', () => {
      expect(
        isAiCatalogItemOutsideOwningProject(privateItem, {
          isProjectNamespace: false,
          projectId: null,
        }),
      ).toBe(false);
    });

    it('returns true for a private item viewed from a different project', () => {
      expect(
        isAiCatalogItemOutsideOwningProject(privateItem, {
          isProjectNamespace: true,
          projectId: '99',
        }),
      ).toBe(true);
    });

    it('returns false for a private item viewed from its owning project', () => {
      expect(
        isAiCatalogItemOutsideOwningProject(privateItem, {
          isProjectNamespace: true,
          projectId: '42',
        }),
      ).toBe(false);
    });

    describe('for a restricted item (flag on)', () => {
      const restrictedItem = {
        public: false,
        visibility: VISIBILITY_LEVEL_RESTRICTED,
        project: { id: 'gid://gitlab/Project/42', nameWithNamespace: 'Group 1 / Project 1' },
      };
      const glFeatures = { aiCatalogInternalVisibility: true };

      it('returns false even when viewed from a different project', () => {
        expect(
          isAiCatalogItemOutsideOwningProject(restrictedItem, {
            isProjectNamespace: true,
            projectId: '99',
            glFeatures,
          }),
        ).toBe(false);
      });

      it('returns false when viewed from the owning project', () => {
        expect(
          isAiCatalogItemOutsideOwningProject(restrictedItem, {
            isProjectNamespace: true,
            projectId: '42',
            glFeatures,
          }),
        ).toBe(false);
      });
    });

    describe('for a restricted item (flag off)', () => {
      const restrictedItem = {
        public: false,
        visibility: VISIBILITY_LEVEL_RESTRICTED,
        project: { id: 'gid://gitlab/Project/42', nameWithNamespace: 'Group 1 / Project 1' },
      };

      it('falls back to private behaviour and returns true for a different project', () => {
        expect(
          isAiCatalogItemOutsideOwningProject(restrictedItem, {
            isProjectNamespace: true,
            projectId: '99',
          }),
        ).toBe(true);
      });
    });
  });

  describe('getAiCatalogItemVisibilityLevel', () => {
    describe('when aiCatalogInternalVisibility is enabled', () => {
      const glFeatures = { aiCatalogInternalVisibility: true };

      it.each`
        visibility                     | expected
        ${VISIBILITY_LEVEL_PUBLIC}     | ${VISIBILITY_LEVEL_PUBLIC}
        ${VISIBILITY_LEVEL_RESTRICTED} | ${VISIBILITY_LEVEL_RESTRICTED}
        ${VISIBILITY_LEVEL_PRIVATE}    | ${VISIBILITY_LEVEL_PRIVATE}
      `('returns $expected when item.visibility is $visibility', ({ visibility, expected }) => {
        expect(getAiCatalogItemVisibilityLevel({ public: false, visibility }, glFeatures)).toBe(
          expected,
        );
      });

      it('falls back to deriving from item.public when visibility is absent', () => {
        expect(getAiCatalogItemVisibilityLevel({ public: true }, glFeatures)).toBe(
          VISIBILITY_LEVEL_PUBLIC,
        );
        expect(getAiCatalogItemVisibilityLevel({ public: false }, glFeatures)).toBe(
          VISIBILITY_LEVEL_PRIVATE,
        );
      });
    });

    describe('when aiCatalogInternalVisibility is disabled', () => {
      it.each`
        isPublic | expected
        ${true}  | ${VISIBILITY_LEVEL_PUBLIC}
        ${false} | ${VISIBILITY_LEVEL_PRIVATE}
      `('derives $expected from item.public=$isPublic', ({ isPublic, expected }) => {
        expect(
          getAiCatalogItemVisibilityLevel(
            { public: isPublic, visibility: VISIBILITY_LEVEL_RESTRICTED },
            {},
          ),
        ).toBe(expected);
      });
    });
  });

  describe('isAiCatalogItemRestricted', () => {
    it('returns true when flag is on and visibility is RESTRICTED', () => {
      expect(
        isAiCatalogItemRestricted(
          { visibility: VISIBILITY_LEVEL_RESTRICTED },
          { aiCatalogInternalVisibility: true },
        ),
      ).toBe(true);
    });

    it('returns false when flag is on but visibility is not RESTRICTED', () => {
      expect(
        isAiCatalogItemRestricted(
          { visibility: VISIBILITY_LEVEL_PUBLIC },
          { aiCatalogInternalVisibility: true },
        ),
      ).toBe(false);
    });

    it('returns false when flag is off even if visibility is RESTRICTED', () => {
      expect(isAiCatalogItemRestricted({ visibility: VISIBILITY_LEVEL_RESTRICTED }, {})).toBe(
        false,
      );
    });
  });
});
