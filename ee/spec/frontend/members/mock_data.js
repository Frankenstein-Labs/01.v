import { member, dataAttribute as CEDataAttribute } from 'jest/members/mock_data';
import { MEMBERS_TAB_TYPES } from 'ee/members/constants';
import { pagination as promotionRequestsPagination } from './promotion_requests/mock_data';

// eslint-disable-next-line import/export
export * from 'jest/members/mock_data';

export const bannedMember = {
  ...member,
  banned: true,
};

export const customRoles = [
  {
    baseAccessLevel: 10,
    name: 'custom role 1',
    description: 'custom role 1 description',
    memberRoleId: 101,
    permissions: [
      { name: 'Permission 0', description: 'Permission description 0' },
      { name: 'Permission 1', description: 'Permission description 1' },
    ],
  },
  {
    baseAccessLevel: 20,
    name: 'custom role 2',
    description: null,
    memberRoleId: 102,
    permissions: [
      { name: 'Permission 2', description: 'Permission description 2' },
      { name: 'Permission 3', description: 'Permission description 3' },
    ],
  },
];

export const upgradedMember = {
  ...member,
  accessLevel: {
    integerValue: 10,
    stringValue: 'custom role 1',
    memberRoleId: 101,
    description: 'custom role 1 description',
  },
  customRoles,
};

export const updateableCustomRoleMember = {
  ...upgradedMember,
  isDirectMember: true,
  canUpdate: true,
  memberPath: 'group/path/-/group_members/238',
  namespace: 'user',
};

export const ldapMember = {
  ...updateableCustomRoleMember,
  canOverride: true,
  isOverridden: false,
  ldapOverridePath: 'group/path/-/group_members/238/override',
};

export const ldapOverriddenMember = { ...ldapMember, isOverridden: true };

// eslint-disable-next-line import/export
export const dataAttribute = JSON.stringify({
  ...JSON.parse(CEDataAttribute),
  [MEMBERS_TAB_TYPES.promotionRequest]: {
    pagination: promotionRequestsPagination,
  },
});
