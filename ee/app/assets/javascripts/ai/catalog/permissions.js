import { isLoggedIn } from '~/lib/utils/common_utils';
import { isAiCatalogItemOutsideOwningProject, isAiCatalogItemRestricted } from './capabilities';
import { isGitLabMaintainedItem } from './utils';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from './constants';

/**
 * Checks if user can edit an existing third-party flow.
 * Edit requires only the third-party-flows ability/flag, not the additional
 * create flag.
 *
 * @param {Object} options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @param {Object} options.glFeatures - GitLab features object
 * @returns {Boolean}
 */
export const canEditThirdPartyFlow = (options = {}) => {
  const { glAbilities = {}, glFeatures = {} } = options;
  return Boolean(glAbilities.createAiCatalogThirdPartyFlow ?? glFeatures.aiCatalogThirdPartyFlows);
};

/**
 * Checks if user can create a new third-party flow.
 * Create requires both third-party-flows feature flags when falling back
 * from glAbilities.
 *
 * @param {Object} options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @param {Object} options.glFeatures - GitLab features object
 * @returns {Boolean}
 */
export const canCreateThirdPartyFlow = (options = {}) => {
  const { glAbilities = {}, glFeatures = {} } = options;
  return Boolean(
    glAbilities.createAiCatalogThirdPartyFlow ??
    (glFeatures.aiCatalogThirdPartyFlows && glFeatures.aiCatalogCreateThirdPartyFlows),
  );
};

/**
 * Checks if the agent type selection should be shown in the agent form.
 * Delegates to canEditThirdPartyFlow / canCreateThirdPartyFlow based on mode.
 *
 * @param {Object} options
 * @param {Boolean} options.isEditMode - Whether the form is in edit mode
 * @param {Object} options.glAbilities - GitLab abilities object
 * @param {Object} options.glFeatures - GitLab features object
 * @returns {Boolean}
 */
export const showTypeSelectionInAgentForm = (options = {}) => {
  const { isEditMode = false, glAbilities = {}, glFeatures = {} } = options;

  return isEditMode
    ? canEditThirdPartyFlow({ glAbilities, glFeatures })
    : canCreateThirdPartyFlow({ glAbilities, glFeatures });
};

/**
 * Checks if user has admin permission on an item
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const canAdminItem = (item) => {
  return Boolean(item?.userPermissions?.adminAiCatalogItem);
};

/**
 * Checks if user can report an item.
 *
 * @param {Object} options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @param {Object} options.item - The AI Catalog item
 * @returns {Boolean}
 */
export const canReportAiCatalogItem = (options = {}) => {
  const { glAbilities = {}, item = null } = options;
  if (item === null) return false;
  return Boolean(glAbilities.reportAiCatalogItem && !isGitLabMaintainedItem(item));
};

/**
 * Checks if user can hard-delete an item.
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const canDeleteAiCatalogItem = (options = {}) => {
  const { glAbilities = {} } = options;
  return Boolean(glAbilities.forceHardDeleteAiCatalogItem);
};

/**
 * Checks if user can read MCP servers in agent configuration.
 *
 * @param {Object} options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @returns {Boolean}
 */
export const canReadMcpServer = (options = {}) => {
  const { glAbilities = {} } = options;
  return Boolean(glAbilities.readAiCatalogMcpServer);
};

/**
 * Checks if user can create a new item.
 * Does not include isLoggedIn check as that's handled on the router level.
 *
 * @param {Object} options - Additional options
 * @param {Boolean} options.isGlobalNamespace - Whether viewing from explore page
 * @param {Object} options.glAbilities - GitLab abilities object
 * @returns {Boolean}
 */
export const canCreateAiCatalogItem = (options = {}) => {
  const { isGlobalNamespace = false, glAbilities = {} } = options;

  if (isGlobalNamespace) {
    return true;
  }

  return Boolean(glAbilities.adminAiCatalogItem);
};

/**
 * Checks if user can create a new agent or external agent based on project duo settings.
 * Does not include isLoggedIn check as that's handled on the router level.
 *
 * @param {Object} options - Additional options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @returns {Boolean}
 */
export const canCreateAiCatalogAgent = (options = {}) => {
  const { glAbilities = {} } = options;

  return (
    Boolean(glAbilities.createAiCatalogAgent) || Boolean(glAbilities.createAiCatalogThirdPartyFlow)
  );
};

/**
 * Checks if user can create a new flow based on project duo settings.
 * Does not include isLoggedIn check as that's handled on the router level.
 *
 * @param {Object} options - Additional options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @returns {Boolean}
 */
export const canCreateAiCatalogFlow = (options = {}) => {
  const { glAbilities = {} } = options;

  return Boolean(glAbilities.createAiCatalogFlow);
};

/**
 * Checks if user can duplicate an existing item.
 * Duplicate has same permissions as edit, with additional checks for third-party flows
 * and foundational flows.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} options - Additional options
 * @param {Boolean} options.isGlobalNamespace - Whether viewing from explore page
 * @param {Boolean} options.isGroupNamespace - Whether viewing from group page
 * @param {Object} options.glAbilities - GitLab abilities object
 * @param {Object} options.glFeatures - GitLab features object
 * @returns {Boolean}
 */
