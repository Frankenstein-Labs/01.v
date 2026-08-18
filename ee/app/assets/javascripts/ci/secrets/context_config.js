import {
  ENTITY_PROJECT,
  ENTITY_GROUP,
  GROUP_EVENTS,
  GROUP_SECRETS_QUERY_LIMIT,
  PROJECT_EVENTS,
  PROJECT_SECRETS_QUERY_LIMIT,
} from 'ee/ci/secrets/constants';
import {
  getGroupEnvironments,
  getProjectEnvironments,
} from '~/ci/common/private/ci_environments_dropdown';

// project
import getProjectSecrets from 'ee/ci/secrets/graphql/queries/get_project_secrets.query.graphql';
import getProjectSecretsNeedingRotation from 'ee/ci/secrets/graphql/queries/get_project_secrets_needing_rotation.query.graphql';
import getProjectSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_project_secret_manager_status.query.graphql';
import getProjectSecretDetails from 'ee/ci/secrets/graphql/queries/get_project_secret_details.query.graphql';

import createProjectSecret from 'ee/ci/secrets/graphql/mutations/create_project_secret.mutation.graphql';
import enableSecretManager from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import updateProjectSecret from 'ee/ci/secrets/graphql/mutations/update_project_secret.mutation.graphql';
import deleteProjectSecret from 'ee/ci/secrets/graphql/mutations/delete_project_secret.mutation.graphql';

// group
import getGroupSecrets from 'ee/ci/secrets/graphql/queries/get_group_secrets.query.graphql';
import getGroupSecretDetails from 'ee/ci/secrets/graphql/queries/get_group_secret_details.query.graphql';
import getGroupSecretsNeedingRotation from 'ee/ci/secrets/graphql/queries/get_group_secrets_needing_rotation.query.graphql';
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';
import createGroupSecret from 'ee/ci/secrets/graphql/mutations/create_group_secret.mutation.graphql';
import enableGroupSecretManager from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import updateGroupSecret from 'ee/ci/secrets/graphql/mutations/update_group_secret.mutation.graphql';
import deleteGroupSecret from 'ee/ci/secrets/graphql/mutations/delete_group_secret.mutation.graphql';

export const SECRETS_MANAGER_CONTEXT_CONFIG = {
  [ENTITY_PROJECT]: {
    eventTracking: PROJECT_EVENTS,
    type: ENTITY_PROJECT,
    createSecret: {
      mutation: createProjectSecret,
    },
    deleteSecret: {
      mutation: deleteProjectSecret,
    },
    enableSecretsManager: {
      lookup: (data) => data?.projectSecretsManagerInitialize,
      mutation: enableSecretManager,
    },
    environments: {
      lookup: (data) => data?.project?.environments,
      query: getProjectEnvironments,
    },
    getSecretDetails: {
      query: getProjectSecretDetails,
    },
    getSecrets: {
      query: getProjectSecrets,
      first: PROJECT_SECRETS_QUERY_LIMIT,
    },
    getSecretsNeedingRotation: {
      query: getProjectSecretsNeedingRotation,
    },
    getStatus: {
      query: getProjectSecretManagerStatusQuery,
    },
    updateSecret: {
      mutation: updateProjectSecret,
    },
  },
  [ENTITY_GROUP]: {
    eventTracking: GROUP_EVENTS,
    type: ENTITY_GROUP,
    createSecret: {
      mutation: createGroupSecret,
    },
    deleteSecret: {
      mutation: deleteGroupSecret,
    },
    enableSecretsManager: {
      lookup: (data) => data?.groupSecretsManagerInitialize,
      mutation: enableGroupSecretManager,
    },
    environments: {
      lookup: (data) => data?.group?.environmentScopes,
      query: getGroupEnvironments,
    },
    getSecrets: {
      query: getGroupSecrets,
      first: GROUP_SECRETS_QUERY_LIMIT,
    },
    getSecretDetails: {
      query: getGroupSecretDetails,
    },
    getSecretsNeedingRotation: {
      query: getGroupSecretsNeedingRotation,
    },
    getStatus: {
      query: getGroupSecretManagerStatusQuery,
    },
    updateSecret: {
      mutation: updateGroupSecret,
    },
  },
};
