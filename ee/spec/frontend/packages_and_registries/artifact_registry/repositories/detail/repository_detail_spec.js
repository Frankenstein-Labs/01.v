import { GlAlert, GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import { isUndefined, omitBy } from 'lodash-es';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import detailFixture from 'test_fixtures/ee/graphql/packages_and_registries/artifact_registry/graphql/queries/get_repository_detail.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import NotFound from 'ee/packages_and_registries/artifact_registry/components/not_found.vue';
import { GRAPHQL_PAGE_SIZE } from 'ee/packages_and_registries/artifact_registry/constants';
import {
  possibleTypes,
  typePolicies as artifactRegistryTypePolicies,
} from 'ee/packages_and_registries/artifact_registry/graphql/cache_config';
import getRepositoryDetailQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_detail.query.graphql';
import getRepositoryImagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_images.query.graphql';
import getRepositoryPackagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_packages.query.graphql';
import ArtifactsSection from 'ee/packages_and_registries/artifact_registry/repositories/detail/artifacts_section.vue';
import RepositoryDetail from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_detail.vue';
import RepositoryHeader from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_header.vue';
import RepositorySidebar from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_sidebar.vue';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import {
  BASE_PATH,
  FIRST_PAGE_END_CURSOR,
  ORGANIZATION_GID,
  SECOND_PAGE_START_CURSOR,
  mockEmptyImagePage,
  mockFirstImagePage,
  mockImagePage,
  mockMavenPackagePage,
  mockNpmPackagePage,
  mockRepository,
  mockSecondImagePage,
  mockUser,
} from '../../mock_data';

Vue.use(VueApollo);

const REPOSITORY_NAME = mockRepository.name;

// From the generated fixture rather than a transcription of it, so a change to the schema's
// field set fails here rather than drifting. The format is overridden per example, because it
// decides which artifact connection the page then reads.
const serverRepository = (format = 'MAVEN') => ({
  ...detailFixture.data.organization.artifactRegistryRepository,
  format,
});

// Answered by a local resolver each, rather than arriving inside the parent.
const LOCAL_FIELDS = {
  artifactsCount: '3',
  createdAt: '2026-05-12T09:24:00Z',
  createdBy: mockUser,
  updatedBy: mockUser,
};

const localFieldResolvers = Object.fromEntries(
  Object.entries(LOCAL_FIELDS).map(([field, value]) => [field, () => value]),
);

const renderedRepository = (format = 'MAVEN') => ({ ...serverRepository(format), ...LOCAL_FIELDS });

const organizationResponse = (repository) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: ORGANIZATION_GID,
      artifactRegistryRepository: repository,
    },
  },
});

// A container repository reads `images` and every other format reads `packages`, so exactly one
// of the two is ever in the document and one resolver stands in for both.
const ARTIFACT_CONNECTION = {
  DOCKER: mockImagePage,
  OCI: mockImagePage,
  MAVEN: mockMavenPackagePage,
  NPM: mockNpmPackagePage,
};

// Echoes the name it was asked for, which makes the repository a read addresses legible.
const artifactRepositoryHandler = (format) =>
  jest.fn(({ name }) =>
    organizationResponse({ __typename: 'ArtifactRegistryRepository', name, format }),
  );

