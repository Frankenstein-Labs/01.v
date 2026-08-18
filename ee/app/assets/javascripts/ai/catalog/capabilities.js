import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
  VISIBILITY_LEVEL_RESTRICTED,
} from './constants';

/**
 * Returns whether an AI Catalog item has restricted visibility and the
 * `ai_catalog_internal_visibility` feature flag is enabled.
 *
 * Defined first because it is used by other helpers in this module.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} glFeatures - The feature flags object from glFeatureFlagsMixin
 * @returns {Boolean}
 */
export const isAiCatalogItemRestricted = (item, glFeatures = {}) => {
  return (
    Boolean(glFeatures.aiCatalogInternalVisibility) &&
    item.visibility === VISIBILITY_LEVEL_RESTRICTED
  );
};

/**
 * Checks whether an AI Catalog item is enabled at the group level.
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const isAiCatalogItemEnabledInGroup = (item) => {
  return Boolean(item?.configurationForGroup?.enabled);
};

/**
 * Checks whether an AI Catalog item is enabled at the project level.
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const isAiCatalogItemEnabledInProject = (item) => {
  return Boolean(item?.configurationForProject?.enabled);
};

/**
 * Checks whether an AI Catalog item is enabled in the project that manages it
 * (the owning project of a private item).
 *
 * Backed by the `isEnabledInManagedByProject` GraphQL field, which is resolved
 * server-side against the item's owning project and is available regardless of
 * the current namespace context (Explore, project, group).
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const isAiCatalogItemEnabledInManagedByProject = (item) => {
  return Boolean(item?.isEnabledInManagedByProject);
};

/**
 * Checks whether an AI Catalog item is currently enabled in the active namespace.
 *
 * For private items, "enabled" is determined by the single owning project via
 * `isEnabledInManagedByProject`, since a private item can only ever be enabled
 * in that one project. This works in any namespace context (Explore, project,
 * group) without needing a `projectId` query variable.
 *
 * For restricted items (when the flag is enabled), enabled state is scoped to
 * the current namespace just like public items, since a restricted item can be
 * enabled across any project within the same top-level group.
 *
 * For public items, falls back to the namespace-scoped configuration field.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} options
 * @param {Boolean} options.isProjectNamespace - Whether viewing from a project page
 * @param {Object} options.glFeatures - Feature flags object (from glFeatureFlagsMixin)
 * @returns {Boolean}
 */
export const isAiCatalogItemEnabled = (item, options = {}) => {
  const { isProjectNamespace = false, glFeatures = {} } = options;

  if (item && item.public === false && !isAiCatalogItemRestricted(item, glFeatures)) {
    return isAiCatalogItemEnabledInManagedByProject(item);
  }

  return isProjectNamespace
    ? isAiCatalogItemEnabledInProject(item)
    : isAiCatalogItemEnabledInGroup(item);
};

/**
 * Checks whether the "Enable from global" action should be shown.
 * Shown on the explore page when the item is not foundational (unless it is
 * a third-party flow, which is always showable).
 *
 * Login state is intentionally not considered here — the button is still
 * rendered when logged out so it can show a "Log in to enable" tooltip.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} options
 * @param {Boolean} options.isGlobalNamespace - Whether viewing from the explore page
 * @returns {Boolean}
 */
export const showEnableFromGlobalAction = (item, options = {}) => {
  const { isGlobalNamespace = false } = options;
  return (
    isGlobalNamespace &&
    (!item?.foundational || item?.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW)
  );
};

/**
 * Returns the numeric ID of an AI Catalog item's owning project.
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Number|null}
 */
export const getAiCatalogItemOwningProjectId = (item) => {
  const projectGid = item?.project?.id;
  return projectGid ? getIdFromGraphQLId(projectGid) : null;
};

/**
 * Returns the `nameWithNamespace` of the AI Catalog item's owning project.
 *
 * @param {Object} item - The AI Catalog item
 * @returns {String|null}
 */
export const getAiCatalogItemOwningProjectName = (item) => {
  return item?.project?.nameWithNamespace ?? null;
};

/**
 * Whether a private AI Catalog item is being viewed from a project other
 * than its owning project. Only gates project namespaces.
 *
 * Public items, restricted items, and items with a missing owning project id
 * return false. Restricted items can be enabled from any project in the same
 * top-level group, so the owning-project constraint does not apply to them.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} options
 * @param {Boolean} options.isProjectNamespace - Viewing from a project page
 * @param {String|Number} options.projectId - Current project id (numeric)
 * @param {Object} options.glFeatures - Feature flags object (from glFeatureFlagsMixin)
 * @returns {Boolean}
 */
export const isAiCatalogItemOutsideOwningProject = (item, options = {}) => {
  const { isProjectNamespace = false, projectId = null, glFeatures = {} } = options;

  if (item?.public) return false;
  if (item && isAiCatalogItemRestricted(item, glFeatures)) return false;
  if (!isProjectNamespace) return false;

  const owningProjectId = getAiCatalogItemOwningProjectId(item);
  if (!owningProjectId) return false;

  return Number(projectId) !== Number(owningProjectId);
};

/**
 * Returns the effective visibility level string for an AI Catalog item,
 * respecting the `ai_catalog_internal_visibility` feature flag.
 *
 * When the flag is enabled, the `visibility` field from the backend is used
 * directly. When the flag is disabled, visibility is derived from the legacy
 * `public` boolean: `true` → `PUBLIC`, `false` → `PRIVATE`.
 *
 * @param {Object} item - The AI Catalog item
 * @param {Object} glFeatures - The feature flags object from glFeatureFlagsMixin
 * @returns {String} One of VISIBILITY_LEVEL_PUBLIC, VISIBILITY_LEVEL_RESTRICTED,
 *   or VISIBILITY_LEVEL_PRIVATE
 */
export const getAiCatalogItemVisibilityLevel = (item, glFeatures = {}) => {
  if (glFeatures.aiCatalogInternalVisibility && item?.visibility) {
    return item.visibility;
  }
  return item.public ? VISIBILITY_LEVEL_PUBLIC : VISIBILITY_LEVEL_PRIVATE;
};
