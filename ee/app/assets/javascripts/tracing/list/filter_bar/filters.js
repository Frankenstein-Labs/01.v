import {
  filterToQueryObject,
  urlQueryToFilter,
  prepareTokens,
  processFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TIME_RANGE_OPTIONS_VALUES,
  TIME_RANGE_OPTIONS,
  CUSTOM_DATE_RANGE_OPTION,
} from '~/observability/constants';
import {
  dateFilterObjToQuery,
  queryToDateFilterObj,
  validatedDateRangeQuery,
} from '~/observability/utils';
import { queryToObject } from '~/lib/utils/url_utility';

export const SERVICE_NAME_FILTER_TOKEN_TYPE = 'service-name';
export const OPERATION_FILTER_TOKEN_TYPE = 'operation';
export const TRACE_ID_FILTER_TOKEN_TYPE = 'trace-id';
export const DURATION_MS_FILTER_TOKEN_TYPE = 'duration-ms';
export const ATTRIBUTE_FILTER_TOKEN_TYPE = 'attribute';
export const STATUS_FILTER_TOKEN_TYPE = 'status';

const TIME_OPTIONS = [
  TIME_RANGE_OPTIONS_VALUES.FIVE_MIN,
  TIME_RANGE_OPTIONS_VALUES.FIFTEEN_MIN,
  TIME_RANGE_OPTIONS_VALUES.THIRTY_MIN,
  TIME_RANGE_OPTIONS_VALUES.ONE_HOUR,
  TIME_RANGE_OPTIONS_VALUES.FOUR_HOURS,
  TIME_RANGE_OPTIONS_VALUES.TWELVE_HOURS,
];

const isValidPeriodValue = (value) => TIME_OPTIONS.includes(value);

export const PERIOD_FILTER_OPTIONS = TIME_RANGE_OPTIONS.filter(({ value }) =>
  isValidPeriodValue(value),
);

export const MAX_PERIOD_DAYS = 7;

export function queryToFilterObj(queryString) {
  const queryObj = queryToObject(queryString, { gatherArrays: true });
  const filter = urlQueryToFilter(queryObj, {
    filteredSearchTermKey: 'search',
    customOperators: [
      {
        operator: '>',
        prefix: 'gt',
      },
      {
        operator: '<',
        prefix: 'lt',
      },
    ],
  });
  const {
    service = undefined,
    operation = undefined,
    trace_id: traceId = undefined,
    durationMs = undefined,
    attribute = undefined,
    status = undefined,
  } = filter;
  const search = filter[FILTERED_SEARCH_TERM];
  return {
    attributes: {
      service,
      operation,
      traceId,
      durationMs,
      search,
      attribute,
      status,
    },
    dateRange: queryToDateFilterObj(queryObj),
  };
}

export function filterObjToQuery({ attributes, dateRange }) {
  const attributesFilters = attributes
    ? filterToQueryObject(
        {
          service: attributes.service,
          operation: attributes.operation,
          trace_id: attributes.traceId,
          durationMs: attributes.durationMs,
          attribute: attributes.attribute,
          status: attributes.status,
          [FILTERED_SEARCH_TERM]: attributes.search,
        },
        {
          filteredSearchTermKey: 'search',
          customOperators: [
            {
              operator: '>',
              prefix: 'gt',
              applyOnlyToKey: 'durationMs',
            },
            {
              operator: '<',
              prefix: 'lt',
              applyOnlyToKey: 'durationMs',
            },
          ],
        },
      )
    : {};
  return {
    ...attributesFilters,
    ...dateFilterObjToQuery(dateRange),
  };
}

export function filterObjToFilterToken(filters) {
  return prepareTokens({
    [SERVICE_NAME_FILTER_TOKEN_TYPE]: filters.service,
    [OPERATION_FILTER_TOKEN_TYPE]: filters.operation,
    [TRACE_ID_FILTER_TOKEN_TYPE]: filters.traceId,
    [DURATION_MS_FILTER_TOKEN_TYPE]: filters.durationMs,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.attribute,
    [FILTERED_SEARCH_TERM]: filters.search,
    [STATUS_FILTER_TOKEN_TYPE]: filters.status,
  });
}

export function filterTokensToFilterObj(tokens) {
  const {
    [SERVICE_NAME_FILTER_TOKEN_TYPE]: service,
    [OPERATION_FILTER_TOKEN_TYPE]: operation,
    [TRACE_ID_FILTER_TOKEN_TYPE]: traceId,
    [DURATION_MS_FILTER_TOKEN_TYPE]: durationMs,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: attribute,
    [FILTERED_SEARCH_TERM]: search,
    [STATUS_FILTER_TOKEN_TYPE]: status,
  } = processFilters(tokens);

  return {
    service,
    operation,
    traceId,
    durationMs,
    attribute,
    search,
    status,
  };
}

export function tracingListQueryFromAttributes({ startTimestamp, endTimestamp, traceIds = [] }) {
  return filterObjToQuery({
    attributes: {
      traceId: traceIds.map((traceId) => ({ value: traceId, operator: '=' })),
    },
    dateRange: validatedDateRangeQuery(CUSTOM_DATE_RANGE_OPTION, startTimestamp, endTimestamp),
  });
}
