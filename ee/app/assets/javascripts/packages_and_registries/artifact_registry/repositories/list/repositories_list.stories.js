import createMockApollo from 'helpers/mock_apollo_helper';
import {
  CLIENT_BASE_URL,
  FIRST_PAGE_END_CURSOR,
  ORGANIZATION_GID,
  SECOND_PAGE_START_CURSOR,
  SLUG,
  mockEmptyRepositoryPage,
  mockRepositories,
  mockRepositoriesResponse,
  mockRepositoryPage,
} from 'ee_jest/packages_and_registries/artifact_registry/mock_data';
import getRepositoriesQuery from '../../graphql/queries/get_repositories.query.graphql';
import { createRouter } from '../../router';
import RepositoriesList from './repositories_list.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

// A pair of single-row pages, so which page is rendered is legible from the row itself.
const mockFirstRepositoryPage = {
  ...mockRepositoryPage,
  nodes: [mockRepositories[0]],
  pageInfo: { ...mockRepositoryPage.pageInfo, hasNextPage: true, endCursor: FIRST_PAGE_END_CURSOR },
};

const mockSecondRepositoryPage = {
  ...mockRepositoryPage,
  nodes: [mockRepositories[1]],
  pageInfo: {
    ...mockRepositoryPage.pageInfo,
    hasPreviousPage: true,
    startCursor: SECOND_PAGE_START_CURSOR,
  },
};

const respondWith = (connection) => () => Promise.resolve(mockRepositoriesResponse(connection));

export default {
  component: RepositoriesList,
  title: 'ee/artifact_registry/repositories/list/repositories_list',
};

// The page reads its filter selection from the route query, so the router is seeded with the
// story's. Seeding an empty query would push the route the router already holds, which
// vue-router rejects as a duplicate navigation.
function createStoryRouter(query) {
  const router = createRouter(BASE_PATH);

  if (query) {
    router.push({ path: '/', query });
  }

  return router;
}

function Template(repositoriesHandler, query = null) {
  return () => ({
    components: { RepositoriesList },
    router: createStoryRouter(query),
    apolloProvider: createMockApollo([[getRepositoriesQuery, repositoriesHandler]]),
    provide: { organizationGid: ORGANIZATION_GID, slug: SLUG, clientBaseUrl: CLIENT_BASE_URL },
    template: '<repositories-list />',
  });
}

export const Default = Template(respondWith(mockRepositoryPage));

export const Empty = Template(respondWith(mockEmptyRepositoryPage));

export const ZeroResult = Template(respondWith(mockEmptyRepositoryPage), { format: 'npm' });

// A non-default sort, so the accessibility run covers a header carrying an active sort.
export const Sorted = Template(respondWith(mockRepositoryPage), { sort: 'name_asc' });

export const Loading = Template(() => new Promise(() => {}));

export const ServiceUnavailable = Template(() => Promise.reject(new Error('Unavailable')));

export const NotFound = Template(respondWith(null));

// The request after the first page's end cursor answers the second page; every other request
// answers the first, so the pager is operable rather than only rendered.
export const Paginated = Template(({ after }) =>
  Promise.resolve(
    mockRepositoriesResponse(
      after === FIRST_PAGE_END_CURSOR ? mockSecondRepositoryPage : mockFirstRepositoryPage,
    ),
  ),
);
