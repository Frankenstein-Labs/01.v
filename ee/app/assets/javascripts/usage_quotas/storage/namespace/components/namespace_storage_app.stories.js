import VueApollo from 'vue-apollo';
import { defaultNamespaceProvideValues } from 'ee_jest/usage_quotas/storage/mock_data';
import {
  mockGetNamespaceStorageGraphQLResponse,
  mockGetProjectListStorageGraphQLResponse,
} from 'jest/usage_quotas/storage/mock_data';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getNamespaceStorageQuery from 'ee/usage_quotas/storage/namespace/queries/namespace_storage.query.graphql';
import getProjectListStorageQuery from 'ee/usage_quotas/storage/namespace/queries/project_list_storage.query.graphql';
import NamespaceStorageApp from '~/usage_quotas/storage/namespace/components/namespace_storage_app.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockSubscriptionPermissionsResponse } from 'ee_jest/usage_quotas/seats/mock_data';

const meta = {
  title: 'ee/usage_quotas/storage/namespace/namespace_storage_app',
  component: NamespaceStorageApp,
};

export default meta;

const GIBIBYTE = 1024 * 1024 * 1024; // bytes in a gibibyte

const createTemplate = (config = {}) => {
  // Apollo
  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    const requestHandlers = [
      [getNamespaceStorageQuery, () => Promise.resolve(mockGetNamespaceStorageGraphQLResponse)],
      [getProjectListStorageQuery, () => Promise.resolve(mockGetProjectListStorageGraphQLResponse)],
    ];
    defaultClient = createMockClient(requestHandlers);
  }
  const customersDotClient = createMockClient([
    [
      getSubscriptionPermissionsData,
      () => Promise.resolve(createMockSubscriptionPermissionsResponse()),
    ],
  ]);
  const apolloProvider = new VueApollo({
    defaultClient,
    clients: { customersDotClient, gitlabClient: defaultClient },
  });

  const { provide = {} } = config;
  return (args, { argTypes }) => ({
    components: { NamespaceStorageApp },
    apolloProvider,
    provide: {
      ...defaultNamespaceProvideValues,
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<namespace-storage-app />',
  });
};

export const SaasWithNamespaceLimits = {
  render: createTemplate(),
};

export const SaasWithNamespaceLimitsLoading = {
  render: (...args) => {
    const apollo = {
      defaultClient: createMockClient([
        [getNamespaceStorageQuery, () => new Promise(() => {})],
        [getProjectListStorageQuery, () => new Promise(() => {})],
      ]),
    };

    return createTemplate({
      apollo,
    })(...args);
  },
};

export const SaasWithProjectLimits = {
  render: createTemplate({
    provide: {
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: true,
      isUsingProjectEnforcementWithNoLimits: false,
      totalRepositorySizeExcess: 3 * GIBIBYTE,
      customSortKey: 'EXCESS_REPO_STORAGE_SIZE_DESC',
    },
  }),
};

export const SaasWithHighProjectLimits = {
  render: createTemplate({
    provide: {
      aboveSizeLimit: true,
      subjectToHighLimit: true,
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: true,
      isUsingProjectEnforcementWithNoLimits: false,
      totalRepositorySizeExcess: 3 * GIBIBYTE,
      customSortKey: 'EXCESS_REPO_STORAGE_SIZE_DESC',
    },
  }),
};

export const SaasWithNoLimits = {
  render: createTemplate({
    provide: {
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: false,
      isUsingProjectEnforcementWithNoLimits: true,
      perProjectStorageLimit: 0,
      namespaceStorageLimit: 0,
    },
  }),
};

export const SaasWithNoLimitsInPreEnforcement = {
  render: createTemplate({
    provide: {
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: false,
      isUsingProjectEnforcementWithNoLimits: true,
      isInNamespaceLimitsPreEnforcement: true,
      totalRepositorySizeExcess: 0,
      namespacePlanStorageIncluded: 0,
    },
  }),
};

export const SaasWithProjectLimitsLoading = {
  render: (...args) => {
    const apollo = {
      defaultClient: createMockClient([
        [getNamespaceStorageQuery, () => new Promise(() => {})],
        [getProjectListStorageQuery, () => new Promise(() => {})],
      ]),
    };

    return createTemplate({
      apollo,
      provide: {
        isUsingNamespaceEnforcement: false,
        isUsingProjectEnforcementWithLimits: true,
        isUsingProjectEnforcementWithNoLimits: false,
        totalRepositorySizeExcess: 3 * GIBIBYTE,
        customSortKey: 'EXCESS_REPO_STORAGE_SIZE_DESC',
      },
    })(...args);
  },
};

export const SaasLoadingError = {
  render: (...args) => {
    const apollo = {
      defaultClient: createMockClient([
        [getNamespaceStorageQuery, () => Promise.reject()],
        [getProjectListStorageQuery, () => Promise.reject()],
      ]),
    };

    return createTemplate({
      apollo,
    })(...args);
  },
};

const selfManagedDefaultProvide = {
  isUsingProjectEnforcementWithLimits: false,
  isUsingProjectEnforcementWithNoLimits: true,
  isUsingNamespaceEnforcement: false,
  namespacePlanName: null,
  perProjectStorageLimit: 0,
  namespaceStorageLimit: 0,
  purchaseStorageUrl: null,
  buyAddonTargetAttr: null,
};

export const SelfManaged = {
  render: createTemplate({
    provide: {
      ...selfManagedDefaultProvide,
    },
  }),
};

export const SelfManagedWithProjectLimits = {
  render: createTemplate({
    provide: {
      ...selfManagedDefaultProvide,
      isUsingProjectEnforcementWithLimits: true,
      isUsingProjectEnforcementWithNoLimits: false,
      perProjectStorageLimit: 10 * GIBIBYTE,
    },
  }),
};

export const SelfManagedLoading = {
  render: (...args) => {
    const apollo = {
      defaultClient: createMockClient([
        [getNamespaceStorageQuery, () => new Promise(() => {})],
        [getProjectListStorageQuery, () => new Promise(() => {})],
      ]),
    };

    return createTemplate({
      apollo,
      provide: {
        ...selfManagedDefaultProvide,
      },
    })(...args);
  },
};
