import {
  getByVersionKey,
  resolveVersion,
  getCancelRoute,
  getSubmitButtonText,
  isKnownPermissionError,
  isGitLabMaintainedItem,
  normalizeCustomOrFoundationalItem,
} from 'ee/ai/catalog/utils';
import {
  VERSION_LATEST,
  VERSION_PINNED,
  VERSION_PINNED_GROUP,
  VERIFICATION_LEVEL_GITLAB_MAINTAINED,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from 'ee/ai/catalog/constants';

describe('AI Catalog Utils', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  /**
    Versioning utilities
   */

  const EXP_LATEST = { id: '1', name: 'Latest' };
  const EXP_PINNED_PROJECT = { id: '2', name: 'Project pinned' };
  const EXP_PINNED_GROUP = { id: '3', name: 'Group pinned' };

  describe('getByVersionKey', () => {
    describe('handles dot notation correctly', () => {
      it.each`
        description                    | obj                                                                       | keys                                           | expected
        ${'single-level key'}          | ${{ latestVersion: EXP_LATEST }}                                          | ${'latestVersion'}                             | ${EXP_LATEST}
        ${'nested key (dot notation)'} | ${{ configurationForProject: { pinnedItemVersion: EXP_PINNED_PROJECT } }} | ${'configurationForProject.pinnedItemVersion'} | ${EXP_PINNED_PROJECT}
        ${'arbitrarily deep keys'}     | ${{ level1: { level2: { level3: { value: 'deep value' } } } }}            | ${'level1.level2.level3.value'}                | ${'deep value'}
      `('returns the value at $description', ({ obj, keys, expected }) => {
        expect(getByVersionKey(obj, keys)).toEqual(expected);
      });
    });

    describe('handles falsy key values correctly', () => {
      it.each`
        description                         | obj                                                                | keys
        ${'key does not exist'}             | ${{ latestVersion: { id: '1' } }}                                  | ${'nonexistent'}
        ${'nested key path does not exist'} | ${{ configurationForProject: { pinnedItemVersion: { id: '2' } } }} | ${'configurationForProject.nonexistent.value'}
        ${'intermediate key is null'}       | ${{ configurationForProject: null }}                               | ${'configurationForProject.pinnedItemVersion'}
        ${'key is empty string'}            | ${{ latestVersion: { id: '1' } }}                                  | ${''}
        ${'key is null'}                    | ${{ latestVersion: { id: '1' } }}                                  | ${null}
        ${'key is undefined'}               | ${{ latestVersion: { id: '1' } }}                                  | ${undefined}
      `('returns undefined when $description', ({ obj, keys }) => {
        const result = getByVersionKey(obj, keys);
        expect(result).toBeUndefined();
      });
    });

    describe('returns correct version based on configuration presence', () => {
      const obj = {
        latestVersion: EXP_LATEST,
        configurationForProject: {
          pinnedItemVersion: EXP_PINNED_PROJECT,
        },
        configurationForGroup: {
          pinnedItemVersion: EXP_PINNED_GROUP,
        },
      };

      it.each`
        versionKey              | expectedResult
        ${VERSION_PINNED}       | ${EXP_PINNED_PROJECT}
        ${VERSION_PINNED_GROUP} | ${EXP_PINNED_GROUP}
        ${VERSION_LATEST}       | ${EXP_LATEST}
      `(
        'returns the correct value for $versionKey constant key',
        ({ versionKey, expectedResult }) => {
          const result = getByVersionKey(obj, versionKey);

          expect(result).toEqual(expectedResult);
        },
      );
    });
  });

  describe('getCancelRoute', () => {
    const SHOW_ROUTE = 'show-route';
    const INDEX_ROUTE = 'index-route';

    it('returns show route with id when routeParams.id is present', () => {
      expect(getCancelRoute({ id: '42' }, SHOW_ROUTE, INDEX_ROUTE)).toEqual({
        name: SHOW_ROUTE,
        params: { id: '42' },
      });
    });

    it('returns index route when routeParams.id is absent', () => {
      expect(getCancelRoute({}, SHOW_ROUTE, INDEX_ROUTE)).toEqual({ name: INDEX_ROUTE });
    });
  });

  describe('getSubmitButtonText', () => {
    it('returns "Save changes" in edit mode', () => {
      expect(getSubmitButtonText(true, 'Create thing')).toBe('Save changes');
    });

    it('returns the createLabel in create mode', () => {
      expect(getSubmitButtonText(false, 'Create thing')).toBe('Create thing');
    });
  });

  describe('isKnownPermissionError', () => {
    it('returns false for null/undefined', () => {
      expect(isKnownPermissionError(null)).toBe(false);
      expect(isKnownPermissionError(undefined)).toBe(false);
    });

    it('returns false for a generic error', () => {
      expect(isKnownPermissionError(new Error('something went wrong'))).toBe(false);
    });

    it('returns true when the error message matches a known permission error string', () => {
      expect(
        isKnownPermissionError(new Error("You don't have permission to access this workflow.")),
      ).toBe(true);
    });

    it('returns true when the error message contains a known permission error string', () => {
      expect(
        isKnownPermissionError(
          new Error(
            "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
          ),
        ),
      ).toBe(true);
    });

    it('returns true when graphQLErrors contains a NO_RESOURCE_PERMISSIONS code', () => {
      const apolloError = Object.assign(new Error('GraphQL error'), {
        graphQLErrors: [{ extensions: { code: 'NO_RESOURCE_PERMISSIONS' } }],
      });

      expect(isKnownPermissionError(apolloError)).toBe(true);
    });

    it('returns false when graphQLErrors contains an unrelated code', () => {
      const apolloError = Object.assign(new Error('GraphQL error'), {
        graphQLErrors: [{ extensions: { code: 'SOME_OTHER_CODE' } }],
      });

      expect(isKnownPermissionError(apolloError)).toBe(false);
    });
  });

  describe('resolveVersion', () => {
    describe('handles when isGlobalNamespace is true correctly', () => {
      it('returns the latestVersion', () => {
        const mockItem = {
          latestVersion: EXP_LATEST,
          configurationForProject: { pinnedItemVersion: EXP_PINNED_PROJECT },
          configurationForGroup: { pinnedItemVersion: EXP_PINNED_GROUP },
        };
        const result = resolveVersion(mockItem, { isGlobalNamespace: true });
        expect(result).toEqual({ ...EXP_LATEST, key: VERSION_LATEST });
      });
    });

    describe('when isGroupNamespace is true (group namespace)', () => {
      const PINNED_PROJECT_CONFIG = { pinnedItemVersion: EXP_PINNED_PROJECT };
      const PINNED_GROUP_CONFIG = { pinnedItemVersion: EXP_PINNED_GROUP };
      // Note that here we assert against the actual runtime constants, since these are what are returned by the resolveVersion function
      it.each`
        description                                                             | latestVersion | pinnedProjectConfig      | pinnedGroupConfig      | expectedKey             | expectedConfig
        ${'prioritizes configurationForProject over configurationForGroup'}     | ${EXP_LATEST} | ${PINNED_PROJECT_CONFIG} | ${PINNED_GROUP_CONFIG} | ${VERSION_PINNED}       | ${EXP_PINNED_PROJECT}
        ${'returns VERSION_PINNED when configurationForGroup is undefined'}     | ${EXP_LATEST} | ${PINNED_PROJECT_CONFIG} | ${undefined}           | ${VERSION_PINNED}       | ${EXP_PINNED_PROJECT}
        ${'uses configurationForGroup when configurationForProject is missing'} | ${EXP_LATEST} | ${undefined}             | ${PINNED_GROUP_CONFIG} | ${VERSION_PINNED_GROUP} | ${EXP_PINNED_GROUP}
        ${'uses VERSION_LATEST when both configurations are missing'}           | ${EXP_LATEST} | ${undefined}             | ${undefined}           | ${VERSION_LATEST}       | ${EXP_LATEST}
      `(
        '$description',
        ({
          latestVersion,
          pinnedProjectConfig,
          pinnedGroupConfig,
          expectedKey,
          expectedConfig,
        }) => {
          const testItem = {
            latestVersion,
            configurationForProject: pinnedProjectConfig,
            configurationForGroup: pinnedGroupConfig,
          };
          const result = resolveVersion(testItem, {
            isGlobalNamespace: false,
            isGroupNamespace: true,
          });
          expect(result).toEqual({ ...expectedConfig, key: expectedKey });
        },
      );
    });

    describe('when isGroupNamespace is false (project namespace)', () => {
      const PINNED_PROJECT_CONFIG = { pinnedItemVersion: EXP_PINNED_PROJECT };
      const PINNED_GROUP_CONFIG = { pinnedItemVersion: EXP_PINNED_GROUP };

      it.each`
        description                                                            | pinnedProjectConfig      | pinnedGroupConfig      | expectedKey       | expectedConfig
        ${'returns VERSION_PINNED when the project config is present'}         | ${PINNED_PROJECT_CONFIG} | ${PINNED_GROUP_CONFIG} | ${VERSION_PINNED} | ${EXP_PINNED_PROJECT}
        ${'returns VERSION_LATEST and ignores the group anchor when disabled'} | ${undefined}             | ${PINNED_GROUP_CONFIG} | ${VERSION_LATEST} | ${EXP_LATEST}
        ${'returns VERSION_LATEST when no configs are present'}                | ${undefined}             | ${undefined}           | ${VERSION_LATEST} | ${EXP_LATEST}
      `(
        '$description',
        ({ pinnedProjectConfig, pinnedGroupConfig, expectedKey, expectedConfig }) => {
          const testItem = {
            latestVersion: EXP_LATEST,
            configurationForProject: pinnedProjectConfig,
            configurationForGroup: pinnedGroupConfig,
          };
          const result = resolveVersion(testItem, {
            isGlobalNamespace: false,
            isGroupNamespace: false,
          });
          expect(result).toEqual({ ...expectedConfig, key: expectedKey });
        },
      );
    });
  });

  describe('isGitLabMaintainedItem', () => {
    it('returns true when verificationLevel is GitLab-maintained', () => {
      expect(
        isGitLabMaintainedItem({
          verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
        }),
      ).toBe(true);
    });

    it('returns false when verificationLevel is unverified', () => {
      expect(isGitLabMaintainedItem({ verificationLevel: 'UNVERIFIED' })).toBe(false);
    });

    it('returns false when item is null or undefined', () => {
      expect(isGitLabMaintainedItem(null)).toBe(false);
      expect(isGitLabMaintainedItem(undefined)).toBe(false);
    });
  });

  describe('normalizeCustomOrFoundationalItem', () => {
    it('returns the node unchanged when it is not a foundational chat agent', () => {
      const node = { __typename: 'AiCatalogItem', id: 'gid://gitlab/Ai::Catalog::Item/1' };

      expect(normalizeCustomOrFoundationalItem(node)).toBe(node);
    });

    it('normalizes a foundational chat agent node into a list item shape', () => {
      const node = {
        __typename: 'AiFoundationalChatAgent',
        id: 'gid://gitlab/Ai::FoundationalChatAgent/security_analyst_agent-v1',
        reference: 'security_analyst_agent',
        name: 'Security Analyst',
        description: 'Automate security workflows',
      };

      expect(normalizeCustomOrFoundationalItem(node)).toMatchObject({
        ...node,
        itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
        foundational: true,
        public: true,
        verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
        starCount: 0,
        starred: false,
        last30DayUsageCount: 0,
      });
    });
  });
});
