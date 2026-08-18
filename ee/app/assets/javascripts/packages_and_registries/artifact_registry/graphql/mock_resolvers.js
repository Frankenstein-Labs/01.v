// Runtime Apollo local resolvers standing in for the parts of the Artifact Registry GraphQL
// surface the schema does not carry yet, so the read and write flows are exercisable in a
// browser ahead of the backend, per doc/development/fe_guide/graphql.md ("Mocking API response
// with local Apollo cache"). The precedent for shipping a runtime mock merged is
// ee/app/assets/javascripts/cd/graphql/mock_resolvers.js.
//
// To remove once the backend ships the remaining types, reads, and mutations:
//   1. delete this file and graphql/typedefs.graphql,
//   2. drop the `mockResolvers`, `typeDefs`, and `possibleTypes` arguments in
//      repositories/index.js, settings/index.js, and setup/index.js,
//   3. remove the remaining `@client` directives from the query and mutation documents.
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { userPath } from '~/lib/utils/path_helpers/user';
import { s__ } from '~/locale';
import {
  TYPENAME_ARTIFACT_REGISTRY,
  TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_REPOSITORY,
} from '../constants';
import { isContainerFormat } from '../utils';
import { mockArtifacts } from './mock_artifacts';

// The handle a claim resolves to, whatever was typed. It has to be the slug the repositories
// route serves - `Organizations::ArtifactRegistry::STUB_SLUG` - or the post-activation redirect
// lands on a 404.
const MOCK_SERVED_HANDLE = 'acme';

const MOCK_CLAIMED_HANDLE = 'taken-handle';

const MOCK_REGISTRY_CREATED_AT = '2026-01-15T09:00:00Z';

const MOCK_REPOSITORY_CREATED_AT = '2026-01-20T09:00:00Z';

// The stand-in holds the condition rather than only answering with it: the settings
// section renders its state and its offered action from a later read of the status.
let mockRegistryStatus = 'active';

const mockRegistry = () => ({
  __typename: TYPENAME_ARTIFACT_REGISTRY,
  handle: MOCK_SERVED_HANDLE,
  status: mockRegistryStatus,
  createdAt: MOCK_REGISTRY_CREATED_AT,
});

// Pauses before resolving, so a consuming view renders its loading state.
const delay = () =>
  new Promise((resolve) => {
    const MOCK_LATENCY_MS = 500;

    setTimeout(resolve, MOCK_LATENCY_MS);
  });

// An Artifact Registry cursor is opaque: a caller may only hand one back (ADR-009). This one
// carries the key of the row it points at, encoded rather than bare so no reader starts reading
// it as a name or an id.
const encodeCursor = (key) => window.btoa(JSON.stringify({ key }));

// A cursor naming a row that has since gone away reads as no cursor at all, so the page fills
// from the unbounded edge rather than coming back empty.
const cursorIndex = (rows, cursor, keyOf) => {
  const index = rows.findIndex((row) => encodeCursor(keyOf(row)) === cursor);

  return index === -1 ? null : index;
};

// `after` names the last row of the page being left and `before` its first, so a forward page
// starts after the one and a backward page ends at the other.
const paginate = (rows, keyOf, pageArguments) => {
  const { first, last, before, after } = pageArguments ?? {};

  const afterIndex = after ? cursorIndex(rows, after, keyOf) : null;
  const beforeIndex = before ? cursorIndex(rows, before, keyOf) : null;

  const windowStart = afterIndex === null ? 0 : afterIndex + 1;
  const windowEnd = beforeIndex === null ? rows.length : beforeIndex;

  const start = last ? Math.max(windowEnd - last, windowStart) : windowStart;
  const end = first ? Math.min(start + first, windowEnd) : windowEnd;
  const nodes = rows.slice(start, end);

  return {
    nodes,
    pageInfo: {
      __typename: 'PageInfo',
      hasPreviousPage: start > 0,
      hasNextPage: end < rows.length,
      startCursor: nodes.length ? encodeCursor(keyOf(nodes[0])) : null,
      endCursor: nodes.length ? encodeCursor(keyOf(nodes.at(-1))) : null,
    },
  };
};

