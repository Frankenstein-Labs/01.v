import { getAccessLevelsRolesText } from '~/projects/settings/utils';
import { n__ } from '~/locale';

export const getAccessLevels = (accessLevels = {}) => {
  const total = accessLevels.edges?.length;
  const accessLevelTypes = {
    total,
    users: [],
    groups: [],
    roles: [],
    deployKeys: [],
    memberRoles: [],
  };

  (accessLevels.edges || []).forEach(({ node }) => {
    // Priority order: user > group > deployKey > memberRole > role
    // memberRole must be checked before the role fallback because a
    // member_role-type access level also has an accessLevel integer set
    // (to the role's base_access_level), which would otherwise misclassify
    // it as a plain role.
    if (node.user) {
      const src = node.user.avatarUrl;
      accessLevelTypes.users.push({ src, ...node.user });
    } else if (node.group) {
      accessLevelTypes.groups.push(node.group);
    } else if (node.deployKey) {
      accessLevelTypes.deployKeys.push(node.deployKey);
    } else if (node.memberRole) {
      accessLevelTypes.memberRoles.push(node.memberRole);
    } else {
      accessLevelTypes.roles.push(node.accessLevel);
    }
  });

  return accessLevelTypes;
};

export const getAccessLevelInputFromEdges = (edges) => {
  return edges.flatMap(({ node }) => {
    const result = {};

    if (node.accessLevel !== undefined) {
      result.accessLevel = node.accessLevel;
    }

    if (node.group?.id !== undefined) {
      result.groupId = node.group.id;
      delete result.accessLevel; // backend only expects groupId
    }

    if (node.user?.id !== undefined) {
      result.userId = node.user.id;
      delete result.accessLevel; // backend only expects userId
    }

    if (node.deployKey?.id !== undefined) {
      result.deployKeyId = node.deployKey.id;
      delete result.accessLevel; // backend only expects deployKeyId
    }

    // memberRole must be checked before falling back to accessLevel because a
    // member_role-type access level also has an accessLevel integer set.
    if (node.memberRole?.id !== undefined) {
      result.memberRoleId = node.memberRole.id;
      delete result.accessLevel; // backend only expects memberRoleId
    }

    return Object.keys(result).length > 0 ? [result] : [];
  });
};

export const getAccessLevelsRolesAndEEText = (accessLevels) => {
  const textParts = getAccessLevelsRolesText(accessLevels);

  if (accessLevels.memberRoles?.length) {
    textParts.push(...accessLevels.memberRoles.map((memberRole) => memberRole.name));
  }

  if (accessLevels.groups?.length) {
    textParts.push(n__('1 group', '%d groups', accessLevels.groups.length));
  }

  if (accessLevels.users?.length) {
    textParts.push(n__('1 user', '%d users', accessLevels.users.length));
  }

  return textParts;
};
