/**
 * Calculate the total number of vulnerabilities across different severities
 * @param {Object} vulnerabilitySeveritiesCount - An object containing the count of vulnerabilities for each severity level
 * @returns {number} The total number of vulnerabilities
 */
export const getVulnerabilityTotal = (vulnerabilitySeveritiesCount = {}) => {
  const {
    critical = 0,
    high = 0,
    medium = 0,
    low = 0,
    info = 0,
    unknown = 0,
  } = vulnerabilitySeveritiesCount || {};

  return critical + high + medium + low + info + unknown;
};

export const isSubGroup = (item) => {
  // eslint-disable-next-line no-underscore-dangle
  return item.__typename === 'Group';
};

/**
 * Validates the structure and types of a security scanner group object
 * @param {Object} value - Object of group security scanner
 * @returns {Boolean} True if all items have valid structure, false otherwise
 */
export const securityScannerOfGroupValidator = (value) => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return false;
  }
  const typeChecks = {
    analyzerType: (val) => typeof val === 'string',
    failure: (val) => typeof val === 'number',
    notConfigured: (val) => typeof val === 'number',
    success: (val) => typeof val === 'number',
  };
  const optionalTypeChecks = {
    updatedAt: (val) => val === undefined || typeof val === 'string',
  };
  for (const [key, typeCheck] of Object.entries(typeChecks)) {
    if (!(key in value) || !typeCheck(value[key])) {
      return false;
    }
  }
  for (const [key, typeCheck] of Object.entries(optionalTypeChecks)) {
    if (key in value && !typeCheck(value[key])) {
      return false;
    }
  }
  return true;
};

/**
 * Validates the structure and types of a security scanner project object
 * @param {Array<Object>} value - Array of security scanner objects
 * @returns {Boolean} True if all items have valid structure, false otherwise
 */
export const securityScannerOfProjectValidator = (value) => {
  return value.every(
    (item) =>
      typeof item === 'object' &&
      'analyzerType' in item &&
      typeof item.analyzerType === 'string' &&
      (!('status' in item) || typeof item.status === 'string') &&
      (!('buildId' in item) || item.buildId === null || typeof item.buildId === 'string') &&
      (!('lastCall' in item) || typeof item.lastCall === 'string') &&
      (!('updatedAt' in item) || typeof item.updatedAt === 'string'),
  );
};

/**
 * Validator function for item prop
 * @param {Object} value - Object item of project tool coverage
 * @returns {Boolean} True if all items have valid structure, false otherwise
 */
export const itemValidator = (value) => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return false;
  }
  if ('analyzerStatuses' in value) {
    if (
      !Array.isArray(value.analyzerStatuses) ||
      !securityScannerOfProjectValidator(value.analyzerStatuses)
    ) {
      return false;
    }
  }
  if ('path' in value && typeof value.path !== 'string') {
    return false;
  }
  return !('webUrl' in value && typeof value.webUrl !== 'string');
};

/**
 * Checks if recursive breadcrumbs should break and display GlBreadcrumb instead
 * @param {String} currentPath - the fullPath of the group for which breadcrumbs are being rendered
 * @param {String} groupFullPath - the fullPath of the group for which the security inventory is being rendered
 * @param {Object} group - group object as returned by the GroupAvatarAndParentQuery
 * @returns {Boolean} True if we've reached groupFullPath or a group with no parent (or something has gone wrong)
 */
export const hasReachedMainGroup = (currentPath, groupFullPath, group) => {
  // something has gone wrong
  if (!currentPath || !groupFullPath || !group || !currentPath.includes(groupFullPath)) return true;

  // reached groupFullPath or group with no parent
  return currentPath === groupFullPath || !group.parent?.fullPath;
};
