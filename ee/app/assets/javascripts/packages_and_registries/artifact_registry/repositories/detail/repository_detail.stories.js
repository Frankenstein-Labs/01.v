import createMockApollo from 'helpers/mock_apollo_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import {
  CLIENT_BASE_URL,
  FIRST_PAGE_END_CURSOR,
  ORGANIZATION_GID,
  SLUG,
  mockDetailRepository,
  mockEmptyImagePage,
  mockFirstImagePage,
  mockRepository,
  mockSecondImagePage,
} from 'ee_jest/packages_and_registries/artifact_registry/mock_data';
import {
  possibleTypes,
  typePolicies as artifactRegistryTypePolicies,
} from '../../graphql/cache_config';
import getRepositoryDetailQuery from '../../graphql/queries/get_repository_detail.query.graphql';
import getRepositoryImagesQuery from '../../graphql/queries/get_repository_images.query.graphql';
import getRepositoryPackagesQuery from '../../graphql/queries/get_repository_packages.query.graphql';
import { createRouter } from '../../router';
import RepositoryDetail from './repository_detail.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

// The fields a local resolver answers, each one on its own rather than inside the parent.
const CLIENT_FIELDS = [
  'artifactsCount',
  'createdAt',
  'createdBy',
  'updatedBy',
  'images',
  'packages',
];

export default {
  component: RepositoryDetail,
  title: 'ee/artifact_registry/repositories/detail/repository_detail',
};

const Template =
  (repositoryResolver, artifactResolvers = {}) =>
  () => {
    // The page reads the repository name from the route, so the story navigates to
    // the detail route before rendering.
    const router = createRouter(BASE_PATH);
    router.push(`/${mockRepository.name}`);

    // Resolved once per render, so every read below describes one repository.
    const repository = Promise.resolve().then(repositoryResolver);

    // Each consumer chains a promise of its own off this one, so this keeps the unavailable
    // story's shared rejection from surfacing as an unhandled one.
    repository.catch(() => {});

    const detailHandler = () =>
      repository.then((artifactRegistryRepository) => ({
        data: {
          organization: {
            __typename: 'Organization',
            id: ORGANIZATION_GID,
            artifactRegistryRepository,
          },
        },
      }));

    // The page skips both artifact reads until the detail read has answered, so the row is
    // there to take the format off by the time this runs.
    const artifactRepositoryHandler = ({ name }) =>
      repository.then((row) => ({
        data: {
          organization: {
            __typename: 'Organization',
            id: ORGANIZATION_GID,
            artifactRegistryRepository: {
              __typename: 'ArtifactRegistryRepository',
              name,
              format: row.format,
            },
          },
        },
      }));

    const clientFieldResolvers = Object.fromEntries(
      CLIENT_FIELDS.map((field) => [field, () => repository.then((row) => row?.[field] ?? null)]),
    );

    return {
      components: { RepositoryDetail },
      router,
      apolloProvider: createMockApollo(
        [
          [getRepositoryDetailQuery, detailHandler],
          [getRepositoryImagesQuery, artifactRepositoryHandler],
          [getRepositoryPackagesQuery, artifactRepositoryHandler],
        ],
        { ArtifactRegistryRepository: { ...clientFieldResolvers, ...artifactResolvers } },
        // Keying the type on `name` - which the view's own policies do - merges the detail
        // read's and the artifact read's field sets onto one entity rather than letting the
        // second write replace the first. The mock cache is built from whatever options it is
        // handed rather than from a merge, so the global policies are handed to it alongside.
        {
          possibleTypes,
          typePolicies: { ...globalTypePolicies, ...artifactRegistryTypePolicies },
        },
      ),
      // The kebab composes its copy-URL item from the slug and the client base URL, so both
      // have to be provided or the item does not render.
      provide: { organizationGid: ORGANIZATION_GID, slug: SLUG, clientBaseUrl: CLIENT_BASE_URL },
      template: '<repository-detail />',
    };
  };

export const Default = Template(() => mockDetailRepository());

export const WithoutDescription = Template(() =>
  mockDetailRepository('MAVEN', { description: null }),
);

export const NpmRepository = Template(() => mockDetailRepository('NPM'));

export const ContainerRepository = Template(() => mockDetailRepository('DOCKER'));

export const WithoutAttribution = Template(() =>
  mockDetailRepository('MAVEN', { createdBy: null, updatedBy: null }),
);

export const WithoutLastUpdate = Template(() =>
  mockDetailRepository('MAVEN', {
    downloadsCount: '0',
    sizeBytes: '0',
    artifactsCount: '0',
    lastUpdatedAt: null,
    updatedBy: null,
  }),
);

export const WithoutArtifacts = Template(() =>
  mockDetailRepository('DOCKER', { images: mockEmptyImagePage }),
);

export const ArtifactsUnavailable = Template(() =>
  mockDetailRepository('DOCKER', { images: null }),
);

export const Paginated = Template(() => mockDetailRepository('DOCKER'), {
  images: (_, { after }) =>
    after === FIRST_PAGE_END_CURSOR ? mockSecondImagePage : mockFirstImagePage,
});

export const Loading = Template(() => new Promise(() => {}));

export const ServiceUnavailable = Template(() => Promise.reject(new Error('Unavailable')));

export const NotFound = Template(() => null);
