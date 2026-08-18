import projectPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/project_pending_member_approvals.json';
import groupPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/group_pending_member_approvals.json';
import { CONTEXT_TYPE } from '~/members/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export const pagination = {
  totalItems: 1,
};

export const groupDefaultProvide = {
  canManageMembers: true,
  context: CONTEXT_TYPE.GROUP,
  group: {
    id: getIdFromGraphQLId(groupPendingMemberApprovalsQueryMockData.data.group.id),
    name: 'gitlab',
    path: 'gitlab-org',
  },
  project: {
    path: null,
  },
};

export const projectDefaultProvide = {
  canManageMembers: true,
  context: CONTEXT_TYPE.PROJECT,
  group: {
    name: 'gitlab',
    path: 'gitlab-org',
  },
  project: {
    id: getIdFromGraphQLId(projectPendingMemberApprovalsQueryMockData.data.project.id),
    path: 'gitlab-org/gitlab-test',
  },
};
