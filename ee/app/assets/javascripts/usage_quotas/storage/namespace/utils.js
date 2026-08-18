import { parseBoolean } from '~/lib/utils/common_utils';
import { storageTypeHelpPaths as helpLinks } from '~/usage_quotas/storage/constants';

// https://docs.gitlab.com/ee/user/storage_usage_quotas
// declared in ee/app/models/namespaces/storage/repository_limit/enforcement.rb
const PROJECT_ENFORCEMENT_TYPE = 'project_repository_limit';

// https://internal.gitlab.com/handbook/engineering/fulfillment/namespace-storage-enforcement/
// declared in ee/app/models/namespaces/storage/root_size.rb
const NAMESPACE_ENFORCEMENT_TYPE = 'namespace_storage_limit';

/**
 * Parses group and profile data injected via a DOM element.
 * @param {HTMLElement} el - DOM element
 * @return parsed data
 */
export const parseNamespaceProvideData = (el) => {
  if (!el) {
    return {};
  }

  const {
    namespaceId,
    namespacePath,
    userNamespace,
    defaultPerPage,
    namespacePlanName,
    purchaseStorageUrl,
    buyAddonTargetAttr,
    enforcementType,
    aboveSizeLimit,
    subjectToHighLimit,
    isInNamespaceLimitsPreEnforcement,
    totalRepositorySizeExcess,
  } = el.dataset;

  const perProjectStorageLimit = el.dataset.perProjectStorageLimit
    ? Number(el.dataset.perProjectStorageLimit)
    : 0;
  const namespaceStorageLimit = el.dataset.namespaceStorageLimit
    ? Number(el.dataset.namespaceStorageLimit)
    : 0;
  const isUsingNamespaceEnforcement = enforcementType === NAMESPACE_ENFORCEMENT_TYPE;
  const isUsingProjectEnforcement = enforcementType === PROJECT_ENFORCEMENT_TYPE;
  const isUsingProjectEnforcementWithLimits =
    isUsingProjectEnforcement && perProjectStorageLimit !== 0;
  const isUsingProjectEnforcementWithNoLimits =
    isUsingProjectEnforcement && perProjectStorageLimit === 0;

  return {
    namespaceId: parseInt(namespaceId, 10),
    namespacePath,
    userNamespace: parseBoolean(userNamespace),
    defaultPerPage: Number(defaultPerPage),
    namespacePlanName,
    perProjectStorageLimit,
    namespaceStorageLimit,
    purchaseStorageUrl,
    buyAddonTargetAttr,
    isInNamespaceLimitsPreEnforcement: parseBoolean(isInNamespaceLimitsPreEnforcement),
    totalRepositorySizeExcess: totalRepositorySizeExcess && Number(totalRepositorySizeExcess),
    isUsingNamespaceEnforcement,
    isUsingProjectEnforcementWithLimits,
    isUsingProjectEnforcementWithNoLimits,
    aboveSizeLimit: parseBoolean(aboveSizeLimit),
    subjectToHighLimit: parseBoolean(subjectToHighLimit),
    customSortKey: isUsingProjectEnforcementWithLimits ? 'EXCESS_REPO_STORAGE_SIZE_DESC' : null,
    helpLinks,
  };
};

export const parseAdminProvideData = (el) => {
  if (!el) {
    return {};
  }

  const { namespacePlanName } = el.dataset;

  return {
    namespacePlanName,
  };
};
