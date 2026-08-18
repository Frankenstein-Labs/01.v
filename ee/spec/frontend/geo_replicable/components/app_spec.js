import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  ACTION_TYPES,
  BULK_ACTIONS,
  GEO_TROUBLESHOOTING_LINK,
  DEFAULT_PAGE_SIZE,
  DEFAULT_CURSOR,
  SORT_OPTIONS,
} from 'ee/geo_replicable/constants';
import GeoReplicableApp from 'ee/geo_replicable/components/app.vue';
import GeoReplicable from 'ee/geo_replicable/components/geo_replicable.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import replicableTypeBulkUpdateMutation from 'ee/geo_shared/graphql/replicable_type_bulk_update_mutation.graphql';
import buildReplicableTypeQuery from 'ee/geo_replicable/graphql/replicable_type_query_builder';
import { processFilters } from 'ee/geo_replicable/filters';
import { TEST_HOST } from 'spec/test_constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import { setUrlParams, visitUrl, updateHistory } from '~/lib/utils/url_utility';
import {
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_CLASS,
  MOCK_REPLICABLE_TYPE_FILTER,
  MOCK_REPLICATION_STATUS_FILTER,
  MOCK_VERIFICATION_STATUS_FILTER,
  MOCK_GRAPHQL_PAGINATION_DATA,
} from '../mock_data';

const MOCK_FILTERS = { foo: 'bar' };
const MOCK_PROCESSED_FILTERS = { query: MOCK_FILTERS, url: { href: 'mock-url/params' } };
const MOCK_UPDATED_URL = 'mock-url/params?foo=bar';

const MOCK_BASE_LOCATION = `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}`;
const MOCK_REPLICATION_STATUS_QUERY = `${MOCK_REPLICATION_STATUS_FILTER.type}=${MOCK_REPLICATION_STATUS_FILTER.value.data}`;
const MOCK_VERIFICATION_STATUS_QUERY = `${MOCK_VERIFICATION_STATUS_FILTER.type}=${MOCK_VERIFICATION_STATUS_FILTER.value.data}`;
const MOCK_IDS_QUERY = `ids=${MOCK_BASIC_GRAPHQL_DATA[0].id}`;

const MOCK_LOCATION_WITH_FILTERS = `${MOCK_BASE_LOCATION}?${MOCK_REPLICATION_STATUS_QUERY}&${MOCK_VERIFICATION_STATUS_QUERY}&${MOCK_IDS_QUERY}`;

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  setUrlParams: jest.fn(() => MOCK_UPDATED_URL),
  visitUrl: jest.fn(),
  updateHistory: jest.fn(),
}));

jest.mock('ee/geo_replicable/filters', () => ({
  ...jest.requireActual('ee/geo_replicable/filters'),
  processFilters: jest.fn(() => MOCK_PROCESSED_FILTERS),
}));

jest.mock('~/alert');
jest.mock('~/vue_shared/plugins/global_toast');

Vue.use(VueApollo);

