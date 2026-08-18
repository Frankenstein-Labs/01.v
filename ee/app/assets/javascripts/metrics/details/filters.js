import { omit } from 'lodash-es';
import {
  filterToQueryObject,
  urlQueryToFilter,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import {
  OPERERATOR_LIKE,
  OPERERATOR_NOT_LIKE,
  FILTERED_SEARCH_TERM_QUERY_KEY,
  DATE_RANGE_QUERY_KEY,
  DATE_RANGE_START_QUERY_KEY,
  DATE_RANGE_END_QUERY_KEY,
  CUSTOM_DATE_RANGE_OPTION,
} from '~/observability/constants';
import {
  dateFilterObjToQuery,
  queryToDateFilterObj,
  validatedDateRangeQuery,
} from '~/observability/utils';
import { queryToObject } from '~/lib/utils/url_utility';

const customOperators = [
  {
    operator: OPERERATOR_LIKE,
    prefix: 'like',
  },
  {
    operator: OPERERATOR_NOT_LIKE,
    prefix: 'not_like',
  },
];

const GROUP_BY_FN_QUERY_KEY = 'group_by_fn';
const GROUP_BY_ATTRIBUTES_QUERY_KEY = 'group_by_attrs';

export function filterObjToQuery(filters) {
  const attributes = filterToQueryObject(filters.attributes, {
    filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
    customOperators,
  });
  return {
    ...attributes,
    [GROUP_BY_FN_QUERY_KEY]: filters.groupBy?.func,
    [GROUP_BY_ATTRIBUTES_QUERY_KEY]: filters.groupBy?.attributes?.length
      ? filters.groupBy.attributes
      : undefined,
    ...dateFilterObjToQuery(filters.dateRange),
  };
}

function validatedGroupByAttributes(groupByAttributes = []) {
  const nonEmptyAttrs = groupByAttributes.filter((attr) => attr.length > 0);
  return nonEmptyAttrs.length > 0 ? nonEmptyAttrs : undefined;
}

export function queryToFilterObj(queryString) {
  const queryObj = queryToObject(queryString, { gatherArrays: true });
  const {
    [GROUP_BY_FN_QUERY_KEY]: groupByFn,
    [GROUP_BY_ATTRIBUTES_QUERY_KEY]: groupByAttributes,
    ...attributes
  } = omit(queryObj, [
    // not all query params are filters, so omitting them from the query object
    'type',
    DATE_RANGE_QUERY_KEY,
    DATE_RANGE_START_QUERY_KEY,
    DATE_RANGE_END_QUERY_KEY,
  ]);

  const attributesFilter = urlQueryToFilter(attributes, {
    filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
    customOperators,
  });

  return {
    attributes: attributesFilter,
    groupBy: {
      func: groupByFn,
      attributes: validatedGroupByAttributes(groupByAttributes),
    },
    dateRange: queryToDateFilterObj(queryObj),
  };
}

export function metricsDetailsQueryFromAttributes({ dateRange: { startDate, endDate } = {} }) {
  if (!startDate || !endDate) return {};
  return filterObjToQuery({
    dateRange: validatedDateRangeQuery(CUSTOM_DATE_RANGE_OPTION, startDate, endDate),
  });
}