// Every artifact shape carries an id, while only some carry a name.
const artifactKey = ({ id }) => id;

const versionsNewestFirst = (versions) =>
  [...versions].sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt));

const versions = async ({ publishedVersions }, pageArguments) => {
  await delay();

  return {
    __typename: 'ArtifactRegistryVersionConnection',
    ...paginate(versionsNewestFirst(publishedVersions ?? []), artifactKey, pageArguments),
  };
};

const findMockArtifact = (artifacts, id) =>
  artifacts.find((artifact) => artifact.id === id) ?? null;

const mockCurrentUser = () => {
  const { current_user_id: id, current_username: username } = window.gon ?? {};

  if (!id) return null;

  return {
    __typename: 'UserCore',
    id: convertToGraphQLId(TYPENAME_USER, id),
    name: window.gon.current_user_fullname,
    avatarUrl: window.gon.current_user_avatar_url,
    webPath: userPath(username),
  };
};

export const mockResolvers = {
  Organization: {
    artifactRegistry: async () => {
      await delay();

      return mockRegistry();
    },
  },
  [TYPENAME_ARTIFACT_REGISTRY_REPOSITORY]: {
    // `format` is the field the server supplies to tell a container repository from a package
    // one, so gating on it keeps the shape an artifact renders under and the repository it
    // renders against from coming apart.
    images: async ({ name, format }, pageArguments) => {
      if (!isContainerFormat(format)) return null;

      await delay();

      return {
        __typename: 'ArtifactRegistryImageConnection',
        ...paginate(mockArtifacts(name, format), artifactKey, pageArguments),
      };
    },
    packages: async ({ name, format }, pageArguments) => {
      if (isContainerFormat(format)) return null;

      await delay();

      return {
        __typename: 'ArtifactRegistryPackageConnection',
        ...paginate(mockArtifacts(name, format), artifactKey, pageArguments),
      };
    },
    image: async ({ name, format }, { id }) => {
      if (!isContainerFormat(format)) return null;

      await delay();

      return findMockArtifact(mockArtifacts(name, format), id);
    },
    package: async ({ name, format }, { id }) => {
      if (isContainerFormat(format)) return null;

      await delay();

      return findMockArtifact(mockArtifacts(name, format), id);
    },
    // A String, which is what the BigInt scalar the schema carries elsewhere on this type
    // serializes to.
    artifactsCount: ({ name, format }) => String(mockArtifacts(name, format).length),
    createdAt: () => MOCK_REPOSITORY_CREATED_AT,
    createdBy: () => mockCurrentUser(),
    updatedBy: () => mockCurrentUser(),
  },
  [TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE]: { versions },
  [TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE]: { versions },
  Mutation: {
    artifactRegistryActivate: async (_, { input }) => {
      await delay();

      const { handle } = input;

      if (handle === MOCK_CLAIMED_HANDLE) {
        return {
          __typename: 'LocalArtifactRegistryActivatePayload',
          registry: null,
          errors: [s__('ArtifactRegistry|Handle has already been taken.')],
        };
      }

      return {
        __typename: 'LocalArtifactRegistryActivatePayload',
        registry: {
          __typename: TYPENAME_ARTIFACT_REGISTRY,
          handle: MOCK_SERVED_HANDLE,
          status: 'active',
          createdAt: new Date().toISOString(),
        },
        errors: [],
      };
    },
    // Both conditions are idempotent at Artifact Registry, so setting a registry to the
    // condition it already holds succeeds as a no-op rather than erroring.
    artifactRegistryDisable: async () => {
      await delay();

      mockRegistryStatus = 'disabled';

      return {
        __typename: 'LocalArtifactRegistryDisablePayload',
        registry: mockRegistry(),
        errors: [],
      };
    },
    artifactRegistryEnable: async () => {
      await delay();

      mockRegistryStatus = 'active';

      return {
        __typename: 'LocalArtifactRegistryEnablePayload',
        registry: mockRegistry(),
        errors: [],
      };
    },
  },
};
