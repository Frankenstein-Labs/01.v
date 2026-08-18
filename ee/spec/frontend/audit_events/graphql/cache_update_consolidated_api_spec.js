import { InMemoryCache } from '@apollo/client/core';
import {
  addAuditEventsStreamingDestinationToCache,
  updateAuditEventsStreamingDestinationFromCache,
  updateEventTypeFiltersFromCache,
  setNamespaceFiltersInCache,
  removeAuditEventsStreamingDestinationFromCache,
} from 'ee/audit_events/graphql/cache_update_consolidated_api';
import getGroupStreamingDestinationsQuery from 'ee/audit_events/graphql/queries/get_group_streaming_destinations.query.graphql';
import getInstanceStreamingDestinationsQuery from 'ee/audit_events/graphql/queries/get_instance_streaming_destinations.query.graphql';
import {
  mockAllAPIDestinations,
  destinationCreateMutationPopulator,
  groupStreamingDestinationDataPopulator,
  instanceStreamingDestinationDataPopulator,
} from '../mock_data/consolidated_api';

describe('Audit events GraphQL cache updates', () => {
  const GROUP1_PATH = 'group-1';
  const GROUP2_PATH = 'group-2';
  const GROUP_NOT_IN_CACHE = 'other-group';
  let cache;

  const getMockInstanceDestinations = (id) =>
    instanceStreamingDestinationDataPopulator(
      mockAllAPIDestinations.map((record) => ({
        ...record,
        id: `${record.id}-set-${id}`,
        __typename: 'InstanceAuditEventStreamingDestination',
      })),
    );

  const getMockGroupDestinations = (id) =>
    groupStreamingDestinationDataPopulator(
      mockAllAPIDestinations.map((record) => ({ ...record, id: `${record.id}-set-${id}` })),
    );

  const getGroupDestinations = (fullPath) =>
    cache.readQuery({
      query: getGroupStreamingDestinationsQuery,
      variables: { fullPath },
    }).group.externalAuditEventStreamingDestinations.nodes;

  const getDestinations = (view, fullPath = GROUP1_PATH) => {
    if (view !== 'instance') return getGroupDestinations(fullPath);

    return cache.readQuery({
      query: getInstanceStreamingDestinationsQuery,
    }).auditEventsInstanceStreamingDestinations.nodes;
  };

  beforeEach(() => {
    cache = new InMemoryCache({
      possibleTypes: {
        AuditEventStreamingDestinationInterface: [
          'GroupAuditEventStreamingDestination',
          'InstanceAuditEventStreamingDestination',
        ],
      },
    });

    cache.writeQuery({
      query: getGroupStreamingDestinationsQuery,
      variables: { fullPath: GROUP1_PATH },
      data: getMockGroupDestinations(GROUP1_PATH).data,
    });

    cache.writeQuery({
      query: getGroupStreamingDestinationsQuery,
      variables: { fullPath: GROUP2_PATH },
      data: getMockGroupDestinations(GROUP2_PATH).data,
    });

    cache.writeQuery({
      query: getInstanceStreamingDestinationsQuery,
      data: getMockInstanceDestinations().data,
    });
  });

  describe.each`
    view
    ${'group'}
    ${'instance'}
  `('when the view is $view', ({ view }) => {
    describe('addAuditEventsStreamingDestinationToCache', () => {
      const { externalAuditEventDestination: newDestination } = destinationCreateMutationPopulator({
        view,
      });

      it('adds new destination to beginning of the list of destinations for specific fullPath', () => {
        const { length: originalDestinationsLength } = getDestinations(view);
        const { length: originalDestinationsLengthForGroup2 } = getGroupDestinations(GROUP2_PATH);

        addAuditEventsStreamingDestinationToCache({
          store: cache,
          isInstance: view === 'instance',
          fullPath: view === 'group' ? GROUP1_PATH : view,
          newDestination,
        });

        expect(getDestinations(view)).toHaveLength(originalDestinationsLength + 1);
        expect(getDestinations(view)[0].id).toBe(newDestination.id);
        expect(getGroupDestinations(GROUP2_PATH)).toHaveLength(originalDestinationsLengthForGroup2);
      });

      it('does not throw on non-existing fullPath', () => {
        expect(() =>
          addAuditEventsStreamingDestinationToCache({
            store: cache,
            isInstance: view === 'instance',
            fullPath: GROUP_NOT_IN_CACHE,
            newDestination,
          }),
        ).not.toThrow();
      });
    });

    describe('updateAuditEventsStreamingDestinationFromCache', () => {
      it('updates an existing destination in the cache', () => {
        const [, secondDestination] = getDestinations(view);

        const updatedData = {
          ...secondDestination,
          name: 'Updated Name',
          config: { url: 'https://updated.url' },
          eventTypeFilters: ['event-type-a', 'event-type-b'],
        };

        updateAuditEventsStreamingDestinationFromCache({
          store: cache,
          isInstance: view === 'instance',
          updatedData,
        });

        const [, secondDestinationAfterUpdate] = getDestinations(view);

        expect(secondDestinationAfterUpdate).toStrictEqual(updatedData);
      });

      it('does not throw on non-existing destination', () => {
        expect(() =>
          updateAuditEventsStreamingDestinationFromCache({
            store: cache,
            isInstance: view === 'instance',
            destinationId: 'non-existing-id',
            filters: [],
          }),
        ).not.toThrow();
      });
    });

    describe('updateEventTypeFiltersFromCache', () => {
      it('updates event type filters on specified destination', () => {
        const [, secondDestination] = getDestinations(view);

        const newFilters = ['new-1', 'new-2'];

        updateEventTypeFiltersFromCache({
          store: cache,
          isInstance: view === 'instance',
          destinationId: secondDestination.id,
          filters: newFilters,
        });

        const [, secondDestinationAfterUpdate] = getDestinations(view);

        expect(secondDestinationAfterUpdate.eventTypeFilters).toStrictEqual(newFilters);
      });

      it('does not throw on non-existing destination', () => {
        expect(() =>
          updateEventTypeFiltersFromCache({
            store: cache,
            isInstance: view === 'instance',
            destinationId: 'non-existing-id',
            filters: [],
          }),
        ).not.toThrow();
      });
    });

    describe('removeAuditEventsStreamingDestinationFromCache', () => {
      it('removes new destination to list of destinations for specific fullPath', () => {
        const [firstDestination, ...restDestinations] = getDestinations(view);
        const { length: originalDestinationsLength } = getDestinations(view);

        removeAuditEventsStreamingDestinationFromCache({
          store: cache,
          isInstance: view === 'instance',
          fullPath: view === 'group' ? GROUP1_PATH : view,
          destinationId: firstDestination.id,
        });

        expect(getDestinations(view)).toHaveLength(restDestinations.length);
        expect(getDestinations(view)).not.toStrictEqual(
          expect.arrayContaining([expect.objectContaining({ id: firstDestination.id })]),
        );
        expect(getDestinations(view)).toHaveLength(originalDestinationsLength - 1);
      });

      it('does not throw on non-existing fullPath', () => {
        expect(() =>
          removeAuditEventsStreamingDestinationFromCache({
            store: cache,
            isInstance: view === 'instance',
            fullPath: view === 'group' ? GROUP1_PATH : view,
            destinationId: 'fake-id',
          }),
        ).not.toThrow();
      });
    });
  });

  describe('for group specific view', () => {
    describe('setNamespaceFiltersInCache', () => {
      it('replaces namespace filters on specified destination with the provided list', () => {
        const [, secondDestination] = getGroupDestinations(GROUP1_PATH);
        const newNamespaceFilters = [
          {
            __typename: 'GroupAuditEventNamespaceFilter',
            id: 'namespace-filter-123',
            namespace: {
              __typename: 'Namespace',
              id: 'namespace-123',
              name: 'subgroup1',
              fullPath: `${GROUP1_PATH}/subgroup1`,
            },
          },
          {
            __typename: 'GroupAuditEventNamespaceFilter',
            id: 'namespace-filter-456',
            namespace: {
              __typename: 'Namespace',
              id: 'namespace-456',
              name: 'subgroup2',
              fullPath: `${GROUP1_PATH}/subgroup2`,
            },
          },
        ];

        setNamespaceFiltersInCache({
          store: cache,
          destinationId: secondDestination.id,
          filters: newNamespaceFilters,
        });

        const [, secondDestinationAfterUpdate] = getGroupDestinations(GROUP1_PATH);

        expect(secondDestinationAfterUpdate.namespaceFilters).toStrictEqual(newNamespaceFilters);
      });

      it('does not throw on non-existing destination', () => {
        expect(() =>
          setNamespaceFiltersInCache({
            store: cache,
            destinationId: 'non-existing-id',
            filters: [],
          }),
        ).not.toThrow();
      });
    });

    describe('updateAuditEventsStreamingDestinationFromCache', () => {
      it('updates namespace filter from an existing destination in the cache', () => {
        const [, secondDestination] = getGroupDestinations(GROUP1_PATH);

        const updatedData = {
          ...secondDestination,
          namespaceFilters: [
            {
              __typename: 'GroupAuditEventNamespaceFilter',
              id: 'namespace-filter-123',
              namespace: {
                __typename: 'Namespace',
                id: 'namespace-123',
                name: 'subgroup1',
                fullPath: `${GROUP1_PATH}/subgroup1`,
              },
            },
          ],
        };

        updateAuditEventsStreamingDestinationFromCache({
          store: cache,
          isInstance: false,
          updatedData,
        });

        const [, secondDestinationAfterUpdate] = getGroupDestinations(GROUP1_PATH);

        expect(secondDestinationAfterUpdate).toStrictEqual(updatedData);
      });
    });
  });
});
