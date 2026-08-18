import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlFilteredSearch, GlKeysetPagination } from '@gitlab/ui';
import mavenUpstreamCacheEntriesCountFixture from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries_count.query.graphql.json';
import mavenUpstreamCacheEntriesFixture from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { deleteMavenUpstreamCacheEntry } from 'ee/api/virtual_registries_api';
import getMavenUpstreamCacheEntriesCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries_count.query.graphql';
import getMavenUpstreamCacheEntriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries.query.graphql';
import getUpstreamSummaryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstream_summary.query.graphql';
import deleteContainerCacheEntryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_cache_entry.mutation.graphql';
import UpstreamDetailsApp from 'ee/packages_and_registries/virtual_registries/pages/common/upstream/show.vue';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/show/header.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/show/cache_entries_table.vue';
import { createAlert } from '~/alert';
import * as urlUtils from '~/lib/utils/url_utility';
import { TEST_HOST } from 'spec/test_constants';
import { mockUpstream } from '../../../mock_data';

jest.mock('~/alert');
jest.mock('ee/api/virtual_registries_api', () => ({
  deleteMavenUpstreamCacheEntry: jest.fn(),
}));

Vue.use(VueApollo);

describe('UpstreamShow', () => {
  let wrapper;

  const defaultProvide = {
    initialUpstream: mockUpstream,
    getUpstreamCacheEntriesCountQuery: getMavenUpstreamCacheEntriesCountQuery,
    getUpstreamCacheEntriesQuery: getMavenUpstreamCacheEntriesQuery,
    i18n: {
      registryType: 'Maven',
    },
    ids: {
      baseUpstream: 'VirtualRegistries::Packages::Maven::Upstream',
    },
  };

  const upstreamId = `gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/${mockUpstream.id}`;
  const mockCacheEntries = mavenUpstreamCacheEntriesFixture.data.upstream.cacheEntries.nodes;
  const [mockCacheEntry] = mockCacheEntries;
  const mockPageInfo = mavenUpstreamCacheEntriesFixture.data.upstream.cacheEntries.pageInfo;

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findTable = () => wrapper.findComponent(CacheEntriesTable);
  const findHeader = () => wrapper.findComponent(UpstreamDetailsHeader);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const mavenUpstreamCacheEntriesQueryResolver = jest
    .fn()
    .mockResolvedValue(mavenUpstreamCacheEntriesFixture);
  const mavenUpstreamCacheEntriesCountQueryResolver = jest
    .fn()
    .mockResolvedValue(mavenUpstreamCacheEntriesCountFixture);
  const deleteContainerCacheEntryMutationResolver = jest
    .fn()
    .mockResolvedValue({ data: { delete: { errors: [] } } });

  const createComponent = ({
    handlers = [
      [getMavenUpstreamCacheEntriesQuery, mavenUpstreamCacheEntriesQueryResolver],
      [getMavenUpstreamCacheEntriesCountQuery, mavenUpstreamCacheEntriesCountQueryResolver],
    ],
    provide = {},
    propsData = {},
  } = {}) => {
    wrapper = shallowMountExtended(UpstreamDetailsApp, {
      apolloProvider: createMockApollo(handlers),
      propsData,
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  beforeEach(() => {
    deleteMavenUpstreamCacheEntry.mockReset();
  });

  describe('initial loading', () => {
    it('passes loading state to header and table', async () => {
      createComponent();

      await nextTick();

      expect(findHeader().props('loading')).toBe(true);
      expect(findTable().props('loading')).toBe(true);
    });

    describe('when URL params exist', () => {
      it.each`
        params                              | expectedEntriesArgs                                                   | expectedCountArgs
        ${'?search=foo'}                    | ${{ id: upstreamId, search: 'foo', first: 20 }}                       | ${{ id: upstreamId }}
        ${'?search=foo&after=some_cursor'}  | ${{ id: upstreamId, search: 'foo', after: 'some_cursor', first: 20 }} | ${{ id: upstreamId }}
        ${'?search=foo&before=some_cursor'} | ${{ id: upstreamId, search: 'foo', before: 'some_cursor', last: 20 }} | ${{ id: upstreamId }}
        ${'?after=some_cursor'}             | ${{ id: upstreamId, after: 'some_cursor', first: 20 }}                | ${{ id: upstreamId }}
        ${'?before=some_cursor'}            | ${{ id: upstreamId, before: 'some_cursor', last: 20 }}                | ${{ id: upstreamId }}
      `(
        'parses URL params and passes them to GraphQL queries ($params)',
        async ({ params, expectedEntriesArgs, expectedCountArgs }) => {
          setWindowLocation(params);

          createComponent();

          await nextTick();

          expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenCalledTimes(1);
          expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenCalledWith(expectedEntriesArgs);

          expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledTimes(1);
          expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledWith(
            expectedCountArgs,
          );
        },
      );
    });
  });

  describe('component rendering', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('passes loading state as false after data loads', () => {
      expect(findHeader().props('loading')).toBe(false);
      expect(findTable().props('loading')).toBe(false);
    });

    it('renders details header with cache entries count', () => {
      expect(findHeader().props('upstream')).toEqual(mockUpstream);
      expect(findHeader().props('cacheEntriesCount')).toBe(1);
    });

    it('queries with the right arguments', () => {
      expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenCalledTimes(1);
      expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenCalledWith({
        id: upstreamId,
        first: 20,
      });

      expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledTimes(1);
      expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledWith({
        id: upstreamId,
      });
    });

    it('renders cache entries table', () => {
      expect(findTable().props('cacheEntries')).toEqual(mockCacheEntries);
    });

    it('sets pagination with right props', () => {
      const { __typename, ...pageInfo } = mockPageInfo;
      expect(findPagination().props()).toMatchObject(pageInfo);
    });
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders filter search', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('searches for artifact relative path', async () => {
      jest.spyOn(urlUtils, 'updateHistory');
      await findFilteredSearch().vm.$emit('submit', ['foo']);

      expect(findTable().props('loading')).toBe(true);

      await waitForPromises();

      expect(findTable().props('loading')).toBe(false);
      expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenLastCalledWith({
        id: upstreamId,
        search: 'foo',
        first: 20,
      });
      expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenLastCalledWith({
        id: upstreamId,
      });
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?search=foo`,
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      jest.spyOn(urlUtils, 'updateHistory');
      createComponent();

      await waitForPromises();
    });

    it('paginates next page', async () => {
      await findPagination().vm.$emit('next');

      expect(findHeader().props('loading')).toBe(false);
      expect(findTable().props('loading')).toBe(true);

      await waitForPromises();

      expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenLastCalledWith({
        id: upstreamId,
        first: 20,
        after: mockPageInfo.endCursor,
      });
      expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledTimes(1);
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?after=${mockPageInfo.endCursor}`,
      });
    });

    it('paginates prev page', async () => {
      await findPagination().vm.$emit('prev');

      expect(findHeader().props('loading')).toBe(false);
      expect(findTable().props('loading')).toBe(true);

      await waitForPromises();

      expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenLastCalledWith({
        id: upstreamId,
        last: 20,
        before: mockPageInfo.startCursor,
      });
      expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledTimes(1);
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?before=${mockPageInfo.endCursor}`,
      });
    });

    describe('with search term', () => {
      it('passes search arguments while paginating', async () => {
        await findFilteredSearch().vm.$emit('submit', ['foo']);
        await findPagination().vm.$emit('next');

        await waitForPromises();

        expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenLastCalledWith({
          id: upstreamId,
          search: 'foo',
          first: 20,
          after: mockPageInfo.endCursor,
        });
        expect(urlUtils.updateHistory).toHaveBeenCalledWith({
          url: `${TEST_HOST}/?after=${mockPageInfo.endCursor}&search=foo`,
        });
      });
    });
  });

  describe('actions', () => {
    it('deletes upstream artifact via REST API when deleteCacheEntryMutation is not provided', async () => {
      createComponent();

      await waitForPromises();

      await findTable().vm.$emit('delete', { id: mockCacheEntry.id });

      await nextTick();

      expect(findHeader().props('loading')).toBe(true);
      expect(findTable().props('loading')).toBe(true);

      expect(deleteMavenUpstreamCacheEntry).toHaveBeenCalledWith({ id: mockCacheEntry.id });

      expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenCalledTimes(2);
      expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledTimes(2);
    });

    describe('when deleteCacheEntryMutation is provided', () => {
      const createComponentWithMutation = () =>
        createComponent({
          handlers: [
            [getMavenUpstreamCacheEntriesQuery, mavenUpstreamCacheEntriesQueryResolver],
            [getMavenUpstreamCacheEntriesCountQuery, mavenUpstreamCacheEntriesCountQueryResolver],
            [deleteContainerCacheEntryMutation, deleteContainerCacheEntryMutationResolver],
          ],
          provide: { deleteCacheEntryMutation: deleteContainerCacheEntryMutation },
        });

      it('deletes upstream artifact via GraphQL mutation', async () => {
        createComponentWithMutation();

        await waitForPromises();

        await findTable().vm.$emit('delete', { id: mockCacheEntry.id });

        await waitForPromises();

        expect(deleteContainerCacheEntryMutationResolver).toHaveBeenCalledWith({
          id: mockCacheEntry.id,
        });
        expect(deleteMavenUpstreamCacheEntry).not.toHaveBeenCalled();
        expect(mavenUpstreamCacheEntriesQueryResolver).toHaveBeenCalledTimes(2);
        expect(mavenUpstreamCacheEntriesCountQueryResolver).toHaveBeenCalledTimes(2);
      });

      it('shows error message when mutation returns errors', async () => {
        const mutationError = 'something went wrong';
        deleteContainerCacheEntryMutationResolver.mockResolvedValue({
          data: { delete: { errors: [mutationError] } },
        });

        createComponentWithMutation();

        await waitForPromises();

        findTable().vm.$emit('delete', { id: mockCacheEntry.id });

        await waitForPromises();

        expect(deleteMavenUpstreamCacheEntry).not.toHaveBeenCalled();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to delete cache entry.',
          error: mutationError,
          captureError: true,
        });
      });
    });
  });

  describe('error state', () => {
    it('shows empty state when upstream is not found', async () => {
      createComponent({
        handlers: [
          [getMavenUpstreamCacheEntriesQuery, mavenUpstreamCacheEntriesQueryResolver],
          [getMavenUpstreamCacheEntriesCountQuery, mavenUpstreamCacheEntriesCountQueryResolver],
          [getUpstreamSummaryQuery, jest.fn().mockResolvedValue({ data: { upstream: null } })],
        ],
        provide: {
          initialUpstream: {},
          getUpstreamSummaryQuery,
        },
        propsData: {
          id: 1,
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
    });

    it('shows error message on failed attempt to get cached entries', async () => {
      const error = new Error('API Error');

      createComponent({
        handlers: [
          [getMavenUpstreamCacheEntriesQuery, jest.fn().mockRejectedValue(error)],
          [getMavenUpstreamCacheEntriesCountQuery, mavenUpstreamCacheEntriesCountQueryResolver],
        ],
      });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch cache entries.',
        error,
        captureError: true,
      });
    });

    it('shows error message on failed attempt to get cached entries count', async () => {
      const error = new Error('API Error');

      createComponent({
        handlers: [
          [getMavenUpstreamCacheEntriesQuery, mavenUpstreamCacheEntriesQueryResolver],
          [getMavenUpstreamCacheEntriesCountQuery, jest.fn().mockRejectedValue(error)],
        ],
      });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch cache entries count.',
        error,
        captureError: true,
      });
    });

    it('shows error message on failed attempt to delete upstream artifact', async () => {
      const error = new Error('API Error');

      deleteMavenUpstreamCacheEntry.mockRejectedValue(error);

      createComponent();

      await waitForPromises();

      findTable().vm.$emit('delete', { id: mockCacheEntry.id });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to delete cache entry.',
        error,
        captureError: true,
      });
    });
  });
});
