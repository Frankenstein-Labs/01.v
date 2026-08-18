import {
  mockAgent,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockFlow,
  mockFlowConfigurationForProject,
  mockFlowConfigurationForGroup,
  mockProjectsMaintainerResponse,
} from '../mock_data';

export const createAgentWithPermissions = ({
  adminAiCatalogItem = true,
  foundational = false,
  verificationLevel = foundational ? 'GITLAB_MAINTAINED' : 'UNVERIFIED',
  isPublic = true,
  withProjectConfig = true,
  withGroupConfig = true,
  projectConfigEnabled = true,
  groupConfigEnabled = true,
  // For a private agent the owning project is the only valid target, so by
  // default we mirror `projectConfigEnabled` here. Override explicitly for
  // scenarios where the two should disagree.
  isEnabledInManagedByProject = !isPublic && withProjectConfig && projectConfigEnabled,
  pinnedVersion = null,
  groupPinnedVersion = null,
} = {}) => ({
  ...mockAgent,
  foundational,
  verificationLevel,
  public: isPublic,
  isEnabledInManagedByProject,
  userPermissions: {
    adminAiCatalogItem,
  },
  configurationForProject: withProjectConfig
    ? {
        ...mockAgentConfigurationForProject,
        enabled: projectConfigEnabled,
        pinnedItemVersion: pinnedVersion ?? mockAgentConfigurationForProject.pinnedItemVersion,
      }
    : null,
  configurationForGroup: withGroupConfig
    ? {
        ...mockItemConfigurationForGroup,
        enabled: groupConfigEnabled,
        pinnedItemVersion: groupPinnedVersion ?? mockItemConfigurationForGroup.pinnedItemVersion,
      }
    : null,
});

export const createProjectsMaintainerHandler = () => {
  return jest.fn().mockResolvedValue(mockProjectsMaintainerResponse);
};

export const createFlowWithPermissions = ({
  adminAiCatalogItem = true,
  foundational = false,
  verificationLevel = foundational ? 'GITLAB_MAINTAINED' : 'UNVERIFIED',
  isPublic = true,
  withProjectConfig = true,
  withGroupConfig = true,
  projectConfigEnabled = true,
  groupConfigEnabled = true,
  // For a private flow the owning project is the only valid target, so by
  // default we mirror `projectConfigEnabled` here. Override explicitly for
  // scenarios where the two should disagree.
  isEnabledInManagedByProject = !isPublic && withProjectConfig && projectConfigEnabled,
  pinnedVersion = null,
  groupPinnedVersion = null,
} = {}) => ({
  ...mockFlow,
  foundational,
  verificationLevel,
  public: isPublic,
  isEnabledInManagedByProject,
  userPermissions: {
    adminAiCatalogItem,
  },
  configurationForProject: withProjectConfig
    ? {
        ...mockFlowConfigurationForProject,
        enabled: projectConfigEnabled,
        pinnedItemVersion: pinnedVersion ?? mockFlowConfigurationForProject.pinnedItemVersion,
      }
    : null,
  configurationForGroup: withGroupConfig
    ? {
        ...mockFlowConfigurationForGroup,
        enabled: groupConfigEnabled,
        pinnedItemVersion: groupPinnedVersion ?? mockFlowConfigurationForGroup.pinnedItemVersion,
      }
    : null,
});
