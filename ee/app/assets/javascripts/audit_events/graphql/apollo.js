import {
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
} from '../constants';

import updateGroupStreamingDestination from './mutations/update_group_streaming_destination.mutation.graphql';
import createGroupStreamingDestination from './mutations/create_group_streaming_destination.mutation.graphql';
import addGroupEventTypeFiltersToDestination from './mutations/add_group_event_type_filters.mutation.graphql';
import addGroupNamespaceFiltersToDestination from './mutations/add_group_namespace_filters.mutation.graphql';
import deleteGroupEventTypeFiltersFromDestination from './mutations/delete_group_event_type_filters.mutation.graphql';
import deleteGroupNamespaceFiltersFromDestination from './mutations/delete_group_namespace_filters.mutation.graphql';
import updateInstanceStreamingDestination from './mutations/update_instance_streaming_destination.mutation.graphql';
import createInstanceStreamingDestination from './mutations/create_instance_streaming_destination.mutation.graphql';
import addInstanceEventTypeFiltersToDestination from './mutations/add_instance_event_type_filters.mutation.graphql';
import deleteInstanceEventTypeFiltersFromDestination from './mutations/delete_instance_event_type_filters.mutation.graphql';
import addInstanceNamespaceFiltersToDestination from './mutations/add_instance_namespace_filters.mutation.graphql';
import deleteInstanceNamespaceFiltersFromDestination from './mutations/delete_instance_namespace_filters.mutation.graphql';
import {
  addAuditEventsStreamingDestinationToCache,
  updateAuditEventsStreamingDestinationFromCache,
  updateEventTypeFiltersFromCache,
  setNamespaceFiltersInCache,
} from './cache_update_consolidated_api';

const getCategoryInGraphqlFormat = (category) => {
  switch (category) {
    case DESTINATION_TYPE_HTTP:
      return 'http';
    case DESTINATION_TYPE_GCP_LOGGING:
      return 'gcp';
    case DESTINATION_TYPE_AMAZON_S3:
      return 'aws';
    default:
      return category;
  }
};

const getCreatedEventTypeFiltersData = (data, isInstance) =>
  isInstance
    ? data.auditEventsInstanceDestinationEventsAdd
    : data.auditEventsGroupDestinationEventsAdd;

const getCreatedDestinationData = (data, isInstance) =>
  isInstance
    ? data.instanceAuditEventStreamingDestinationsCreate
    : data.groupAuditEventStreamingDestinationsCreate;

const addEventTypeFilters = async ({
  $apollo,
  destination,
  isInstance,
  eventTypeFiltersToAdd,
  fetchPolicy,
}) => {
  if (!eventTypeFiltersToAdd.length || !destination.id) {
    return [];
  }

  const variables = {
    destinationId: destination.id,
    eventTypeFilters: eventTypeFiltersToAdd,
  };

  const update = (cache, { data }) => {
    const { errors, eventTypeFilters } = getCreatedEventTypeFiltersData(data, isInstance);

    if (errors.length || fetchPolicy === 'no-cache') {
      return;
    }

    updateEventTypeFiltersFromCache({
      store: cache,
      isInstance,
      destinationId: destination.id,
      filters: eventTypeFilters,
    });
  };

  const { data } = await $apollo.mutate({
    mutation: isInstance
      ? addInstanceEventTypeFiltersToDestination
      : addGroupEventTypeFiltersToDestination,
    variables,
    fetchPolicy,
    update,
  });

  return getCreatedEventTypeFiltersData(data, isInstance).errors;
};

const removeEventTypeFilters = async ({
  $apollo,
  destination,
  isInstance,
  eventTypeFiltersToRemove,
}) => {
  if (!eventTypeFiltersToRemove.length || !destination.id) {
    return [];
  }

  const variables = {
    destinationId: destination.id,
    eventTypeFilters: eventTypeFiltersToRemove,
  };

  const { data } = await $apollo.mutate({
    mutation: isInstance
      ? deleteInstanceEventTypeFiltersFromDestination
      : deleteGroupEventTypeFiltersFromDestination,
    variables,
    fetchPolicy: 'no-cache',
    update: () => {},
  });

  return isInstance
    ? data.auditEventsInstanceDestinationEventsDelete.errors
    : data.auditEventsGroupDestinationEventsDelete.errors;
};

