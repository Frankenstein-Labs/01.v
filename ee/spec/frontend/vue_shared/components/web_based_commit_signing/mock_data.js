// Query responses
export const groupQueryResponse = (webBasedCommitSigningEnabled = false) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      webBasedCommitSigningEnabled,
    },
  },
});

export const projectQueryResponse = (
  projectWebBasedCommitSigningEnabled = false,
  groupWebBasedCommitSigningEnabled = false,
) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      webBasedCommitSigningEnabled: projectWebBasedCommitSigningEnabled,
      group: {
        id: 'gid://gitlab/Group/1',
        webBasedCommitSigningEnabled: groupWebBasedCommitSigningEnabled,
      },
    },
  },
});

// Mutation success responses
export const groupMutationSuccessResponse = (webBasedCommitSigningEnabled = true) => ({
  data: {
    groupUpdate: {
      group: {
        id: 'gid://gitlab/Group/1',
        webBasedCommitSigningEnabled,
      },
      errors: [],
    },
  },
});

export const projectMutationSuccessResponse = (webBasedCommitSigningEnabled = true) => ({
  data: {
    projectSettingsUpdate: {
      projectSettings: {
        webBasedCommitSigningEnabled,
      },
      errors: [],
    },
  },
});

// Mutation error responses
export const projectMutationErrorResponse = (errors = ['Permission denied']) => ({
  data: {
    projectSettingsUpdate: {
      projectSettings: null,
      errors,
    },
  },
});
