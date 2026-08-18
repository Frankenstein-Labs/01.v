import { __, s__ } from '~/locale';
import { roleDropdownItems, initialSelectedRole } from 'ee/members/utils';

export { callRoleUpdateApi, setMemberRole } from '~/members/components/table/drawer/utils';

export const ldapRole = { text: s__('MemberRole|Use LDAP sync role'), value: 'ldap-role' };

export const getRoleDropdownItems = (member) => {
  const roles = roleDropdownItems(member);
  // Add in the LDAP group and role if the member is an LDAP user.
  if (member.canOverride) {
    roles.flatten.unshift(ldapRole);
    roles.formatted.unshift({ text: __('LDAP'), options: [ldapRole] });
  }

  return roles;
};

export const getMemberRole = (roles, member) => {
  // If the member is an LDAP user and their role is synced to the LDAP settings, return the LDAP role instead of the
  // actual role they have.
  if (member.canOverride && !member.isOverridden) {
    return ldapRole;
  }

  const { stringValue, integerValue, memberRoleId } = member.accessLevel;
  const role = initialSelectedRole(roles, member);
  // When the user is logged out or has the Minimal Access role, the member data won't have available custom roles,
  // only the current role data in the accessLevel property. This means that if the member has a custom role,
  // initialSelectedRole() won't return anything, so the role name won't show. To fix this, we'll manually create a role
  // object using the accessLevel data.
  return role || { text: stringValue, value: integerValue, memberRoleId };
};
