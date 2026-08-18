import showGlobalToast from '~/vue_shared/plugins/global_toast';
import { __, s__ } from '~/locale';
import {
  generateBadges as CEGenerateBadges,
  roleDropdownItems as CERoleDropdownItems,
  handleMemberRoleUpdate as CEHandleMemberRoleUpdate,
} from '~/members/utils';

export {
  isGroup,
  isCurrentUser,
  canRemove,
  canRemoveBlockedByLastOwner,
  canResend,
  canUpdate,
} from '~/members/utils';

export const generateBadges = ({ member, isCurrentUser, canManageMembers }) => [
  ...CEGenerateBadges({ member, isCurrentUser, canManageMembers }),
  {
    show: member.usingLicense,
    text: __('Is using seat'),
    variant: 'neutral',
  },
  {
    show: member.groupSso,
    text: __('SAML'),
    variant: 'info',
  },
  {
    show: member.groupManagedAccount,
    text: __('Managed Account'),
    variant: 'info',
  },
  {
    show: member.canOverride,
    text: __('LDAP'),
    variant: 'info',
  },
  {
    show: member.enterpriseUserOfThisGroup,
    text: __('Enterprise'),
    variant: 'info',
  },
  {
    show: member.user?.isServiceAccount ?? false,
    text: __('Service Account'),
    variant: 'neutral',
  },
];

/**
 * Creates the dropdowns options for static and custom roles
 *
 * @param {object} member
 *   @param {Map<string, number>} member.validRoles
 *   @param {Array<{baseAccessLevel: number, name: string, memberRoleId: number}>} member.customRoles
 */
export const roleDropdownItems = ({ validRoles, customRoles }) => {
  const defaultRoleItems = CERoleDropdownItems({ validRoles });

  if (!customRoles?.length) {
    return defaultRoleItems;
  }

  const customRoleItems = customRoles.map(({ baseAccessLevel, name, ...role }) => ({
    ...role,
    accessLevel: baseAccessLevel,
    text: name,
    value: `role-custom-${role.memberRoleId}`,
  }));

  return {
    flatten: [...defaultRoleItems.flatten, ...customRoleItems],
    formatted: [
      { text: s__('MemberRole|Default roles'), options: defaultRoleItems.flatten },
      { text: s__('MemberRole|Custom roles'), options: customRoleItems },
    ],
  };
};

/**
 * Finds and returns unique value
 *
 * @param {Array<{accessLevel: number, memberRoleId: null|number, text: string, value: string}>} flattenDropdownItems
 * @param {object} member
 *   @param {{integerValue: number, memberRoleId: undefined|null|number}} member.accessLevel
 */
export const initialSelectedRole = (flattenDropdownItems, member) => {
  return flattenDropdownItems.find(
    ({ accessLevel, memberRoleId }) =>
      accessLevel === member.accessLevel.integerValue &&
      (memberRoleId ?? null) === (member.accessLevel.memberRoleId ?? null),
  );
};

export const canDisableTwoFactor = (member) => {
  return Boolean(member.canDisableTwoFactor);
};

export const canOverride = (member) => member.canOverride && member.isDirectMember;

export const canUnban = (member) => {
  return Boolean(member.banned) && member.canUnban;
};

/**
 * Handles role change response, whether it was immediate or enqueued
 *
 * @param {object} update
 *  @param {string} update.currentRole
 *  @param {string} update.requestedRole
 *  @param {object} update.response server response
 * @returns {string} actual new member role
 */
export const handleMemberRoleUpdate = ({ currentRole, requestedRole, response }) => {
  // key and enum are defined in ee/app/controllers/concerns/ee/membership_actions.rb
  if (response?.data?.enqueued) {
    showGlobalToast(s__('Members|Role change request was sent to the administrator.'));
    return currentRole;
  }

  return CEHandleMemberRoleUpdate({ currentRole, requestedRole, response });
};
