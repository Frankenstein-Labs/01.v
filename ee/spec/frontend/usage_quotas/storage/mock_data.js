import { storageTypeHelpPaths } from '~/usage_quotas/storage/constants';

export const defaultNamespaceProvideValues = {
  namespaceId: 0,
  namespacePath: 'GitLab',
  userNamespace: false,
  defaultPerPage: 20,
  purchaseStorageUrl: 'some-fancy-url',
  buyAddonTargetAttr: '_blank',
  namespacePlanName: 'Free',
  isInNamespaceLimitsPreEnforcement: false,
  perProjectStorageLimit: 10737418240,
  namespaceStorageLimit: 5368709120,
  totalRepositorySizeExcess: '0',
  isUsingProjectEnforcementWithLimits: false,
  isUsingProjectEnforcementWithNoLimits: false,
  aboveSizeLimit: false,
  subjectToHighLimit: false,
  isUsingNamespaceEnforcement: true,
  customSortKey: null,
  helpLinks: storageTypeHelpPaths,
};
