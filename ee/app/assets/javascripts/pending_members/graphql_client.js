import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

function approvePendingGroupmemberApi(namespaceId, userId) {
  const APPROVE_PENDING_GROUP_MEMBER_PATH = '/api/:version/groups/:id/members/:user_id/approve';

  const url = buildApiUrl(APPROVE_PENDING_GROUP_MEMBER_PATH)
    .replace(':id', namespaceId)
    .replace(':user_id', userId);

  return axios.put(url);
}

function approveAllPendingGroupmembersApi(namespaceId) {
  const APPROVE_ALL_PENDING_GROUP_MEMBERS_PATH = '/api/:version/groups/:id/members/approve_all';

  const url = buildApiUrl(APPROVE_ALL_PENDING_GROUP_MEMBERS_PATH).replace(':id', namespaceId);

  return axios.post(url);
}

const resolvers = {
  Mutation: {
    async approvePendingGroupMember(_, { namespaceId, id }) {
      try {
        await approvePendingGroupmemberApi(namespaceId, getIdFromGraphQLId(id));
      } catch (error) {
        throw new Error(error);
      }
    },
    async approveAllPendingGroupMembers(_, { namespaceId }) {
      try {
        await approveAllPendingGroupmembersApi(namespaceId);
      } catch (error) {
        throw new Error(error);
      }
    },
  },
};

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(resolvers),
});

export default apolloProvider;
