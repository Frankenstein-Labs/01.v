import { convertToGraphQLId } from '~/graphql_shared/utils';
import { CONTEXT_TYPE } from '~/members/constants';
import { graphqlClient } from '~/members/graphql_client';
import GroupPendingMemberApprovalsQuery from './group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from './project_pending_member_approvals.query.graphql';

/** Removes Group(or Project)PendingMemberApprovalsQuery data from the cache */
export const evictCache = ({ context, group, project }) => {
  const isProject = context === CONTEXT_TYPE.PROJECT;

  const { cache } = graphqlClient;
  // eslint-disable-next-line @gitlab/require-i18n-strings
  const typename = isProject ? 'Project' : 'Group';
  const id = isProject ? project.id : group.id;
  const graphqlId = convertToGraphQLId(typename, id);
  const cacheId = cache.identify({
    __typename: typename,
    id: graphqlId,
  });

  cache.evict({
    id: cacheId,
    fieldName: 'pendingMemberApprovals',
  });
  cache.gc();
};

/** Fetch Group(or Project)PendingMemberApprovalsQuery requests count */
export const fetchCount = async ({ context, group, project }) => {
  const isProject = context === CONTEXT_TYPE.PROJECT;
  const query = isProject ? ProjectPendingMemberApprovalsQuery : GroupPendingMemberApprovalsQuery;
  const response = await graphqlClient.query({
    query,
    variables: {
      fullPath: isProject ? project.path : group.path,
      first: 0,
    },
    fetchPolicy: 'network-only',
  });

  const count = isProject
    ? response.data.project.pendingMemberApprovals.count
    : response.data.group.pendingMemberApprovals.count;

  return count;
};
