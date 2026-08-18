import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';
import {
  mapWidgetsFromFeatures as ceMapWidgetsFromFeatures,
  mapFeaturesFromRestResponse as ceMapFeaturesFromRestResponse,
  mapWorkItemToGraphQL as ceMapWorkItemToGraphQL,
  nullWorkItemFeatures as ceNullWorkItemFeatures,
  parsePageInfo,
  isGroupNamespace,
} from '~/work_items/list/graphql/rest/work_items_rest_resolver';
import { convertGraphQLVarsToRestParams } from './rest_filter_params_mapper';

const GROUPS_PATH = '/api/:version/groups/:full_path/-/work_items';
const NAMESPACES_PATH = '/api/:version/namespaces/:full_path/-/work_items';

const REST_HEALTH_STATUS_TO_GRAPHQL = {
  on_track: 'onTrack',
  needs_attention: 'needsAttention',
  at_risk: 'atRisk',
};

function mapStatusFeature(features) {
  const status = features?.status?.status;
  return {
    __typename: 'WorkItemWidgetStatus',
    status: status
      ? {
          id: status.id,
          name: status.name,
          category: status.category,
          color: status.color,
          description: status.description,
          iconName: status.icon_name,
          position: status.position,
          __typename: 'WorkItemStatus',
        }
      : null,
  };
}

function mapHealthStatusFeature(features) {
  const healthStatus = features?.health_status?.health_status;
  return {
    __typename: 'WorkItemWidgetHealthStatus',
    healthStatus: healthStatus
      ? (REST_HEALTH_STATUS_TO_GRAPHQL[healthStatus] ?? healthStatus)
      : null,
  };
}

function mapWeightFeature(features) {
  const weight = features?.weight?.weight;
  return {
    __typename: 'WorkItemWidgetWeight',
    weight: weight ?? null,
  };
}

function mapIterationFeature(features) {
  const iteration = features?.iteration?.iteration;
  return {
    __typename: 'WorkItemWidgetIteration',
    iteration: iteration
      ? {
          id: iteration.id ? `gid://gitlab/Iteration/${iteration.id}` : null,
          title: iteration.title,
          startDate: iteration.start_date ?? null,
          dueDate: iteration.due_date ?? null,
          webUrl: iteration.web_url ?? null, // eslint-disable-line local-rules/no-web-url
          iterationCadence: iteration.iteration_cadence
            ? {
                id: iteration.iteration_cadence.id
                  ? `gid://gitlab/Iterations::Cadence/${iteration.iteration_cadence.id}`
                  : null,
                title: iteration.iteration_cadence.title,
                __typename: 'IterationCadence',
              }
            : null,
          __typename: 'Iteration',
        }
      : null,
  };
}

function mapLinkedItemsFeature(features) {
  const linkedItemsData = features?.linked_items;
  return {
    __typename: 'WorkItemWidgetLinkedItems',
    blockingCount: linkedItemsData?.blocking_count ?? 0,
    blockedByCount: linkedItemsData?.blocked_by_count ?? 0,
  };
}

// REST leaves out feature keys the type doesn't support, so only map what it sends. Mapping a
// missing key gives an empty but truthy widget, and the cache policies merge, so it survives the
// detail query. Keyed by REST name to keep `widgets[]` and `features` in sync.
const EE_FEATURES = [
  { restKey: 'status', graphQLKey: 'status', widgetType: 'STATUS', map: mapStatusFeature },
  {
    restKey: 'health_status',
    graphQLKey: 'healthStatus',
    widgetType: 'HEALTH_STATUS',
    map: mapHealthStatusFeature,
  },
  { restKey: 'weight', graphQLKey: 'weight', widgetType: 'WEIGHT', map: mapWeightFeature },
  {
    restKey: 'iteration',
    graphQLKey: 'iteration',
    widgetType: 'ITERATION',
    map: mapIterationFeature,
  },
  {
    restKey: 'linked_items',
    graphQLKey: 'linkedItems',
    widgetType: 'LINKED_ITEMS',
    map: mapLinkedItemsFeature,
  },
];

function mapEEWidgetsFromFeatures(features) {
  return EE_FEATURES.filter(({ restKey }) => features?.[restKey]).map(({ widgetType, map }) => ({
    ...map(features),
    type: widgetType,
  }));
}

function mapWidgetsFromFeatures(features, itemNamespace) {
  const ceWidgets = ceMapWidgetsFromFeatures(features, itemNamespace);
  const eeWidgets = mapEEWidgetsFromFeatures(features);

  return [...ceWidgets, ...eeWidgets];
}

function mapEEFeaturesFromRestResponse(features) {
  return Object.fromEntries(
    EE_FEATURES.map(({ restKey, graphQLKey, map }) => [
      graphQLKey,
      features?.[restKey] ? map(features) : null,
    ]),
  );
}

function mapFeaturesFromRestResponse(features, itemNamespace) {
  return {
    ...ceMapFeaturesFromRestResponse(features, itemNamespace),
    ...mapEEFeaturesFromRestResponse(features),
  };
}

// See the CE counterpart for rationale. Adds EE-only feature placeholders so the GraphQL
// selection set on features is satisfied when the work_item_features_field flag is off
function nullWorkItemFeatures() {
  return {
    ...ceNullWorkItemFeatures(),
    status: null,
    healthStatus: null,
    weight: null,
    iteration: null,
    linkedItems: null,
  };
}

function mapWorkItemToGraphQL(item, sharedNamespace, { useWorkItemFeatures = false } = {}) {
  const ceWorkItem = ceMapWorkItemToGraphQL(item, sharedNamespace, { useWorkItemFeatures });
  const itemNamespace = ceWorkItem.namespace;

  return {
    ...ceWorkItem,
    widgets: mapWidgetsFromFeatures(item.features, itemNamespace),
    features: useWorkItemFeatures
      ? mapFeaturesFromRestResponse(item.features, itemNamespace)
      : nullWorkItemFeatures(),
  };
}

export async function workItemsRestResolver(namespace, args) {
  const { fullPath } = namespace;

  const restParams = convertGraphQLVarsToRestParams(args);

  restParams.set(
    'fields',
    'id,iid,global_id,title,title_html,state,created_at,updated_at,closed_at,reference,web_path,web_url,author,work_item_type,confidential,hidden,user_discussions_count,namespace',
  );
  restParams.set(
    'features',
    'labels,assignees,milestone,start_and_due_date,status,health_status,weight,iteration,hierarchy,linked_items,award_emoji,development',
  );

  const pathTemplate = isGroupNamespace(namespace) ? GROUPS_PATH : NAMESPACES_PATH;
  const url = buildApiUrl(pathTemplate).replace(':full_path', encodeURIComponent(fullPath));

  let response;
  try {
    response = await axios.get(url, { params: restParams });
  } catch (error) {
    Sentry.captureException(error);
    throw error;
  }

  const useWorkItemFeatures = Boolean(window.gon?.features?.workItemFeaturesField);
  const nodes = (response.data ?? []).map((item) =>
    mapWorkItemToGraphQL(item, namespace, { useWorkItemFeatures }),
  );
  const pageInfo = parsePageInfo(response.headers);
  return {
    __typename: 'WorkItemConnection',
    pageInfo,
    nodes,
  };
}
