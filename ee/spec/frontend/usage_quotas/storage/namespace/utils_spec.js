import { parseNamespaceProvideData } from 'ee/usage_quotas/storage/namespace/utils';

describe('parseNamespaceProvideData', () => {
  /** @type {HTMLElement} */
  let el;

  beforeEach(() => {
    el = document.createElement('div');
    el.dataset.namespaceId = '123';
    el.dataset.namespacePath = 'group/path';
    el.dataset.userNamespace = 'false';
    el.dataset.defaultPerPage = '20';
    el.dataset.namespacePlanName = 'premium';
    el.dataset.perProjectStorageLimit = '1000';
    el.dataset.purchaseStorageUrl = '/purchase';
    el.dataset.buyAddonTargetAttr = '_blank';
    el.dataset.enforcementType = 'project_repository_limit';
    el.dataset.aboveSizeLimit = 'true';
    el.dataset.subjectToHighLimit = 'false';
    el.dataset.isInNamespaceLimitsPreEnforcement = 'false';
    el.dataset.totalRepositorySizeExcess = '100';
  });

  it('parses data from DOM element', () => {
    const result = parseNamespaceProvideData(el);

    expect(result).toStrictEqual({
      namespaceId: 123,
      namespacePath: 'group/path',
      userNamespace: false,
      defaultPerPage: 20,
      namespacePlanName: 'premium',
      namespaceStorageLimit: 0,
      perProjectStorageLimit: 1000,
      purchaseStorageUrl: '/purchase',
      buyAddonTargetAttr: '_blank',
      isInNamespaceLimitsPreEnforcement: false,
      totalRepositorySizeExcess: 100,
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: true,
      isUsingProjectEnforcementWithNoLimits: false,
      aboveSizeLimit: true,
      subjectToHighLimit: false,
      customSortKey: 'EXCESS_REPO_STORAGE_SIZE_DESC',
      helpLinks: expect.any(Object),
    });
  });

  describe('Namespace limit type', () => {
    beforeEach(() => {
      el.dataset.enforcementType = 'namespace_storage_limit';
      el.dataset.namespaceStorageLimit = '5000';
    });

    it('sets sort data correctly', () => {
      const result = parseNamespaceProvideData(el);

      expect(result).toEqual(
        expect.objectContaining({
          customSortKey: null,
          namespaceStorageLimit: 5000,
          isUsingNamespaceEnforcement: true,
          isUsingProjectEnforcementWithLimits: false,
          isUsingProjectEnforcementWithNoLimits: false,
        }),
      );
    });
  });

  it('returns empty object when no element provided', () => {
    expect(parseNamespaceProvideData(null)).toEqual({});
  });
});
