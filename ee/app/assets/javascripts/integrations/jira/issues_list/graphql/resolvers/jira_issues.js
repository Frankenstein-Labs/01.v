import { DEFAULT_PAGE_SIZE } from '~/vue_shared/issuable/list/constants';
import { i18n } from '~/work_items/list/constants';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

const transformJiraIssueAssignees = (jiraIssue) => {
  return jiraIssue.assignees.map((assignee) => ({
    __typename: 'UserCore',
    ...assignee,
  }));
};

const transformJiraIssueAuthor = (jiraIssue, authorId) => {
  return {
    __typename: 'UserCore',
    ...jiraIssue.author,
    id: authorId,
  };
};

const transformJiraIssueLabels = (jiraIssue) => {
  return jiraIssue.labels.map((label) => ({
    __typename: 'Label',
    ...label,
  }));
};

const isJiraCloud = (responseHeaders) => responseHeaders['x-page'] === undefined;

const createJiraCloudPageInfo = (headers) => ({
  __typename: 'JiraIssuesPageInfo',
  nextPageToken: headers['x-next-page-token'] || null,
  isLast: headers['x-is-last'] === 'true',
  page: null,
  total: null,
});

const createJiraServerPageInfo = (headers) => ({
  __typename: 'JiraIssuesPageInfo',
  page: parseInt(headers['x-page'], 10) ?? 1,
  total: parseInt(headers['x-total'], 10) ?? 0,
  nextPageToken: null,
  isLast: null,
});

const transformJiraIssuePageInfo = (responseHeaders = {}) => {
  return isJiraCloud(responseHeaders)
    ? createJiraCloudPageInfo(responseHeaders)
    : createJiraServerPageInfo(responseHeaders);
};

export const transformJiraIssuesREST = (response) => {
  const { headers, data: jiraIssues } = response;

  return {
    __typename: 'JiraIssues',
    errors: [],
    pageInfo: transformJiraIssuePageInfo(headers),
    nodes: jiraIssues.map((rawIssue, index) => {
      const jiraIssue = convertObjectPropsToCamelCase(rawIssue, { deep: true });
      return {
        __typename: 'JiraIssue',
        ...jiraIssue,
        // JIRA issues don't have `id` so we use references.relative
        id: rawIssue.references.relative,
        author: transformJiraIssueAuthor(jiraIssue, index),
        labels: transformJiraIssueLabels(jiraIssue),
        assignees: transformJiraIssueAssignees(jiraIssue),
      };
    }),
  };
};

export default function jiraIssuesResolver(
  _,
  {
    issuesFetchPath,
    page,
    nextPageToken,
    sort,
    state,
    project,
    status,
    authorUsername,
    assigneeUsername,
    labels,
    search,
  },
) {
  return axios
    .get(issuesFetchPath, {
      params: {
        with_labels_details: true,
        per_page: DEFAULT_PAGE_SIZE,
        sort,
        state,
        project,
        status,
        author_username: authorUsername,
        assignee_username: assigneeUsername,
        labels,
        search,
        ...(page && { page }),
        ...(nextPageToken && { next_page_token: nextPageToken }),
      },
    })
    .then((res) => {
      return transformJiraIssuesREST(res);
    })
    .catch((error) => {
      return {
        __typename: 'JiraIssues',
        errors: error?.response?.data?.errors || [i18n.errorFetchingIssues],
        pageInfo: transformJiraIssuePageInfo(),
        nodes: [],
      };
    });
}