// Uses fetchPolicy: 'no-cache' so individual responses do not race each other when
// writing to the Apollo cache; callers do one bulk cache write after all calls resolve.
const addNamespaceFilters = async ({ $apollo, destinationId, isInstance, namespacePathsToAdd }) => {
  if (!namespacePathsToAdd.length || !destinationId) {
    return { errors: [], createdFilters: [] };
  }

  const mutation = isInstance
    ? addInstanceNamespaceFiltersToDestination
    : addGroupNamespaceFiltersToDestination;

  const mutationName = isInstance
    ? 'auditEventsInstanceDestinationNamespaceFilterCreate'
    : 'auditEventsGroupDestinationNamespaceFilterCreate';

  const addPromises = namespacePathsToAdd.map((namespacePath) =>
    $apollo.mutate({
      mutation,
      variables: { destinationId, namespacePath },
      fetchPolicy: 'no-cache',
      update: () => {},
    }),
  );

  const results = await Promise.all(addPromises);

  const errors = [];
  const createdFilters = [];

  results.forEach(({ data }) => {
    const payload = data[mutationName];
    errors.push(...payload.errors);
    if (payload.namespaceFilter) {
      createdFilters.push(payload.namespaceFilter);
    }
  });

  return { errors, createdFilters };
};

const removeNamespaceFilters = async ({ $apollo, isInstance, namespaceFiltersToRemove }) => {
  if (!namespaceFiltersToRemove.length) {
    return [];
  }

  const mutation = isInstance
    ? deleteInstanceNamespaceFiltersFromDestination
    : deleteGroupNamespaceFiltersFromDestination;

  const mutationName = isInstance
    ? 'auditEventsInstanceDestinationNamespaceFilterDelete'
    : 'auditEventsGroupDestinationNamespaceFilterDelete';

  const removeFiltersPromises = namespaceFiltersToRemove.map(async (namespaceFilter) => {
    const { data } = await $apollo.mutate({
      mutation,
      variables: { namespaceFilterId: namespaceFilter.id },
      fetchPolicy: 'no-cache',
      update: () => {},
    });

    return data[mutationName].errors;
  });

  const results = await Promise.all(removeFiltersPromises);

  return results.flat();
};

const executeCreateDestinationMutation = ({ $apollo, destination, isInstance, groupPath }) => {
  const update = (cache, { data }) => {
    if (getCreatedDestinationData(data, isInstance).errors.length) return;

    addAuditEventsStreamingDestinationToCache({
      store: cache,
      isInstance,
      fullPath: groupPath,
      newDestination: getCreatedDestinationData(data, isInstance).externalAuditEventDestination,
    });
  };

  const variables = {
    input: {
      name: destination.name,
      secretToken: destination.secretToken,
      category: getCategoryInGraphqlFormat(destination.category),
      config: {
        ...destination.config,
      },
      ...(isInstance ? {} : { groupPath }),
    },
  };

  return $apollo.mutate({
    mutation: isInstance ? createInstanceStreamingDestination : createGroupStreamingDestination,
    variables,
    update,
  });
};