export const canDuplicateAiCatalogItem = (item, options = {}) => {
  const {
    isGlobalNamespace = false,
    isGroupNamespace = false,
    glAbilities = {},
    glFeatures = {},
  } = options;

  if (!item || !isLoggedIn()) {
    return false;
  }

  if (isGroupNamespace) {
    return false;
  }

  if (item.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW) {
    if (!canCreateThirdPartyFlow({ glAbilities, glFeatures })) {
      return false;
    }
  }

  if (item.itemType === AI_CATALOG_TYPE_FLOW && item.foundational) {
    return false;
  }

  if (item.itemType === AI_CATALOG_TYPE_FOUNDATIONAL_AGENT) {
    return false;
  }

  if (isGlobalNamespace) {
    return true;
  }

  return canAdminItem(item);
};

/**
 * Checks if user can edit an existing item.
 * Does not include isLoggedIn check as that's handled on the router level.
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const canEditAiCatalogItem = (item) => {
  return canAdminItem(item);
};

/**
 * Checks if user can admin an AI Catalog item in a non-group namespace.
 * Extends canAdminItem with the namespace constraint.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} options
 * @param {Boolean} options.isGroupNamespace - Whether viewing from a group page
 * @returns {Boolean}
 */
export const canAdminAiCatalogItem = (item, options = {}) => {
  const { isGroupNamespace = false } = options;
  return canAdminItem(item) && !isGroupNamespace;
};

/**
 * Checks if user can enable an AI Catalog item.
 *
 * @param {Object} options
 * @param {Array}   options.projectsIsUserMaintainer - Projects where the user is a maintainer
 * @param {Boolean} options.canAdminConsumer - Whether user can admin the item consumer
 * @param {Boolean} options.isGlobalNamespace - Whether viewing from the explore page
 * @param {Boolean} options.isOutsideOwningProject - Whether a private item is being
 *   viewed from outside its managing project
 * @returns {Boolean}
 */
export const canEnableAiCatalogItem = (options = {}) => {
  const {
    projectsIsUserMaintainer = [],
    canAdminConsumer = false,
    isGlobalNamespace = false,
    isOutsideOwningProject = false,
  } = options;

  if (isOutsideOwningProject) {
    return false;
  }

  if (isGlobalNamespace) {
    return projectsIsUserMaintainer.length > 0;
  }

  return canAdminConsumer;
};

/**
 * Checks whether the user can enable an AI Catalog item from the current
 * page context. Combines login, read-catalog ability, already-enabled state,
 * and managing-project scope into a single predicate suitable for gating
 * the Enable button.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} options
 * @param {Boolean} options.isGlobalNamespace - Whether viewing from the explore page
 * @param {Boolean} options.isProjectNamespace - Whether viewing from a project page
 * @param {Boolean} options.isEnabled - Whether the item is already enabled in the current namespace
 * @param {Boolean} options.readAiCatalog - Whether the user has the read_ai_catalog ability
 * @param {String|Number} options.projectId - The current project id (numeric string)
 * @param {Object} options.glFeatures - Feature flags object (from glFeatureFlagsMixin)
 * @returns {Boolean}
 */
export const canEnableAiCatalogItemInCurrentContext = (item, options = {}) => {
  const {
    isGlobalNamespace = false,
    isProjectNamespace = false,
    isEnabled = false,
    readAiCatalog = false,
    projectId = null,
    glFeatures = {},
  } = options;

  if (!isLoggedIn()) return false;
  if (!readAiCatalog && isGlobalNamespace) return false;
  if (isProjectNamespace && isEnabled) return false;
  // For private items, `isEnabled` reflects the owning project's state via
  // `isEnabledInManagedByProject`, so we can gate the button in any namespace
  // (including Explore) once we know the only valid target is already enabled.
  // Restricted items are excluded: their `isEnabled` reflects the current namespace
  // and they can be enabled in multiple projects within the same top-level group.
  if (item && item.public === false && !isAiCatalogItemRestricted(item, glFeatures) && isEnabled) {
    return false;
  }

  return !isAiCatalogItemOutsideOwningProject(item, { isProjectNamespace, projectId, glFeatures });
};

/**
 * Checks if user can manage AI flow triggers.
 *
 * @param {Object} options
 * @param {Object} options.glAbilities - GitLab abilities object
 * @returns {Boolean}
 */
export const canManageAiFlowTriggers = (options = {}) => {
  const { glAbilities = {} } = options;
  return Boolean(glAbilities.manageAiFlowTriggers);
};

/**
 * Checks if an AI catalog item type is enabled in the Duo settings.
 *
 * @param {Object} duoSettings - Configuration settings for custom items
 * @param {string} itemType - The item type to check (e.g. AI_CATALOG_TYPE_AGENT)
 * @returns {Boolean}
 */
export const isItemTypeEnabledInDuoSettings = ({ duoSettings = {}, itemType }) => {
  const { duoCustomAgentsEnabled, duoCustomFlowsEnabled, duoExternalAgentsEnabled } = duoSettings;
  const enabledByType = {
    [AI_CATALOG_TYPE_AGENT]: duoCustomAgentsEnabled,
    [AI_CATALOG_TYPE_FLOW]: duoCustomFlowsEnabled,
    [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: duoExternalAgentsEnabled,
    [AI_CATALOG_TYPE_FOUNDATIONAL_AGENT]: true,
  };

  return Boolean(enabledByType[itemType]);
};