describe('ArtifactRegistryRepositoryDetail', () => {
  let wrapper;
  let router;

  const findHeaderSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findNotFound = () => wrapper.findComponent(NotFound);
  const findHeader = () => wrapper.findComponent(RepositoryHeader);
  const findMainColumn = () => wrapper.findByTestId('repository-detail-main');
  const findSidebar = () => wrapper.findByTestId('repository-detail-sidebar');
  const findArtifactsSection = () => wrapper.findComponent(ArtifactsSection);
  const findSidebarComponent = () => wrapper.findComponent(RepositorySidebar);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findAnnouncement = () => wrapper.findByTestId('artifacts-announcement');

  // A variable the page leaves out arrives as an absent key, and one it passes as undefined as
  // a key holding undefined. Dropping those makes both comparable whole, so an unexpected
  // variable or argument fails rather than passing a partial match.
  const lastQueryVariables = (handler) => omitBy(handler.mock.calls.at(-1)[0], isUndefined);

  const lastPageArguments = (resolver) => omitBy(resolver.mock.calls.at(-1)[1], isUndefined);

  const createComponent = async ({
    format = 'MAVEN',
    connection = ARTIFACT_CONNECTION[format],
    detailHandler = jest.fn().mockResolvedValue(organizationResponse(serverRepository(format))),
    artifactHandler = artifactRepositoryHandler(format),
    connectionResolver = jest.fn(() => connection),
    path = `/${REPOSITORY_NAME}`,
    query = {},
  } = {}) => {
    router = createRouter(BASE_PATH);
    await router.push({ path, query });

    wrapper = shallowMountExtended(RepositoryDetail, {
      router,
      apolloProvider: createMockApollo(
        [
          [getRepositoryDetailQuery, detailHandler],
          [getRepositoryImagesQuery, artifactHandler],
          [getRepositoryPackagesQuery, artifactHandler],
        ],
        {
          ArtifactRegistryRepository: {
            ...localFieldResolvers,
            images: connectionResolver,
            packages: connectionResolver,
          },
        },
        // The mock cache is built from whatever options it is handed rather than from a merge,
        // so passing the view's own policies alone would drop every global one. Handing it the
        // view's connection policy puts the cursor-agnostic cache key under test.
        {
          possibleTypes,
          typePolicies: { ...globalTypePolicies, ...artifactRegistryTypePolicies },
        },
      ),
      provide: { organizationGid: ORGANIZATION_GID },
    });

    await nextTick();
  };

  const createResolvedComponent = async (options) => {
    await createComponent(options);
    await waitForPromises();
  };

  it('reads the repository the route names, so a shared URL opens that repository', async () => {
    const detailHandler = jest
      .fn()
      .mockResolvedValue(organizationResponse(serverRepository('MAVEN')));

    await createResolvedComponent({ detailHandler, path: '/payment-core' });

    expect(lastQueryVariables(detailHandler)).toStrictEqual({
      organizationId: ORGANIZATION_GID,
      name: 'payment-core',
    });
  });

  describe('while the detail query is in flight', () => {
    beforeEach(async () => {
      await createComponent({ detailHandler: jest.fn().mockReturnValue(new Promise(() => {})) });
    });

    it('renders the header skeleton, so the page reads as the shape it is about to be', () => {
      expect(findHeaderSkeleton().exists()).toBe(true);
    });

    it('renders no header, because there is nothing yet to name the repository with', () => {
      expect(findHeader().exists()).toBe(false);
    });

    it('renders neither page region, so an in-flight query is not mistaken for a result', () => {
      expect(findMainColumn().exists()).toBe(false);
      expect(findSidebar().exists()).toBe(false);
    });

    it('renders neither the not-found state nor an error', () => {
      expect(findNotFound().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when the repository loads', () => {
    beforeEach(async () => {
      await createResolvedComponent();
    });

    it('lays out the main column and the sidebar the page regions fill', () => {
      expect(findMainColumn().exists()).toBe(true);
      expect(findSidebar().exists()).toBe(true);
    });

    // Deep-equal rather than a subset, so a field the server stopped sending or a local field
    // left unresolved fails here rather than rendering as blank.
    it('hands the header the server-resolved repository with the four local fields on it', () => {
      expect(findHeader().props('repository')).toEqual(renderedRepository());
    });

    it('hands the sidebar the same repository, so the two cannot disagree', () => {
      expect(findSidebarComponent().props('repository')).toEqual(renderedRepository());
    });

    it('renders the sidebar inside the sidebar column, not loose on the page', () => {
      expect(findSidebar().findComponent(RepositorySidebar).exists()).toBe(true);
    });

    it('names the sidebar landmark', () => {
      expect(findSidebar().attributes('aria-label')).toBe('Repository details');
    });

    it('renders no loading affordance, not-found state, or error', () => {
      expect(findHeaderSkeleton().exists()).toBe(false);
      expect(findNotFound().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });

    it('renders the artifacts section in the main column, not loose on the page', () => {
      expect(findMainColumn().findComponent(ArtifactsSection).exists()).toBe(true);
    });
  });

  describe('the artifact connection', () => {
    it.each([
      ['DOCKER', () => mockImagePage.nodes],
      ['OCI', () => mockImagePage.nodes],
      ['MAVEN', () => mockMavenPackagePage.nodes],
      ['NPM', () => mockNpmPackagePage.nodes],
    ])('hands the section a %s repository’s own artifacts', async (format, expectedNodes) => {
      await createResolvedComponent({ format });

      expect(findArtifactsSection().props()).toEqual({
        name: REPOSITORY_NAME,
        format,
        artifacts: expectedNodes(),
        loading: false,
        hasError: false,
      });
    });

    it('passes a null connection down without taking the whole page with it', async () => {
      await createResolvedComponent({ format: 'DOCKER', connection: null });

      expect(findArtifactsSection().props()).toMatchObject({ hasError: true, loading: false });
      expect(findHeader().exists()).toBe(true);
      expect(findSidebar().exists()).toBe(true);
      expect(findAlert().exists()).toBe(false);
    });

    it('asks the server for the repository the route names, so the page addresses one throughout', async () => {
      const artifactHandler = artifactRepositoryHandler('MAVEN');

      await createResolvedComponent({ artifactHandler, path: '/payment-core' });

      expect(lastQueryVariables(artifactHandler)).toStrictEqual({
        organizationId: ORGANIZATION_GID,
        name: 'payment-core',
        first: GRAPHQL_PAGE_SIZE,
      });
    });

    it('stops loading when the artifact read fails outright', async () => {
      await createResolvedComponent({
        connectionResolver: jest.fn().mockRejectedValue(new Error('Artifact Registry is down')),
      });

      expect(findArtifactsSection().props()).toMatchObject({ hasError: true, loading: false });
      expect(findHeader().exists()).toBe(true);
      expect(findSidebar().exists()).toBe(true);
    });
  });

  // The document to issue follows the repository's format, so reading before the format has
  // landed would issue the packages document for a container repository and then swap it.
  describe('before the repository has resolved', () => {
    it('issues no artifact read while the repository read is still in flight', async () => {
      const artifactHandler = artifactRepositoryHandler('MAVEN');

      await createResolvedComponent({
        artifactHandler,
        detailHandler: jest.fn().mockReturnValue(new Promise(() => {})),
      });

      expect(artifactHandler).not.toHaveBeenCalled();
    });

    it('issues no artifact read for a repository that resolved null', async () => {
      const artifactHandler = artifactRepositoryHandler('MAVEN');

      await createResolvedComponent({
        artifactHandler,
        detailHandler: jest.fn().mockResolvedValue(organizationResponse(null)),
      });

      expect(artifactHandler).not.toHaveBeenCalled();
    });

    it('reads a container repository once, on the document its format names', async () => {
      const artifactHandler = artifactRepositoryHandler('DOCKER');

      await createResolvedComponent({ format: 'DOCKER', artifactHandler });

      expect(artifactHandler).toHaveBeenCalledTimes(1);
      expect(findArtifactsSection().props('artifacts')).toEqual(mockImagePage.nodes);
    });
  });

  describe('when the artifact connection comes back empty', () => {
    beforeEach(async () => {
      await createResolvedComponent({
        format: 'DOCKER',
        connection: mockEmptyImagePage,
      });
    });

    it('hides the sidebar stats even though the buffered count says otherwise', () => {
      expect(findSidebarComponent().props('repository').artifactsCount).not.toBe('0');
      expect(findSidebarComponent().props('hideStats')).toBe(true);
    });

    it('keeps the sidebar itself, which still carries the timestamps', () => {
      expect(findSidebar().exists()).toBe(true);
    });

    it('hands the section an empty page, so it shows the empty state', () => {
      expect(findArtifactsSection().props()).toMatchObject({
        artifacts: [],
        loading: false,
        hasError: false,
      });
    });
  });

  describe('the artifact pager', () => {
    // The request after the first page's end cursor answers the second page; every other
    // request answers the first, including the walk back from the second page's start cursor.
    const pagedConnectionResolver = () =>
      jest.fn((_, { after }) =>
        after === FIRST_PAGE_END_CURSOR ? mockSecondImagePage : mockFirstImagePage,
      );

    const pagedComponent = (options = {}) =>
      createResolvedComponent({
        format: 'DOCKER',
        connectionResolver: pagedConnectionResolver(),
        ...options,
      });

    const renderedNames = () =>
      findArtifactsSection()
        .props('artifacts')
        .map(({ name }) => name);

    const namesOf = ({ nodes }) => nodes.map(({ name }) => name);

    const pageTo = async (query) => {
      await router.push({ query });
      await waitForPromises();
    };

    it('drives the pager from the page info the connection returns', async () => {
      await pagedComponent();

      expect(findPagination().props()).toMatchObject({
        hasNextPage: true,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: FIRST_PAGE_END_CURSOR,
      });
    });

    it('hands the pager no page either way for a single-page connection, which hides it', async () => {
      await createResolvedComponent({ format: 'DOCKER', connection: mockImagePage });

      expect(findPagination().props()).toMatchObject({
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('renders the pager below the artifact section, inside the main column', async () => {
      await pagedComponent();

      expect(findMainColumn().findComponent(GlKeysetPagination).exists()).toBe(true);
    });

    it('writes the end cursor to the route query, so a page is shareable and survives a reload', async () => {
      await pagedComponent();

      findPagination().vm.$emit('next', FIRST_PAGE_END_CURSOR);
      await waitForPromises();

      expect(router.currentRoute.query).toEqual({ after: FIRST_PAGE_END_CURSOR });
    });

    it('clears the cursor pointing the other way, so the page just asked for is the one read', async () => {
      await pagedComponent();
      await pageTo({ after: FIRST_PAGE_END_CURSOR });

      findPagination().vm.$emit('prev', SECOND_PAGE_START_CURSOR);
      await waitForPromises();

      expect(router.currentRoute.query).toEqual({ before: SECOND_PAGE_START_CURSOR });
    });

    it('leaves query parameters it does not own alone', async () => {
      await pagedComponent({ query: { search: 'payment' } });

      findPagination().vm.$emit('next', FIRST_PAGE_END_CURSOR);
      await waitForPromises();

      expect(router.currentRoute.query).toEqual({
        search: 'payment',
        after: FIRST_PAGE_END_CURSOR,
      });
    });

    // The connection is the field that pages, so the requested page is observable on its
    // resolver rather than on the query variables a handler sees.
    it.each`
      page          | query                                   | pageArguments
      ${'first'}    | ${{}}                                   | ${{ first: GRAPHQL_PAGE_SIZE }}
      ${'next'}     | ${{ after: FIRST_PAGE_END_CURSOR }}     | ${{ first: GRAPHQL_PAGE_SIZE, after: FIRST_PAGE_END_CURSOR }}
      ${'previous'} | ${{ before: SECOND_PAGE_START_CURSOR }} | ${{ last: GRAPHQL_PAGE_SIZE, before: SECOND_PAGE_START_CURSOR }}
    `(
      'asks the connection for the $page page the route query names',
      async ({ query, pageArguments }) => {
        const connectionResolver = pagedConnectionResolver();

        await pagedComponent({ connectionResolver, query });

        expect(lastPageArguments(connectionResolver)).toStrictEqual(pageArguments);
      },
    );

    describe('paging forward', () => {
      beforeEach(async () => {
        await pagedComponent();
        await pageTo({ after: FIRST_PAGE_END_CURSOR });
      });

      it('renders the next page alone, so a page replaces the previous one rather than extending it', () => {
        expect(renderedNames()).toEqual(namesOf(mockSecondImagePage));
      });
    });

    describe('paging back', () => {
      beforeEach(async () => {
        await pagedComponent();
        await pageTo({ after: FIRST_PAGE_END_CURSOR });
        await pageTo({ before: SECOND_PAGE_START_CURSOR });
      });

      it('renders the first page again', () => {
        expect(renderedNames()).toEqual(namesOf(mockFirstImagePage));
      });
    });

    describe('returning to a cursor already visited', () => {
      beforeEach(async () => {
        await pagedComponent();
        await pageTo({ after: FIRST_PAGE_END_CURSOR });
        await pageTo({ before: SECOND_PAGE_START_CURSOR });
        await pageTo({ after: FIRST_PAGE_END_CURSOR });
      });

      it('renders the second page rather than the entry the cursor already held', () => {
        expect(renderedNames()).toEqual(namesOf(mockSecondImagePage));
      });
    });
  });

  describe('the artifact live region', () => {
    it('announces the page once it has arrived', async () => {
      await createResolvedComponent();

      expect(findAnnouncement().text()).toBe('Artifact list updated.');
    });

    it('is polite and read whole, so a page change does not interrupt mid-sentence', async () => {
      await createResolvedComponent();

      expect(findAnnouncement().attributes()).toMatchObject({
        'aria-live': 'polite',
        'aria-atomic': 'true',
      });
    });

    it('announces again on a page change, so an unchanged message still reaches a reader', async () => {
      await createResolvedComponent({
        format: 'DOCKER',
        connectionResolver: jest.fn((_, { after }) =>
          after ? mockSecondImagePage : mockFirstImagePage,
        ),
      });

      expect(findAnnouncement().text()).toBe('Artifact list updated.');

      await router.push({ query: { after: FIRST_PAGE_END_CURSOR } });
      await nextTick();

      // A live region reads what changed, so a page landing in the same result state
      // needs the message to leave before it comes back.
      expect(findAnnouncement().text()).not.toBe('Artifact list updated.');

      await waitForPromises();

      expect(findAnnouncement().text()).toBe('Artifact list updated.');
    });

    it('says the artifacts are loading before the first page arrives', async () => {
      await createComponent();

      expect(findAnnouncement().text()).toBe('Loading artifacts.');
    });
  });

  describe('when the sidebar stats stay', () => {
    it('shows them for a populated repository', async () => {
      await createResolvedComponent();

      expect(findSidebarComponent().props('hideStats')).toBe(false);
    });

    it('shows them when the connection failed, which says nothing about the counts', async () => {
      await createResolvedComponent({ format: 'DOCKER', connection: null });

      expect(findSidebarComponent().props('hideStats')).toBe(false);
    });

    it('shows them while the connection is still in flight, so they do not flash away on load', async () => {
      await createResolvedComponent({
        connectionResolver: jest.fn().mockReturnValue(new Promise(() => {})),
      });

      expect(findArtifactsSection().props('loading')).toBe(true);
      expect(findSidebarComponent().props('hideStats')).toBe(false);
    });
  });

  // The read resolves null both for a repository that does not exist and for one the viewer may
  // not see, so the view has one outcome to render and never tells the two apart.
  describe('when the repository resolves null', () => {
    beforeEach(async () => {
      await createResolvedComponent({
        detailHandler: jest.fn().mockResolvedValue(organizationResponse(null)),
      });
    });

    it('renders the not-found state', () => {
      expect(findNotFound().exists()).toBe(true);
    });

    it('renders neither page region, so the view never confirms the repository exists', () => {
      expect(findMainColumn().exists()).toBe(false);
      expect(findSidebar().exists()).toBe(false);
    });

    it('renders no error, because nothing failed', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when the detail query fails', () => {
    beforeEach(async () => {
      await createResolvedComponent({
        detailHandler: jest.fn().mockRejectedValue(new Error('Artifact Registry is down')),
      });
    });

    it('renders the service-unavailable alert', () => {
      expect(findAlert().text()).toBe('The Artifact Registry service is unavailable.');
    });

    it('renders no not-found state, because a failed read is not a missing repository', () => {
      expect(findNotFound().exists()).toBe(false);
    });

    it('renders neither page region', () => {
      expect(findMainColumn().exists()).toBe(false);
      expect(findSidebar().exists()).toBe(false);
    });
  });

  // The keyset pager holds its cursor in the route query, which re-runs this same document on
  // the mounted component, so a failed page followed by browser Back would otherwise leave
  // the alert over a page that loaded.
  describe('when a failed read is followed by a successful one', () => {
    it('renders the repository, so a recovered read is not hidden behind the old error', async () => {
      const detailHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('Artifact Registry is down'))
        .mockResolvedValue(organizationResponse(serverRepository('MAVEN')));

      await createResolvedComponent({ detailHandler, path: '/payment-core' });

      expect(findAlert().exists()).toBe(true);

      await router.push(`/${REPOSITORY_NAME}`);
      await waitForPromises();

      expect(findAlert().exists()).toBe(false);
      expect(findMainColumn().exists()).toBe(true);
      expect(findSidebar().exists()).toBe(true);
    });
  });

  describe('when a failed artifact read is followed by a successful one', () => {
    it('renders the artifacts, so a recovered read is not hidden behind the old error', async () => {
      const connectionResolver = jest
        .fn()
        .mockRejectedValueOnce(new Error('Artifact Registry is down'))
        .mockReturnValue(mockMavenPackagePage);

      await createResolvedComponent({ connectionResolver, path: '/payment-core' });

      expect(findArtifactsSection().props('hasError')).toBe(true);

      await router.push(`/${REPOSITORY_NAME}`);
      await waitForPromises();

      expect(findArtifactsSection().props()).toMatchObject({
        artifacts: mockMavenPackagePage.nodes,
        loading: false,
        hasError: false,
      });
    });
  });
});