export const createDestination = async ({
  $apollo,
  destination,
  isInstance,
  groupPath,
  eventTypeFiltersToAdd,
  namespacePathsToAdd = [],
}) => {
  const errors = [];
  const fetchPolicy = 'network-only';

  const { data } = await executeCreateDestinationMutation({
    $apollo,
    destination,
    isInstance,
    groupPath,
  });

  errors.push(...getCreatedDestinationData(data, isInstance).errors);

  if (errors.length) return { errors };

  const createdDestinationId = getCreatedDestinationData(data, isInstance)
    .externalAuditEventDestination.id;

  errors.push(
    ...(await addEventTypeFilters({
      $apollo,
      destination: { id: createdDestinationId },
      isInstance,
      eventTypeFiltersToAdd,
      fetchPolicy,
    })),
  );

  if (namespacePathsToAdd.length) {
    const { errors: addErrors, createdFilters } = await addNamespaceFilters({
      $apollo,
      destinationId: createdDestinationId,
      isInstance,
      namespacePathsToAdd,
    });
    errors.push(...addErrors);

    if (!addErrors.length && createdFilters.length) {
      setNamespaceFiltersInCache({
        store: $apollo.provider.defaultClient.cache,
        destinationId: createdDestinationId,
        filters: createdFilters,
        isInstance,
      });
    }
  }

  return { errors };
};

const getUpdatedDestinationData = (data, isInstance) =>
  isInstance
    ? data.instanceAuditEventStreamingDestinationsUpdate
    : data.groupAuditEventStreamingDestinationsUpdate;

const executeUpdateDestinationMutation = ({ $apollo, destination, isInstance }) => {
  const variables = {
    input: {
      id: destination.id,
      name: destination.name,
      config: {
        ...destination.config,
      },
      ...(destination.secretToken ? { secretToken: destination.secretToken } : {}),
    },
  };

  return $apollo.mutate({
    mutation: isInstance ? updateInstanceStreamingDestination : updateGroupStreamingDestination,
    variables,
    fetchPolicy: 'no-cache',
    update: () => {},
  });
};

// Namespace filter ordering is intentionally **add-first-then-remove** so that a partial
// failure mid-save leaves the destination "over-filtered" (safe for compliance) rather
// than briefly "unfiltered" (which would stream events without any namespace scoping).
// If any add fails, no removes are attempted.
export const updateDestination = async ({
  $apollo,
  destination,
  isInstance,
  eventTypeFiltersToAdd,
  eventTypeFiltersToRemove,
  namespacePathsToAdd = [],
  namespaceFiltersToRemove = [],
}) => {
  const errors = [];
  const fetchPolicy = 'no-cache';

  const { data } = await executeUpdateDestinationMutation({
    $apollo,
    destination,
    isInstance,
  });

  errors.push(...getUpdatedDestinationData(data, isInstance).errors);
  errors.push(
    ...(await removeEventTypeFilters({
      $apollo,
      destination,
      isInstance,
      eventTypeFiltersToRemove,
    })),
  );

  errors.push(
    ...(await addEventTypeFilters({
      $apollo,
      destination,
      isInstance,
      eventTypeFiltersToAdd,
      fetchPolicy,
    })),
  );

  // Namespace filters: add first; only remove if all adds succeeded.
  const { errors: addErrors, createdFilters } = await addNamespaceFilters({
    $apollo,
    destinationId: destination.id,
    isInstance,
    namespacePathsToAdd,
  });
  errors.push(...addErrors);

  let removalRan = false;
  if (!addErrors.length) {
    const removeErrors = await removeNamespaceFilters({
      $apollo,
      isInstance,
      namespaceFiltersToRemove,
    });
    errors.push(...removeErrors);
    removalRan = true;
  }

  if (errors.length) return { errors };

  const updatedData = {
    ...getUpdatedDestinationData(data, isInstance).externalAuditEventDestination,
    eventTypeFilters: JSON.parse(JSON.stringify(destination.eventTypeFilters)),
  };

  // Only update cache when namespace filters were actually changed.
  if (createdFilters.length || removalRan) {
    const removedIds = new Set(namespaceFiltersToRemove.map((f) => f.id));
    const survivors = (destination.originalNamespaceFilters || []).filter(
      (f) => !removedIds.has(f.id),
    );
    updatedData.namespaceFilters = [...survivors, ...createdFilters];
  }

  updateAuditEventsStreamingDestinationFromCache({
    store: $apollo.provider.defaultClient.cache,
    isInstance,
    updatedData,
  });

  return { errors };
};
