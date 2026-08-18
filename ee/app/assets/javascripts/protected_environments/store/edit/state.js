export const state = ({ entityId, entityType }) => ({
  entityId,
  entityType,
  loading: false,
  protectedEnvironments: [],
  pageInfo: {},
  usersForRules: {},
  newDeployAccessLevelsForEnvironment: {},
  editingRules: {},
});
