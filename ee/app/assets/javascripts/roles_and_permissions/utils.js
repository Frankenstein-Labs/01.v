import { intersection } from 'lodash-es';
import { TYPENAME_MEMBER_ROLE, TYPENAME_ADMIN_MEMBER_ROLE } from '~/graphql_shared/constants';

export const isCustomRole = ({ __typename }) => __typename === TYPENAME_MEMBER_ROLE;
export const isAdminRole = ({ __typename }) => __typename === TYPENAME_ADMIN_MEMBER_ROLE;

export const isPermissionPreselected = (
  { enabledForGroupAccessLevels: groupLevels, enabledForProjectAccessLevels: projectLevels },
  accessLevel,
) => {
  let enabledForAccessLevels;
  if (groupLevels && projectLevels) {
    enabledForAccessLevels = intersection(groupLevels, projectLevels);
  } else {
    enabledForAccessLevels = groupLevels || projectLevels || [];
  }

  return enabledForAccessLevels.includes(accessLevel);
};

// Whether the role is used or not, which also determines if it's deletable or not.
export const isRoleInUse = (role) => {
  return (
    role.usersCount > 0 ||
    role.dependentSecurityPolicies?.length > 0 ||
    role.ldapAdminRoleLinks?.nodes?.length > 0
  );
};
