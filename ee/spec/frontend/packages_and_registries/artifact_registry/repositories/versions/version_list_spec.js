import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import NotFound from 'ee/packages_and_registries/artifact_registry/components/not_found.vue';
import {
  possibleTypes,
  typePolicies as artifactRegistryTypePolicies,
} from 'ee/packages_and_registries/artifact_registry/graphql/cache_config';
import getArtifactQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact.query.graphql';
import getArtifactVersionsQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact_versions.query.graphql';
import FormatLogo from 'ee/packages_and_registries/artifact_registry/repositories/components/format_logo.vue';
import VersionList from 'ee/packages_and_registries/artifact_registry/repositories/versions/version_list.vue';
import VersionsSection from 'ee/packages_and_registries/artifact_registry/repositories/versions/versions_section.vue';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import {
  ARTIFACT_DISPLAY_NAMES,
  ARTIFACT_ID_FOR,
  BASE_PATH,
  ORGANIZATION_GID,
  mockArtifactRepository,
  mockRepositoryArtifacts,
  mockRepositoryResponse,
  createBreadCrumbState,
  mockVersionPage,
  mockVersions,
  resetBreadCrumbState,
} from '../../mock_data';

Vue.use(VueApollo);

const FORMATS = ['MAVEN', 'NPM', 'DOCKER', 'OCI'];

const PACKAGE_FORMATS = ['MAVEN', 'NPM'];

const CONTAINER_FORMATS = ['DOCKER', 'OCI'];

const REPOSITORY_NAME = mockArtifactRepository().name;

