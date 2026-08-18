import { ENTITY_PROJECT, ENTITY_GROUP } from 'ee/ci/secrets/constants';

// project (shared)
import getProjectSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_project_secret_manager_status.query.graphql';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import disableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_secret_manager.mutation.graphql';
import searchProjectMembersQuery from '~/graphql_shared/queries/project_user_members_search.query.graphql';

// group (shared)
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';
import enableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import disableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_group_secret_manager.mutation.graphql';
import groupUsersSearchQuery from '~/graphql_shared/queries/group_users_search.query.graphql';

// project
import secretsPermissionsQuery from './graphql/secrets_permission.query.graphql';
import createSecretsPermission from './graphql/create_secrets_permission.mutation.graphql';
import deleteSecretsPermission from './graphql/delete_secrets_permission.mutation.graphql';

// group
import groupSecretsPermissionsQuery from './graphql/group_secrets_permission.query.graphql';
import createGroupSecretsPermission from './graphql/create_group_secrets_permission.mutation.graphql';
import deleteGroupSecretsPermission from './graphql/delete_group_secrets_permission.mutation.graphql';

export const SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG = {
  [ENTITY_PROJECT]: {
    type: ENTITY_PROJECT,
    getStatus: {
      lookup: (data) => data?.projectSecretsManager,
      query: getProjectSecretManagerStatusQuery,
    },
    getPermissions: {
      lookup: (data) => data?.secretsPermissions,
      query: secretsPermissionsQuery,
    },
    enable: {
      lookup: (data) => data?.projectSecretsManagerInitialize,
      mutation: enableSecretManagerMutation,
    },
    disable: {
      lookup: (data) => data?.projectSecretsManagerDeprovision,
      mutation: disableSecretManagerMutation,
    },
    searchMembers: {
      lookup: (data) => data?.project.projectMembers,
      query: searchProjectMembersQuery,
      relations: ['DIRECT', 'INHERITED', 'INVITED_GROUPS'],
    },
    createPermission: {
      mutation: createSecretsPermission,
    },
    deletePermission: {
      mutation: deleteSecretsPermission,
    },
  },
  [ENTITY_GROUP]: {
    type: ENTITY_GROUP,
    getStatus: {
      lookup: (data) => data?.groupSecretsManager,
      query: getGroupSecretManagerStatusQuery,
    },
    getPermissions: {
      lookup: (data) => data?.secretsPermissions,
      query: groupSecretsPermissionsQuery,
    },
    enable: {
      lookup: (data) => data?.groupSecretsManagerInitialize,
      mutation: enableGroupSecretManagerMutation,
    },
    disable: {
      lookup: (data) => data?.groupSecretsManagerDeprovision,
      mutation: disableGroupSecretManagerMutation,
    },
    searchMembers: {
      lookup: (data) => data?.namespace.users,
      query: groupUsersSearchQuery,
      relations: ['DIRECT', 'INHERITED', 'SHARED_FROM_GROUPS'],
    },
    createPermission: {
      mutation: createGroupSecretsPermission,
    },
    deletePermission: {
      mutation: deleteGroupSecretsPermission,
    },
  },
};
