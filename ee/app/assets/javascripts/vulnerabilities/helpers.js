import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isAbsolute, isValidURL } from '~/lib/utils/url_utility';
import {
  REGEXES,
  SUPPORTED_IDENTIFIER_TYPE_CWE,
  SUPPORTED_IDENTIFIER_TYPE_OWASP,
  VULNERABILITY_TAB_INDEX_TO_NAME,
} from './constants';

// Get the issue in the format expected by the descendant components of related_issues_block.vue.
export const getFormattedIssue = (issue) => ({
  ...issue,
  reference: `#${issue.iid}`,
  path: issue.web_url,
});

export const getAddRelatedIssueRequestParams = (reference, defaultProjectId) => {
  let issueId = reference;
  let projectId = defaultProjectId;

  // If the reference is an issue number, parse out just the issue number.
  if (REGEXES.ISSUE_FORMAT.test(reference)) {
    [, issueId] = REGEXES.ISSUE_FORMAT.exec(reference);
  }
  // If the reference is an absolute URL and matches the issues URL format, parse out the project and issue.
  else if (isValidURL(reference) && isAbsolute(reference)) {
    const { pathname } = new URL(reference);

    if (REGEXES.LINK_FORMAT.test(pathname)) {
      [, projectId, issueId] = REGEXES.LINK_FORMAT.exec(pathname);
    }
  }

  return { target_issue_iid: issueId, target_project_id: projectId };
};

export const normalizeGraphQLNote = (note) => {
  if (!note) {
    return null;
  }

  return {
    ...note,
    id: getIdFromGraphQLId(note.id),
    author: {
      ...note.author,
      id: getIdFromGraphQLId(note.author.id),
      path: note.author.webPath,
    },
  };
};

export const normalizeGraphQLVulnerability = (vulnerability) => {
  if (!vulnerability) {
    return null;
  }

  const newVulnerability = { ...vulnerability };

  if (vulnerability.id) {
    newVulnerability.id = getIdFromGraphQLId(vulnerability.id);
  }

  if (vulnerability.state) {
    newVulnerability.state = vulnerability.state.toLowerCase();
  }

  ['confirmed', 'resolved', 'dismissed'].forEach((state) => {
    if (vulnerability[`${state}By`]?.id) {
      newVulnerability[`${state}ById`] = getIdFromGraphQLId(vulnerability[`${state}By`].id);
      delete newVulnerability[`${state}By`];
    }
  });

  return newVulnerability;
};

export const normalizeGraphQLLastStateTransition = (graphQLVulnerability, vulnerability) => {
  const stateTransitions = [...vulnerability.stateTransitions];

  // The vulnerability status mutation only returns 1 stateTransition
  const [graphQLLastStateTransitions] = graphQLVulnerability.stateTransitions.nodes;
  stateTransitions.push({
    ...graphQLLastStateTransitions,
    dismissalReason: graphQLLastStateTransitions.dismissalReason?.toLowerCase(),
  });

  return { stateTransitions };
};

export const formatIdentifierExternalIds = ({ externalType, externalId, name }) => {
  return `[${externalType}]-[${externalId}]-[${name}]`;
};

export const isSupportedIdentifier = (externalType) => {
  return (
    externalType?.toLowerCase() === SUPPORTED_IDENTIFIER_TYPE_CWE ||
    // Case matters here. owasp and OWASP require different configuration
    // Currently, our API only support lowercase owasp
    // Uppercase OWASP will be supported in a follow up issue:
    // https://gitlab.com/gitlab-org/gitlab/-/issues/366556
    externalType === SUPPORTED_IDENTIFIER_TYPE_OWASP
  );
};

export const getRefFromBlobPath = (path) => {
  // Matches the 40-character hex string of the Git SHA in the blob path, for example:
  // "/group/project/-/blob/cdeda7ae724a332e008d17245209d5edd9ba6499/src/file.js"
  // will match "cdeda7ae724a332e008d17245209d5edd9ba6499".
  if (typeof path === 'string') {
    const match = path.match(/blob\/([a-f0-9]{40})/);
    return match ? match[1] : '';
  }
  return '';
};

/**
 *  Determines the tab index for code flow based on the route query parameters.
 */
export const getTabIndexForCodeFlowPage = (route) => {
  if (route?.query?.tab) {
    return 1;
  }
  return 0;
};

/**
 * @typedef {Object} TabNavigationParams
 * @property {string} path - The current route path.
 * @property {number} index - The index of the tab to be set.
 * @property {number} [selectedIndex] - The currently selected tab index. This is optional as it might be undefined.
 */

/**
 * Updates the route to reflect the selected tab index.
 * This function is used to update the URL when switching between different views
 * of the vulnerability, between 'details' and 'code flow'
 * @param {Object} router - The router object used for navigation.
 * @param {TabNavigationParams} routeProps - The route properties including path and tab indices.
 */
export const setTabIndexForCodeFlowPage = (router, routeProps) => {
  const { path, index, selectedIndex } = routeProps;

  // Don't set the tab index if it's the same. This prevents some querystring bugs.
  if (index === selectedIndex) {
    return;
  }
  router.push({
    path,
    query: { tab: VULNERABILITY_TAB_INDEX_TO_NAME[index] },
  });
};
