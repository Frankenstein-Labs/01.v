import Api from '~/api';
import { createAlert } from '~/alert';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import * as types from './mutation_types';

export function fetchPage({ commit, state }, newPage) {
  return Api.groupMembers(state.groupId, {
    with_saml_identity: 'true',
    page: newPage || state.pageInfo.page,
    per_page: state.pageInfo.perPage,
  })
    .then((response) => {
      const { headers, data } = response;
      const pageInfo = parseIntPagination(normalizeHeaders(headers));
      commit(types.RECEIVE_SAML_MEMBERS_SUCCESS, {
        members: data.map(
          ({ group_saml_identity: identity, group_scim_identity: scimIdentity, ...item }) => ({
            ...item,
            identity: identity ? identity.extern_uid : null,
            scim_identity: scimIdentity ? scimIdentity.extern_uid : null,
          }),
        ),
        pageInfo,
      });
    })
    .catch(() => {
      createAlert({
        message: __('An error occurred while loading group members.'),
      });
    });
}
