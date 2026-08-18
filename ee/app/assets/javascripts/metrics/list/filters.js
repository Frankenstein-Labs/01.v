import {
  filterToQueryObject,
  urlQueryToFilter,
  prepareTokens,
  processFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { FILTERED_SEARCH_TERM_QUERY_KEY } from '~/observability/constants';

export const ATTRIBUTE_FILTER_TOKEN_TYPE = 'attribute';
export const TRACE_ID_FILTER_TOKEN_TYPE = 'trace-id';

export function queryToFilterObj(queryString) {
  const filter = urlQueryToFilter(queryString, {
    filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
  });
  const { attribute, traceId } = filter;
  const search = filter[FILTERED_SEARCH_TERM];
  return {
    attribute,
    search,
    traceId,
  };
}

export function filterObjToQuery(filters) {
  return filterToQueryObject(
    {
      [FILTERED_SEARCH_TERM]: filters.search,
      attribute: filters.attribute,
      traceId: filters.traceId,
    },
    {
      filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
    },
  );
}

export function filterObjToFilterToken(filters) {
  return prepareTokens({
    [FILTERED_SEARCH_TERM]: filters.search,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.attribute,
    [TRACE_ID_FILTER_TOKEN_TYPE]: filters.traceId,
  });
}

export function filterTokensToFilterObj(tokens) {
  const {
    [FILTERED_SEARCH_TERM]: search,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: attribute,
    [TRACE_ID_FILTER_TOKEN_TYPE]: traceId,
  } = processFilters(tokens);

  return {
    search,
    attribute,
    traceId,
  };
}

export function metricsListQueryFromAttributes({ traceId }) {
  return filterObjToQuery({
    traceId: traceId ? [{ value: traceId, operator: '=' }] : undefined,
  });
}
