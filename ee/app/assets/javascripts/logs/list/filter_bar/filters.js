import {
  prepareTokens,
  processFilters,
  filterToQueryObject,
  urlQueryToFilter,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { queryToObject } from '~/lib/utils/url_utility';
import { dateFilterObjToQuery, queryToDateFilterObj } from '~/observability/utils';
import { FILTERED_SEARCH_TERM_QUERY_KEY } from '~/observability/constants';

export const SERVICE_NAME_FILTER_TOKEN_TYPE = 'service-name';
export const SEVERITY_NAME_FILTER_TOKEN_TYPE = 'severity-name';
export const SEVERITY_NUMBER_FILTER_TOKEN_TYPE = 'severity-number';
export const TRACE_ID_FILTER_TOKEN_TYPE = 'trace-id';
export const SPAN_ID_FILTER_TOKEN_TYPE = 'span-id';
export const FINGERPRINT_FILTER_TOKEN_TYPE = 'fingerprint';
export const TRACE_FLAGS_FILTER_TOKEN_TYPE = 'trace-flags';
export const ATTRIBUTE_FILTER_TOKEN_TYPE = 'attribute';
export const RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE = 'resource-attribute';

export function filterObjToFilterToken(filters) {
  return prepareTokens({
    [SERVICE_NAME_FILTER_TOKEN_TYPE]: filters.service,
    [SEVERITY_NAME_FILTER_TOKEN_TYPE]: filters.severityName,
    [SEVERITY_NUMBER_FILTER_TOKEN_TYPE]: filters.severityNumber,
    [TRACE_ID_FILTER_TOKEN_TYPE]: filters.traceId,
    [SPAN_ID_FILTER_TOKEN_TYPE]: filters.spanId,
    [FINGERPRINT_FILTER_TOKEN_TYPE]: filters.fingerprint,
    [TRACE_FLAGS_FILTER_TOKEN_TYPE]: filters.traceFlags,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.attribute,
    [RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.resourceAttribute,
    [FILTERED_SEARCH_TERM]: filters.search,
  });
}

export function filterTokensToFilterObj(tokens) {
  const {
    [FILTERED_SEARCH_TERM]: search,
    [SERVICE_NAME_FILTER_TOKEN_TYPE]: service,
    [SEVERITY_NAME_FILTER_TOKEN_TYPE]: severityName,
    [SEVERITY_NUMBER_FILTER_TOKEN_TYPE]: severityNumber,
    [TRACE_ID_FILTER_TOKEN_TYPE]: traceId,
    [SPAN_ID_FILTER_TOKEN_TYPE]: spanId,
    [FINGERPRINT_FILTER_TOKEN_TYPE]: fingerprint,
    [TRACE_FLAGS_FILTER_TOKEN_TYPE]: traceFlags,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: attribute,
    [RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE]: resourceAttribute,
  } = processFilters(tokens);

  return {
    search,
    service,
    severityName,
    severityNumber,
    traceId,
    spanId,
    fingerprint,
    traceFlags,
    attribute,
    resourceAttribute,
  };
}

export function queryToFilterObj(queryString) {
  const queryObj = queryToObject(queryString, { gatherArrays: true });
  const filters = urlQueryToFilter(queryObj, {
    filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
  });

  const {
    service,
    severityName,
    severityNumber,
    traceId,
    spanId,
    fingerprint,
    traceFlags,
    attribute,
    resourceAttribute,
    [FILTERED_SEARCH_TERM]: search,
  } = filters;

  return {
    attributes: {
      search,
      service,
      severityName,
      severityNumber,
      traceId,
      spanId,
      fingerprint,
      traceFlags,
      attribute,
      resourceAttribute,
    },
    dateRange: queryToDateFilterObj(queryObj),
  };
}

export function filterObjToQuery({ attributes, dateRange }) {
  const attributesFilters = attributes
    ? filterToQueryObject(
        {
          service: attributes.service,
          severityName: attributes.severityName,
          severityNumber: attributes.severityNumber,
          traceId: attributes.traceId,
          spanId: attributes.spanId,
          fingerprint: attributes.fingerprint,
          traceFlags: attributes.traceFlags,
          attribute: attributes.attribute,
          resourceAttribute: attributes.resourceAttribute,
          [FILTERED_SEARCH_TERM]: attributes.search || [{ value: '' }], // reset the search query param if missing
        },
        {
          filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
        },
      )
    : {};
  return {
    ...attributesFilters,
    ...dateFilterObjToQuery(dateRange),
  };
}

export function logsQueryFromAttributes({
  traceId,
  spanId,
  service,
  severityNumber,
  fingerprint,
  timestamp,
  dateRange,
}) {
  const attributes = {
    traceId: traceId ? [{ value: traceId, operator: '=' }] : undefined,
    spanId: spanId ? [{ value: spanId, operator: '=' }] : undefined,
    service: service ? [{ value: service, operator: '=' }] : undefined,
    severityNumber: severityNumber ? [{ value: severityNumber, operator: '=' }] : undefined,
    fingerprint: fingerprint ? [{ value: fingerprint, operator: '=' }] : undefined,
  };
  const dateRangeValue = timestamp
    ? {
        timestamp,
      }
    : dateRange;
  return filterObjToQuery({
    attributes,
    dateRange: dateRangeValue,
  });
}

export function selectedLogQueryObject(selectedLog) {
  return logsQueryFromAttributes({
    traceId: selectedLog.trace_id,
    fingerprint: selectedLog.fingerprint,
    severityNumber: selectedLog.severity_number,
    service: selectedLog.service_name,
    timestamp: selectedLog.timestamp,
  });
}
