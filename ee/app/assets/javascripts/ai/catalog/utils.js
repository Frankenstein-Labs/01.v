import { s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  VERSION_LATEST,
  VERSION_PINNED,
  VERSION_PINNED_GROUP,
  VERIFICATION_LEVEL_GITLAB_MAINTAINED,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  TYPENAME_AI_FOUNDATIONAL_CHAT_AGENT,
} from './constants';

/**
 * Known permission/authorization error messages returned by the GitLab GraphQL API.
 * These represent expected authorization failures (e.g. a user lacking access to a
 * catalog resource) and should not be reported to Sentry as actionable errors.
 */
const KNOWN_PERMISSION_ERROR_MESSAGES = [
  // eslint-disable-next-line @gitlab/require-i18n-strings
  "You don't have permission to access this workflow.",
  // eslint-disable-next-line @gitlab/require-i18n-strings
  "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
];

/**
 * Known GraphQL error extension codes that indicate a permission/authorization failure.
 */
const KNOWN_PERMISSION_ERROR_CODES = ['NO_RESOURCE_PERMISSIONS'];

/**
 * Returns true if the given error is a known permission/authorization error that
 * does not need to be reported to Sentry. These are expected GraphQL authorization
 * failures, not bugs in the client.
 *
 * @param {Error|unknown} error
 * @returns {boolean}
 */
export const isKnownPermissionError = (error) => {
  if (!error) return false;

  // Check graphQLErrors extension codes (ApolloError)
  if (
    Array.isArray(error.graphQLErrors) &&
    error.graphQLErrors.some((e) => KNOWN_PERMISSION_ERROR_CODES.includes(e?.extensions?.code))
  ) {
    return true;
  }

  // Check error message against known permission error strings
  const message = error?.message ?? String(error);
  return KNOWN_PERMISSION_ERROR_MESSAGES.some((knownMessage) => message.includes(knownMessage));
};

export const prerequisitesPath = helpPagePath('user/duo_agent_platform/ai_catalog', {
  anchor: 'view-the-ai-catalog',
});

export const prerequisitesError = (message, params = {}) => {
  return sprintf(
    message,
    {
      linkStart: `<a href="${prerequisitesPath}" target="_blank">`,
      linkEnd: '</a>',
      ...params,
    },
    false,
  );
};

export const itemTypeDisabledAlertLink = (message, duoSettingsPath) => {
  return sprintf(
    message,
    {
      linkStart: `<a href="${duoSettingsPath}" target="_blank">`,
      linkEnd: '</a>',
    },
    false,
  );
};

/**
 * Helper to retrieve nested version data so we don't have to pass duplicate objects around.
 *
 * @param {Object} obj - an Item or ItemConsumer
 * @param {String} keys - a dot-notated stringh where each item is a key in the obj, leading to the nested value.
 *
 * @example
 * ```
 * const pinnedVersionKey = 'configurationForProject.pinnedItemVersion';
 * const latestVersionKey = 'latestVersion';
 * ```
 */
export const getByVersionKey = (obj, keys) => {
  return (keys || '').split('.').reduce((acc, key) => acc?.[key], obj);
};

const resolveVersionKey = (item, { isGlobalNamespace, isGroupNamespace } = {}) => {
  if (isGlobalNamespace) return VERSION_LATEST;
  if (item?.configurationForProject) return VERSION_PINNED;
  if (isGroupNamespace && item?.configurationForGroup) return VERSION_PINNED_GROUP;
  return VERSION_LATEST;
};

/**
 * Determines version based on scope configuration priority:
 * 1. Project config > VERSION_PINNED
 * 2. Group config (group namespace only) > VERSION_PINNED_GROUP
 * 3. Global, project namespace without a project config, or no configs > VERSION_LATEST
 */
export const resolveVersion = (item, { isGlobalNamespace, isGroupNamespace } = {}) => {
  const key = resolveVersionKey(item, { isGlobalNamespace, isGroupNamespace });
  const data = getByVersionKey(item, key);

  return {
    ...data,
    key,
  };
};

/**
 * Returns the cancel route for an AI Catalog form.
 * Navigates to the show page when editing an existing item, or the index page when creating.
 *
 * @param {Object} routeParams - The current route's params object (e.g. this.$route.params)
 * @param {string} showRouteName - Route name for the item's show page
 * @param {string} indexRouteName - Route name for the catalog index page
 * @returns {{ name: string, params?: { id: string } }}
 */
export const getCancelRoute = (routeParams, showRouteName, indexRouteName) => {
  if (routeParams.id) {
    return { name: showRouteName, params: { id: routeParams.id } };
  }
  return { name: indexRouteName };
};

/**
 * Returns the submit button label for an AI Catalog form.
 *
 * @param {boolean} isEditMode - Whether or not the form is in edit mode
 * @param {string} createLabel - Label to display in create mode (e.g. s__('AICatalog|Create agent'))
 * @returns {string}
 */
export const getSubmitButtonText = (isEditMode, createLabel) => {
  return isEditMode ? s__('AICatalog|Save changes') : createLabel;
};

/**
 * Checks if an item is GitLab-maintained to avoid the long comparison throughout the codebase.
 * Drives display concerns (tanuki badge, "GitLab" attribution, report button).
 *
 * @param {Object} item - The AI Catalog item
 * @returns {Boolean}
 */
export const isGitLabMaintainedItem = (item) => {
  return item?.verificationLevel === VERIFICATION_LEVEL_GITLAB_MAINTAINED;
};

/**
 * Normalizes a node from the `aiCatalogCustomAndFoundationalItems` query into the
 * shape the catalog list components expect.
 *
 * Foundational chat agents are injected via fixtures (no database record) and are
 * returned as `AiFoundationalChatAgent` nodes, which expose a smaller set of fields
 * than `AiCatalogItem`. This fills in the fields the list item relies on so the two
 * node types can be rendered uniformly.
 *
 * @param {Object} node - A node from the custom and foundational items query
 * @returns {Object} A list-item-compatible item
 */
export const normalizeCustomOrFoundationalItem = (node) => {
  // eslint-disable-next-line no-underscore-dangle
  if (node?.__typename !== TYPENAME_AI_FOUNDATIONAL_CHAT_AGENT) {
    return node;
  }

  return {
    itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
    foundational: true,
    public: true,
    verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
    starCount: 0,
    starred: false,
    last30DayUsageCount: 0,
    ...node,
  };
};
