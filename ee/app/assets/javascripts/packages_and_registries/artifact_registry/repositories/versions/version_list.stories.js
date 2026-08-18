import createMockApollo from 'helpers/mock_apollo_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import {
  ORGANIZATION_GID,
  mockArtifactRepository,
  mockEmptyVersionPage,
  mockRepository,
  mockRepositoryResponse,
} from 'ee_jest/packages_and_registries/artifact_registry/mock_data';
import {
  possibleTypes,
  typePolicies as artifactRegistryTypePolicies,
} from '../../graphql/cache_config';
import { mockArtifacts } from '../../graphql/mock_artifacts';
import { mockResolvers } from '../../graphql/mock_resolvers';
import getArtifactQuery from '../../graphql/queries/get_artifact.query.graphql';
import getArtifactVersionsQuery from '../../graphql/queries/get_artifact_versions.query.graphql';
import { createRouter } from '../../router';
import VersionList from './version_list.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

const repositoryHandler = (format) => () =>
  Promise.resolve(mockRepositoryResponse(mockArtifactRepository(format)));

// The app's own resolvers generate the artifact and its ladder from the name and format the
// repository read answers with, so a story reading through them renders what a browser renders.
// Both package shapes resolve their versions through one function.
const { versions: generatedVersions } = mockResolvers.ArtifactRegistryMavenPackage;

// The artifact the generator holds first, whose id the route below names.
const generatedArtifactId = (format) => mockArtifacts(mockRepository.name, format)[0].id;

export default {
  component: VersionList,
  title: 'ee/artifact_registry/repositories/versions/version_list',
};

const Template =
  ({
    format = 'MAVEN',
    handler = repositoryHandler(format),
    artifactId = generatedArtifactId(format),
    versionsResolver = generatedVersions,
  } = {}) =>
  () => {
    // The page reads the repository name and the artifact id from the route, so the story
    // navigates to the version list route before rendering.
    const router = createRouter(BASE_PATH);
    router.push(`/${mockRepository.name}/${artifactId}`);

    return {
      components: { VersionList },
      router,
      apolloProvider: createMockApollo(
        [
          [getArtifactQuery, handler],
          [getArtifactVersionsQuery, handler],
        ],
        {
          ArtifactRegistryRepository: mockResolvers.ArtifactRegistryRepository,
          ArtifactRegistryMavenPackage: { versions: versionsResolver },
          ArtifactRegistryNpmPackage: { versions: versionsResolver },
        },
        // The mock cache is built from whatever cache options it is handed rather than from a
        // merge, so passing the view's own policies alone would drop every global one.
        {
          possibleTypes,
          typePolicies: { ...globalTypePolicies, ...artifactRegistryTypePolicies },
        },
      ),
      provide: {
        breadCrumbState: { name: '', updateName() {} },
        organizationGid: ORGANIZATION_GID,
      },
      template: '<version-list />',
    };
  };

export const Default = Template();

export const NpmPackage = Template({ format: 'NPM' });

export const DockerImage = Template({ format: 'DOCKER' });

export const OciImage = Template({ format: 'OCI' });

export const Loading = Template({ handler: () => new Promise(() => {}) });

export const ServiceUnavailable = Template({
  handler: () => Promise.reject(new Error('Unavailable')),
});

export const NotFound = Template({
  handler: () => Promise.resolve(mockRepositoryResponse(null)),
});

// An id the generator holds no artifact under, which is where this state comes from in the app.
export const ArtifactNotFound = Template({ artifactId: 'unheld-artifact-id' });

// The generator ladders every package it builds, so none of the three states below is reachable
// through it: each stubs the versions resolver for the state it stands for.
export const WithoutVersions = Template({ versionsResolver: () => mockEmptyVersionPage });

export const VersionsLoading = Template({ versionsResolver: () => new Promise(() => {}) });

export const VersionsUnavailable = Template({
  versionsResolver: () => Promise.reject(new Error('Unavailable')),
});
