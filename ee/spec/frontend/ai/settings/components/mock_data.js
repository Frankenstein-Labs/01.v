import allowedPopulatedFixture from 'test_fixtures/graphql/ai/domain_settings/allowed_populated.json';
import allowedEmptyFixture from 'test_fixtures/graphql/ai/domain_settings/allowed_empty.json';
import allowedPaginatedFixture from 'test_fixtures/graphql/ai/domain_settings/allowed_paginated.json';

export { allowedPopulatedFixture, allowedEmptyFixture, allowedPaginatedFixture };

export const instanceMutationAddSuccess = {
  data: {
    aiDomainSettingsInstanceUpdate: {
      addedDomains: ['new-domain.com'],
      removedDomains: null,
      errors: [],
    },
  },
};

export const instanceMutationRemoveSuccess = {
  data: {
    aiDomainSettingsInstanceUpdate: {
      addedDomains: null,
      removedDomains: ['example.com'],
      errors: [],
    },
  },
};

export const namespaceMutationAddSuccess = {
  data: {
    aiDomainSettingsNamespaceUpdate: {
      addedDomains: ['new-domain.com'],
      removedDomains: null,
      errors: [],
    },
  },
};

export const namespaceMutationRemoveSuccess = {
  data: {
    aiDomainSettingsNamespaceUpdate: {
      addedDomains: null,
      removedDomains: ['example.com'],
      errors: [],
    },
  },
};

export const instanceMutationErrorResponse = {
  data: {
    aiDomainSettingsInstanceUpdate: {
      addedDomains: null,
      removedDomains: null,
      errors: ['evil.com is not a valid domain'],
    },
  },
};

export const namespaceMutationErrorResponse = {
  data: {
    aiDomainSettingsNamespaceUpdate: {
      addedDomains: null,
      removedDomains: null,
      errors: ['evil.com is not a valid domain'],
    },
  },
};

export const groupAllowedPopulatedFixture = {
  data: {
    namespace: {
      id: 'gid://gitlab/Namespace/42',
      aiDomainSettings: {
        nodes: ['example.com', 'gitlab.com'],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const errorResponse = new Error('GraphQL error');
