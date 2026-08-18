/* eslint-disable @gitlab/no-hardcoded-urls -- REST API routes using Api.buildUrl is acceptable */
import { DEFAULT_PER_PAGE } from '~/api';
import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

const GROUP_PATH = '/api/:version/groups/:id';
const SUBSCRIPTIONS_GROUPS_PATH = '/-/subscriptions/groups';
const GROUPS_BILLABLE_MEMBERS_SINGLE_PATH = '/api/:version/groups/:group_id/billable_members/:id';
const GROUPS_BILLABLE_MEMBERS_PATH = '/api/:version/groups/:id/billable_members';
const GROUPS_BILLABLE_MEMBERS_SINGLE_MEMBERSHIPS_PATH =
  '/api/:version/groups/:group_id/billable_members/:member_id/memberships';
const GROUPS_BILLABLE_MEMBERS_SINGLE_INDIRECT_MEMBERSHIPS_PATH =
  '/api/:version/groups/:group_id/billable_members/:member_id/indirect';
const GROUPS_ENTERPRISE_USERS_PATH = '/api/:version/groups/:id/enterprise_users';

export const fetchBillableGroupMembersList = (namespaceId, options = {}) => {
  const url = buildApiUrl(GROUPS_BILLABLE_MEMBERS_PATH).replace(':id', namespaceId);
  const defaults = {
    per_page: DEFAULT_PER_PAGE,
    page: 1,
  };

  return axios.get(url, {
    params: {
      ...defaults,
      ...options,
    },
  });
};

export const fetchBillableGroupMemberMemberships = (namespaceId, memberId) => {
  const url = buildApiUrl(GROUPS_BILLABLE_MEMBERS_SINGLE_MEMBERSHIPS_PATH)
    .replace(':group_id', namespaceId)
    .replace(':member_id', memberId);

  return axios.get(url);
};

export const fetchBillableGroupMemberIndirectMemberships = (namespaceId, memberId) => {
  const url = buildApiUrl(GROUPS_BILLABLE_MEMBERS_SINGLE_INDIRECT_MEMBERSHIPS_PATH)
    .replace(':group_id', namespaceId)
    .replace(':member_id', memberId);

  return axios.get(url);
};

export const removeBillableMemberFromGroup = (groupId, memberId) => {
  const url = buildApiUrl(GROUPS_BILLABLE_MEMBERS_SINGLE_PATH)
    .replace(':group_id', groupId)
    .replace(':id', memberId);

  return axios.delete(url);
};

export const fetchGroupEnterpriseUsers = (groupId, options) => {
  const url = buildApiUrl(GROUPS_ENTERPRISE_USERS_PATH).replace(':id', groupId);
  const defaults = {
    per_page: DEFAULT_PER_PAGE,
    page: 1,
  };

  return axios.get(url, {
    params: {
      ...defaults,
      ...options,
    },
  });
};

export const updateGroupSettings = (id, settings) => {
  const url = buildApiUrl(GROUP_PATH).replace(':id', id);

  return axios.put(url, settings);
};

export function deleteGroup(groupId, params) {
  const url = buildApiUrl(GROUP_PATH).replace(':id', groupId);

  return axios.delete(url, { params });
}

export function subscriptionsCreateGroup(params = {}) {
  const url = buildApiUrl(SUBSCRIPTIONS_GROUPS_PATH);

  return axios.post(url, params);
}
