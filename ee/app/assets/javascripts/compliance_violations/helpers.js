import { REGEXES } from 'ee/vulnerabilities/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isAbsolute, isValidURL } from '~/lib/utils/url_utility';
import { makeDetailPanelItemFullPath } from '~/work_items/utils';
import { TYPE_ISSUE } from '~/issues/constants';

// Get the issue in the format expected by the descendant components of related_issues_block.vue.
export const getFormattedIssue = (issue, violationProjectPath) => {
  // Extract project path using GitLab's built-in utility function
  const projectPath = makeDetailPanelItemFullPath(issue, null, TYPE_ISSUE);

  return {
    ...issue,
    id: getIdFromGraphQLId(issue.id), // Convert GraphQL ID to numeric ID
    iid: parseInt(issue.iid, 10), // Convert iid to number
    path: issue.webUrl,
    projectPath,
    reference: projectPath === violationProjectPath ? issue.reference : issue.referencePath,
  };
};

export const getAddRelatedIssueRequestParams = (reference, defaultProjectPath) => {
  let issueIid = reference;
  let projectPath = defaultProjectPath;

  // If the reference is an issue number, parse out just the issue number.
  if (REGEXES.ISSUE_FORMAT.test(reference)) {
    [, issueIid] = REGEXES.ISSUE_FORMAT.exec(reference);
  }
  // If the reference is an absolute URL and matches the issues URL format, parse out the project and issue.
  else if (isValidURL(reference) && isAbsolute(reference)) {
    const { pathname } = new URL(reference);

    if (REGEXES.LINK_FORMAT.test(pathname)) {
      [, projectPath, issueIid] = REGEXES.LINK_FORMAT.exec(pathname);
    }
  }

  return { issueIid, projectPath };
};