describe('GeoReplicableApp', () => {
  let wrapper;

  const defaultProvide = {
    itemTitle: 'Test Items',
    siteName: 'Test Site',
    replicableClass: MOCK_REPLICABLE_CLASS,
  };

  const MOCK_EMPTY_STATE = {
    title: 'No Test Items exist',
    description:
      'If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
    helpLink: GEO_TROUBLESHOOTING_LINK,
    hasFilters: false,
  };

  const query = buildReplicableTypeQuery({
    graphqlFieldName: defaultProvide.replicableClass.graphqlFieldName,
    graphqlRegistryIdType: defaultProvide.replicableClass.graphqlRegistryIdType,
    verificationEnabled: defaultProvide.replicableClass.verificationEnabled,
  });

  const MOCK_QUERY_HANDLER_WITH_DATA = jest.fn().mockResolvedValue({
    data: {
      geoNode: {
        [defaultProvide.replicableClass.graphqlFieldName]: {
          nodes: MOCK_BASIC_GRAPHQL_DATA,
          count: MOCK_BASIC_GRAPHQL_DATA.length,
          pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
        },
      },
    },
  });

  const MOCK_QUERY_HANDLER_WITHOUT_DATA = jest.fn().mockResolvedValue({
    data: {
      geoNode: {
        [defaultProvide.replicableClass.graphqlFieldName]: {
          nodes: [],
          count: 0,
          pageInfo: {},
        },
      },
    },
  });

  const MOCK_SINGLE_MUTATION_HANDLER = jest.fn().mockResolvedValue({
    data: {
      geoRegistriesUpdate: {
        errors: [],
      },
    },
  });

  const MOCK_BULK_MUTATION_HANDLER = jest.fn().mockResolvedValue({
    data: {
      geoRegistriesBulkUpdate: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    provide,
    handler,
    singleMutationHandler,
    bulkMutationHandler,
  } = {}) => {
    const apolloQueryHandler = handler || MOCK_QUERY_HANDLER_WITH_DATA;
    const apolloSingleMutationHandler = singleMutationHandler || MOCK_SINGLE_MUTATION_HANDLER;
    const apolloBulkMutationHandler = bulkMutationHandler || MOCK_BULK_MUTATION_HANDLER;

    const apolloProvider = createMockApollo([
      [query, apolloQueryHandler],
      [replicableTypeUpdateMutation, apolloSingleMutationHandler],
      [replicableTypeBulkUpdateMutation, apolloBulkMutationHandler],
    ]);

    wrapper = shallowMount(GeoReplicableApp, {
      apolloProvider,
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findGeoReplicableContainer = () => wrapper.find('.geo-replicable-container');
  const findGeoReplicable = () => findGeoReplicableContainer().findComponent(GeoReplicable);
  const findGeoList = () => findGeoReplicableContainer().findComponent(GeoList);
  const findGeoListTopBar = () => findGeoReplicableContainer().findComponent(GeoListTopBar);

  beforeEach(() => {
    setWindowLocation(MOCK_BASE_LOCATION);
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('when isLoading is true renders GeoList with loading state true and GeoReplicable in default slot', () => {
      expect(findGeoList().props()).toStrictEqual({
        isLoading: true,
        hasItems: false,
        emptyState: MOCK_EMPTY_STATE,
      });

      expect(findGeoReplicable().exists()).toBe(true);
    });
  });

  describe.each`
    hasItems | handler                            | expectedPagination
    ${true}  | ${MOCK_QUERY_HANDLER_WITH_DATA}    | ${{ ...MOCK_GRAPHQL_PAGINATION_DATA, count: MOCK_BASIC_GRAPHQL_DATA.length }}
    ${false} | ${MOCK_QUERY_HANDLER_WITHOUT_DATA} | ${{ count: 0 }}
  `('GeoList state', ({ hasItems, handler, expectedPagination }) => {
    describe(`${hasItems ? 'does' : 'does not'} have replicableItems`, () => {
      beforeEach(async () => {
        createComponent({ handler });

        await waitForPromises();
      });

      it('renders GeoList with the correct params', () => {
        expect(findGeoList().props()).toStrictEqual({
          isLoading: false,
          hasItems,
          emptyState: MOCK_EMPTY_STATE,
        });
      });

      it('renders GeoReplicable in the default slot of GeoList always with correct pageInfo props', () => {
        expect(findGeoReplicable().exists()).toBe(true);
        expect(findGeoReplicable().props('pageInfo')).toStrictEqual(expectedPagination);
      });
    });
  });

  describe('error handling', () => {
    it('displays error message when Apollo query fails', async () => {
      const errorMessage = new Error('GraphQL Error');
      const handler = jest.fn().mockRejectedValue(errorMessage);
      createComponent({ handler });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message:
          'There was an error fetching the Test Items. The GraphQL API call to the secondary may have failed.',
        captureError: true,
        error: errorMessage,
      });
    });
  });

  describe.each`
    hasFilters | mockLocation
    ${false}   | ${MOCK_BASE_LOCATION}
    ${true}    | ${MOCK_LOCATION_WITH_FILTERS}
  `('empty state property', ({ hasFilters, mockLocation }) => {
    describe(`when filters are ${hasFilters}`, () => {
      beforeEach(async () => {
        setWindowLocation(mockLocation);

        createComponent({ handler: MOCK_QUERY_HANDLER_WITHOUT_DATA });

        await waitForPromises();
      });

      it('renders GeoList with correct empty state prop', () => {
        expect(findGeoList().props('emptyState')).toStrictEqual({
          ...MOCK_EMPTY_STATE,
          hasFilters,
        });
      });
    });
  });

  describe('filter bar', () => {
    describe('when no query is present', () => {
      beforeEach(() => {
        setWindowLocation(MOCK_BASE_LOCATION);

        createComponent();
      });

      it('renders top bar with correct listbox item and no search filters', () => {
        expect(findGeoListTopBar().props('activeListboxItem')).toBe(
          MOCK_REPLICABLE_TYPE_FILTER.value,
        );
        expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([]);
      });
    });

    describe('when query is present', () => {
      describe('when verification is enabled', () => {
        beforeEach(() => {
          setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

          createComponent();
        });

        it('renders top bar with correct listbox item and search filters including verification status', () => {
          expect(findGeoListTopBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([
            MOCK_BASIC_GRAPHQL_DATA[0].id,
            MOCK_REPLICATION_STATUS_FILTER,
            MOCK_VERIFICATION_STATUS_FILTER,
          ]);
        });
      });

      describe('when verification is disabled', () => {
        beforeEach(() => {
          setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

          createComponent({
            provide: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: false } },
          });
        });

        it('renders top bar with correct listbox item and search filters excluding verification status', () => {
          expect(findGeoListTopBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([
            MOCK_BASIC_GRAPHQL_DATA[0].id,
            MOCK_REPLICATION_STATUS_FILTER,
          ]);
        });
      });
    });
  });

  describe('pagination query', () => {
    beforeEach(() => {
      setWindowLocation(`${MOCK_LOCATION_WITH_FILTERS}&after=cursor123&first=20`);

      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });
    });

    it('properly calls Apollo with custom cursor when provided', () => {
      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          after: 'cursor123',
          first: 20,
        }),
      );
    });
  });

  describe('sort query', () => {
    beforeEach(() => {
      setWindowLocation(
        `${MOCK_LOCATION_WITH_FILTERS}&sort=${SORT_OPTIONS.LAST_SYNCED_AT.value}_desc`,
      );

      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });
    });

    it('properly calls Apollo with custom sort when provided', () => {
      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          sort: `${SORT_OPTIONS.LAST_SYNCED_AT.value}_desc`.toUpperCase(),
        }),
      );
    });
  });

  describe('bulk actions', () => {
    describe('with no replicable items', () => {
      beforeEach(async () => {
        createComponent({ handler: MOCK_QUERY_HANDLER_WITHOUT_DATA });

        await waitForPromises();
      });

      it('renders top bar with showActions=false', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
      });
    });

    describe('with replicable items', () => {
      beforeEach(async () => {
        createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

        await waitForPromises();
        MOCK_QUERY_HANDLER_WITH_DATA.mockClear();
      });

      it('renders top bar with showActions=true and correct actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(true);
        expect(findGeoListTopBar().props('bulkActions')).toStrictEqual(BULK_ACTIONS);
      });

      it('when top bar emits @bulk-action, bulk action mutation is called with correct action, emits a toast and calls refetch', async () => {
        findGeoListTopBar().vm.$emit('bulk-action', BULK_ACTIONS[0]);
        await nextTick();

        expect(MOCK_BULK_MUTATION_HANDLER).toHaveBeenCalledWith({
          action: BULK_ACTIONS[0].action.toUpperCase(),
          registryClass: MOCK_REPLICABLE_CLASS.graphqlMutationRegistryClass,
          replicationState: null,
          verificationState: null,
        });

        await waitForPromises();

        expect(toast).toHaveBeenCalledWith('Scheduled all Test Items for resynchronization.');
        expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledTimes(1);
      });
    });

    describe('when bulk action fails', () => {
      beforeEach(async () => {
        const errorMutationHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));
        createComponent({ bulkMutationHandler: errorMutationHandler });

        await waitForPromises();
      });

      it('when top bar emits @bulk-action, createAlert is called and not toast', async () => {
        findGeoListTopBar().vm.$emit('bulk-action', BULK_ACTIONS[0]);
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error scheduling all Test Items for resynchronization.',
          error: expect.any(Error),
          captureError: true,
        });

        expect(toast).not.toHaveBeenCalled();
      });
    });
  });

  describe('page title', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the correct title and description to the topbar', () => {
      expect(findGeoListTopBar().props('pageHeadingTitle')).toBe('Geo replication - Test Site');
      expect(findGeoListTopBar().props('pageHeadingDescription')).toBe(
        'Review replication status, and resynchronize and reverify items with the primary site.',
      );
    });
  });

  describe.each`
    count   | expectedText
    ${null} | ${null}
    ${0}    | ${null}
    ${1}    | ${'1 Registry'}
    ${500}  | ${'500 Registries'}
    ${1000} | ${'1000 Registries'}
    ${1001} | ${'1000+ Registries'}
    ${5000} | ${'1000+ Registries'}
  `('list count when count is $count', ({ count, expectedText }) => {
    const MOCK_QUERY_HANDLER_WITH_COUNT = jest.fn().mockResolvedValue({
      data: {
        geoNode: {
          [defaultProvide.replicableClass.graphqlFieldName]: {
            nodes: MOCK_BASIC_GRAPHQL_DATA,
            count,
            pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
          },
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        handler: MOCK_QUERY_HANDLER_WITH_COUNT,
      });

      await waitForPromises();
    });

    it(`passes ${expectedText} as the listCountText prop to the topBar`, () => {
      expect(findGeoListTopBar().props('listCountText')).toBe(expectedText);
    });
  });

  describe('handleListboxChange', () => {
    beforeEach(() => {
      setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

      createComponent();
    });

    it('preserves active filters and resets cursor while updating the replicable type before calling processFilters and visitUrl', () => {
      const MOCK_NEW_REPLICABLE_TYPE = 'new_replicable_type';

      findGeoListTopBar().vm.$emit('listbox-change', MOCK_NEW_REPLICABLE_TYPE);

      expect(processFilters).toHaveBeenCalledWith([
        { type: MOCK_REPLICABLE_TYPE_FILTER.type, value: MOCK_NEW_REPLICABLE_TYPE },
        MOCK_BASIC_GRAPHQL_DATA[0].id,
        { type: MOCK_REPLICATION_STATUS_FILTER.type, value: MOCK_REPLICATION_STATUS_FILTER.value },
        {
          type: MOCK_VERIFICATION_STATUS_FILTER.type,
          value: MOCK_VERIFICATION_STATUS_FILTER.value,
        },
      ]);
      expect(setUrlParams).toHaveBeenCalledWith(
        { ...MOCK_PROCESSED_FILTERS.query, ...DEFAULT_CURSOR, sort: 'id_asc' },
        { url: MOCK_PROCESSED_FILTERS.url.href, clearParams: true },
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
    });
  });

  describe('handleSearch', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();

      MOCK_QUERY_HANDLER_WITH_DATA.mockClear();
    });

    it('updates Apollo query, processes filters, and resets cursor before calling updateHistory', async () => {
      findGeoListTopBar().vm.$emit('search', [MOCK_VERIFICATION_STATUS_FILTER]);
      await nextTick();

      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledTimes(1);

      expect(processFilters).toHaveBeenCalledWith([
        { type: MOCK_REPLICABLE_TYPE_FILTER.type, value: MOCK_REPLICABLE_TYPE_FILTER.value },
        MOCK_VERIFICATION_STATUS_FILTER,
      ]);
      expect(setUrlParams).toHaveBeenCalledWith(
        { ...MOCK_PROCESSED_FILTERS.query, ...DEFAULT_CURSOR, sort: 'id_asc' },
        { url: MOCK_PROCESSED_FILTERS.url.href, clearParams: true },
      );
      expect(updateHistory).toHaveBeenCalledWith({ url: MOCK_UPDATED_URL });
    });
  });

  describe('handleNextPage', () => {
    beforeEach(async () => {
      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

      await waitForPromises();
    });

    it('updates Apollo query with updated cursor and updates the URL', async () => {
      findGeoReplicable().vm.$emit('next', 'test_item');
      await nextTick();

      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          before: '',
          after: 'test_item',
          first: DEFAULT_PAGE_SIZE,
          last: null,
        }),
      );

      expect(updateHistory).toHaveBeenCalledWith({ url: MOCK_UPDATED_URL });
    });
  });

  describe('handlePrevPage', () => {
    beforeEach(async () => {
      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

      await waitForPromises();
    });

    it('updates Apollo query with updated cursor and updates the URL', async () => {
      findGeoReplicable().vm.$emit('prev', 'test_item');
      await nextTick();

      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          before: 'test_item',
          after: '',
          first: null,
          last: DEFAULT_PAGE_SIZE,
        }),
      );

      expect(updateHistory).toHaveBeenCalledWith({ url: MOCK_UPDATED_URL });
    });
  });

  describe('handleSort', () => {
    beforeEach(async () => {
      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

      await waitForPromises();
    });

    it('updates Apollo query with updated sort, resets cursor, and updates the URL', async () => {
      findGeoListTopBar().vm.$emit('sort', {
        value: SORT_OPTIONS.LAST_SYNCED_AT.value,
        direction: 'desc',
      });
      await nextTick();

      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          before: '',
          after: '',
          first: DEFAULT_PAGE_SIZE,
          last: null,
          sort: `${SORT_OPTIONS.LAST_SYNCED_AT.value}_desc`.toUpperCase(),
        }),
      );

      expect(updateHistory).toHaveBeenCalledWith({ url: MOCK_UPDATED_URL });
    });
  });

  describe('handleSingleAction', () => {
    describe('when single action is successful', () => {
      beforeEach(async () => {
        createComponent();

        await waitForPromises();
        MOCK_QUERY_HANDLER_WITH_DATA.mockClear();
      });

      it('properly calls the single action mutation, toast and refetch', async () => {
        findGeoReplicable().vm.$emit('action-clicked', {
          action: ACTION_TYPES.RESYNC,
          name: 'TestRegistry/1',
          registryId: '123',
        });
        await nextTick();

        expect(MOCK_SINGLE_MUTATION_HANDLER).toHaveBeenCalledWith({
          action: ACTION_TYPES.RESYNC.toUpperCase(),
          registryId: '123',
        });

        await waitForPromises();

        expect(toast).toHaveBeenCalledWith('Scheduled TestRegistry/1 for resync.');
        expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledTimes(1);
      });
    });

    describe('when single action is not successful', () => {
      beforeEach(async () => {
        const errorMutationHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));
        createComponent({ singleMutationHandler: errorMutationHandler });

        await waitForPromises();
      });

      it('calls createAlert and not toast', async () => {
        findGeoReplicable().vm.$emit('action-clicked', {
          action: ACTION_TYPES.RESYNC,
          name: 'TestRegistry/1',
          registryId: '123',
        });
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error scheduling TestRegistry/1 for resync.',
          error: expect.any(Error),
          captureError: true,
        });

        expect(toast).not.toHaveBeenCalled();
      });
    });
  });
});