describe('ArtifactRegistryVersionList', () => {
  let wrapper;
  let state;

  afterEach(() => {
    resetBreadCrumbState();
  });

  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findNotFound = () => wrapper.findComponent(NotFound);
  const findHeading = () => wrapper.findComponent(PageHeading);
  const findLogo = () => wrapper.findComponent(FormatLogo);
  const findName = () => wrapper.findByTestId('artifact-name');
  const findFormatName = () => wrapper.findByTestId('artifact-format-name');
  const findAnnouncement = () => wrapper.findByTestId('versions-announcement');
  const findVersionsSection = () => wrapper.findComponent(VersionsSection);

  // Echoes the name it was asked for, which makes the repository a read addresses legible.
  const repositoryHandler = (format) =>
    jest.fn(({ name }) => mockRepositoryResponse(mockArtifactRepository(format, { name })));

  // The repository's format decides which of the two fields answers and which is null, so one
  // pair of resolvers covers whichever it holds.
  const artifactResolvers = (format, overrides = {}) => {
    const { image, package: artifactPackage } = {
      ...mockRepositoryArtifacts(format),
      ...overrides,
    };

    return { image: jest.fn(() => image), package: jest.fn(() => artifactPackage) };
  };

  const createComponent = async ({
    format = 'MAVEN',
    handler = repositoryHandler(format),
    resolvers = artifactResolvers(format),
    versionsResolver = jest.fn().mockResolvedValue(mockVersionPage),
    path = `/${REPOSITORY_NAME}/${ARTIFACT_ID_FOR[format]}`,
  } = {}) => {
    state = createBreadCrumbState();

    const router = createRouter(BASE_PATH, state);
    await router.push(path);

    wrapper = shallowMountExtended(VersionList, {
      router,
      apolloProvider: createMockApollo(
        [
          [getArtifactQuery, handler],
          [getArtifactVersionsQuery, handler],
        ],
        {
          ArtifactRegistryRepository: resolvers,
          ArtifactRegistryMavenPackage: { versions: versionsResolver },
          ArtifactRegistryNpmPackage: { versions: versionsResolver },
        },
        // The mock cache is built from whatever options it is handed rather than from a merge,
        // so passing the view's own policies alone would drop every global one.
        {
          possibleTypes,
          typePolicies: { ...globalTypePolicies, ...artifactRegistryTypePolicies },
        },
      ),
      provide: { breadCrumbState: state, organizationGid: ORGANIZATION_GID },
    });

    await nextTick();
  };

  const createResolvedComponent = async (options) => {
    await createComponent(options);
    await waitForPromises();
  };

  it('asks the server for the repository the route names', async () => {
    const handler = repositoryHandler('OCI');

    await createResolvedComponent({
      format: 'OCI',
      handler,
      path: `/payment-core/${ARTIFACT_ID_FOR.OCI}`,
    });

    expect(handler).toHaveBeenCalledWith({
      organizationId: ORGANIZATION_GID,
      name: 'payment-core',
      artifactId: ARTIFACT_ID_FOR.OCI,
    });
  });

  // The format is the schema's answer, so the shape the page renders follows the repository
  // rather than anything the route carried.
  it('reads the artifact off the repository the server resolved', async () => {
    const resolvers = artifactResolvers('NPM');

    await createResolvedComponent({ format: 'NPM', resolvers });

    expect(resolvers.package).toHaveBeenCalledWith(
      { __typename: 'ArtifactRegistryRepository', name: REPOSITORY_NAME, format: 'NPM' },
      { id: ARTIFACT_ID_FOR.NPM },
      expect.anything(),
      expect.anything(),
    );
  });

  describe('while the query is in flight', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders the skeleton rather than the header', () => {
      expect(findSkeleton().exists()).toBe(true);
      expect(findHeading().exists()).toBe(false);
    });

    it('announces that the artifact details are loading', () => {
      expect(findAnnouncement().text()).toBe('Loading artifact details.');
    });
  });

  describe.each(FORMATS)('for a %s artifact', (format) => {
    beforeEach(async () => {
      await createResolvedComponent({ format });
    });

    it('renders the artifact display name', () => {
      expect(findName().text()).toBe(ARTIFACT_DISPLAY_NAMES[format]);
    });

    it('renders the format logo, naming the format for assistive technology', () => {
      expect(findLogo().props('format')).toBe(format);
      expect(findFormatName().exists()).toBe(true);
    });

    it('renders no error, skeleton, or not-found state', () => {
      expect(findAlert().exists()).toBe(false);
      expect(findSkeleton().exists()).toBe(false);
      expect(findNotFound().exists()).toBe(false);
    });

    it('announces the artifact by name, never by its id', () => {
      expect(findAnnouncement().text()).toContain(ARTIFACT_DISPLAY_NAMES[format]);
      expect(findAnnouncement().text()).not.toContain(ARTIFACT_ID_FOR[format]);
    });
  });

  describe.each(PACKAGE_FORMATS)('for a %s artifact', (format) => {
    const createPackageComponent = (options) => createResolvedComponent({ format, ...options });

    it('reads the versions of the artifact the route names', async () => {
      const versionsResolver = jest.fn().mockResolvedValue(mockVersionPage);

      await createPackageComponent({ versionsResolver });

      expect(versionsResolver).toHaveBeenCalled();
    });

    it('renders the versions the read returned', async () => {
      await createPackageComponent();

      expect(findVersionsSection().props()).toMatchObject({
        versions: mockVersions,
        loading: false,
        hasError: false,
      });
    });

    it('announces the version list rather than the artifact once the table has content', async () => {
      await createPackageComponent();

      expect(findAnnouncement().text()).toBe(
        `Version list for ${ARTIFACT_DISPLAY_NAMES[format]} updated.`,
      );
    });

    describe('while the versions are in flight', () => {
      beforeEach(async () => {
        await createPackageComponent({ versionsResolver: () => new Promise(() => {}) });
      });

      it('renders the header with the table region loading', () => {
        expect(findHeading().exists()).toBe(true);
        expect(findVersionsSection().props('loading')).toBe(true);
      });

      it('announces that the versions are loading', () => {
        expect(findAnnouncement().text()).toBe('Loading versions.');
      });
    });

    describe.each`
      scenario                      | versionsResolver
      ${'the read fails'}           | ${() => Promise.reject(new Error('Unavailable'))}
      ${'the service returns null'} | ${() => null}
    `('when $scenario', ({ versionsResolver }) => {
      beforeEach(async () => {
        await createPackageComponent({ versionsResolver });
      });

      it('reports the failure in the table region, keeping the header rendered', () => {
        expect(findVersionsSection().props('hasError')).toBe(true);
        expect(findHeading().exists()).toBe(true);
      });

      it('announces the failure', () => {
        expect(findAnnouncement().text()).toBe('The Artifact Registry service is unavailable.');
      });
    });
  });

  describe.each(CONTAINER_FORMATS)('for a %s artifact', (format) => {
    let versionsResolver;

    beforeEach(async () => {
      versionsResolver = jest.fn().mockResolvedValue(mockVersionPage);

      await createResolvedComponent({ format, versionsResolver });
    });

    it('reads no versions and renders no table region', () => {
      expect(versionsResolver).not.toHaveBeenCalled();
      expect(findVersionsSection().exists()).toBe(false);
    });

    it('announces the artifact rather than leaving a version list loading forever', () => {
      expect(findAnnouncement().text()).toBe(
        `Artifact details for ${ARTIFACT_DISPLAY_NAMES[format]} loaded.`,
      );
    });
  });

  // A repository Artifact Registry does not hold and an artifact it holds nothing under render
  // one outcome, so the page never confirms that either exists.
  describe('when the repository is gone', () => {
    let resolvers;

    beforeEach(async () => {
      resolvers = artifactResolvers('MAVEN');

      await createResolvedComponent({
        handler: jest.fn(() => mockRepositoryResponse(null)),
        resolvers,
      });
    });

    it('renders the not-found state alone', () => {
      expect(findNotFound().exists()).toBe(true);
      expect(findHeading().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });

    it('announces the not-found state rather than an artifact with no name', () => {
      expect(findAnnouncement().text()).toBe('Page not found');
    });

    it('reads no artifact off it', () => {
      expect(resolvers.image).not.toHaveBeenCalled();
      expect(resolvers.package).not.toHaveBeenCalled();
    });
  });

  describe('when the artifact is gone', () => {
    beforeEach(async () => {
      await createResolvedComponent({
        resolvers: artifactResolvers('MAVEN', { image: null, package: null }),
      });
    });

    it('renders the not-found state alone', () => {
      expect(findNotFound().exists()).toBe(true);
      expect(findHeading().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });

    it('announces the not-found state rather than an artifact with no name', () => {
      expect(findAnnouncement().text()).toBe('Page not found');
    });
  });

  describe('when the read fails', () => {
    beforeEach(async () => {
      await createResolvedComponent({
        handler: jest.fn().mockRejectedValue(new Error('Unavailable')),
      });
    });

    it('renders the service-unavailable alert rather than the not-found state', () => {
      expect(findAlert().text()).toBe('The Artifact Registry service is unavailable.');
      expect(findNotFound().exists()).toBe(false);
    });

    it('announces the failure', () => {
      expect(findAnnouncement().text()).toBe('The Artifact Registry service is unavailable.');
    });
  });
});
