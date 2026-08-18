import produce from 'immer';
import groupStreamingDestinationsQuery from './queries/get_group_streaming_destinations.query.graphql';
import instanceStreamingDestinationsQuery from './queries/get_instance_streaming_destinations.query.graphql';

const getGroupDestinationId = (store, id) =>
  store.identify({
    __typename: 'GroupAuditEventStreamingDestination',
    id,
  });

const getInstanceDestinationId = (store, id) =>
  store.identify({
    __typename: 'InstanceAuditEventStreamingDestination',
    id,
  });

export function addAuditEventsStreamingDestinationToCache({
  store,
  isInstance,
  fullPath,
  newDestination,
}) {
  const getDestinationQuery = isInstance
    ? instanceStreamingDestinationsQuery
    : groupStreamingDestinationsQuery;

  const variables = isInstance ? {} : { fullPath };

  const sourceData = store.readQuery({
    query: getDestinationQuery,
    variables,
  });

  if (!sourceData) return;

  const data = produce(sourceData, (draftData) => {
    const nodes = isInstance
      ? draftData.auditEventsInstanceStreamingDestinations.nodes
      : draftData.group.externalAuditEventStreamingDestinations.nodes;
    nodes.unshift(newDestination);
  });

  store.writeQuery({ query: getDestinationQuery, variables, data });
}

export function updateAuditEventsStreamingDestinationFromCache({ store, isInstance, updatedData }) {
  const storedDestinationId = isInstance
    ? getInstanceDestinationId(store, updatedData?.id)
    : getGroupDestinationId(store, updatedData?.id);

  if (!storedDestinationId) return;

  store.modify({
    id: storedDestinationId,
    fields: {
      name() {
        return updatedData.name;
      },
      config() {
        return updatedData.config;
      },
      eventTypeFilters() {
        return updatedData.eventTypeFilters;
      },
      namespaceFilters() {
        return updatedData.namespaceFilters;
      },
      active() {
        return updatedData.active;
      },
    },
  });
}

export function updateEventTypeFiltersFromCache({ store, isInstance, destinationId, filters }) {
  const storedDestinationId = isInstance
    ? getInstanceDestinationId(store, destinationId)
    : getGroupDestinationId(store, destinationId);

  if (!storedDestinationId) return;

  store.modify({
    id: storedDestinationId,
    fields: {
      eventTypeFilters() {
        return filters;
      },
    },
  });
}

export function setNamespaceFiltersInCache({ store, destinationId, filters, isInstance }) {
  const storedDestinationId = isInstance
    ? getInstanceDestinationId(store, destinationId)
    : getGroupDestinationId(store, destinationId);

  if (!storedDestinationId) return;

  store.modify({
    id: storedDestinationId,
    fields: {
      namespaceFilters() {
        return filters;
      },
    },
  });
}

export function removeAuditEventsStreamingDestinationFromCache({
  store,
  isInstance,
  fullPath,
  destinationId,
}) {
  const getDestinationQuery = isInstance
    ? instanceStreamingDestinationsQuery
    : groupStreamingDestinationsQuery;

  const variables = isInstance ? {} : { fullPath };

  const sourceData = store.readQuery({
    query: getDestinationQuery,
    variables,
  });

  if (!sourceData) return;

  const data = produce(sourceData, (draftData) => {
    if (isInstance) {
      draftData.auditEventsInstanceStreamingDestinations.nodes =
        draftData.auditEventsInstanceStreamingDestinations.nodes.filter(
          (node) => node.id !== destinationId,
        );
    } else {
      draftData.group.externalAuditEventStreamingDestinations.nodes =
        draftData.group.externalAuditEventStreamingDestinations.nodes.filter(
          (node) => node.id !== destinationId,
        );
    }
  });

  store.writeQuery({ query: getDestinationQuery, variables, data });
}
