import {
  TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_REPOSITORY,
  TYPENAME_ORGANIZATION,
} from '../constants';

export const possibleTypes = {
  [TYPENAME_ARTIFACT_REGISTRY_PACKAGE]: [
    TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
    TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
  ],
};

const ARTIFACT_CONNECTION_POLICY = {
  keyArgs: [],
  merge: (_, incoming) => incoming,
};

// The Artifact Registry repository type carries no `id` — AR addresses a repository
// by name, and ADR-009 makes the name unique within the namespace and immutable — so
// the cache keys on `name`. That is what lets a post-update mutation patch a
// repository in place.
export const typePolicies = {
  [TYPENAME_ARTIFACT_REGISTRY_REPOSITORY]: {
    keyFields: ['name'],
    fields: {
      images: ARTIFACT_CONNECTION_POLICY,
      packages: ARTIFACT_CONNECTION_POLICY,
    },
  },
  [TYPENAME_ORGANIZATION]: {
    fields: {
      // The filters and the sort are applied server-side, so each combination is a
      // distinct result rather than a view of one cached list. Without keying on them, a
      // re-sorted page overwrites the entry another one wrote.
      artifactRegistryRepositories: {
        keyArgs: ['format', 'kind', 'sort'],
      },
    },
  },
};
