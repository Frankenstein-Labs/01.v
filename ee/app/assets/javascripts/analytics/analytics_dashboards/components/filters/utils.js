import { queryToObject } from '~/lib/utils/url_utility';
import { formatDate, newDate } from '~/lib/utils/datetime_utility';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import {
  convertObjectPropsToCamelCase,
  convertObjectPropsToSnakeCase,
  parseBoolean,
} from '~/lib/utils/common_utils';
import {
  filterToQueryObject,
  urlQueryToFilter,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import {
  dateRangeOptionToFilter,
  getDateRangeOption,
} from '~/explore/analytics_dashboards/components/utils';
import {
  DATE_RANGE_OPTIONS,
  DATE_RANGE_OPTION_CUSTOM,
  DATE_RANGE_OPTION_KEYS,
  DEFAULT_SELECTED_DATE_RANGE_OPTION,
  FILTERED_SEARCH_SUPPORTED_TOKENS,
  PROJECT_FILTER_QUERY_NAME,
} from './constants';

const isCustomOption = (option) => option && option === DATE_RANGE_OPTION_CUSTOM;

export { dateRangeOptionToFilter, getDateRangeOption };

const DEFAULT_FILTER = dateRangeOptionToFilter(
  DATE_RANGE_OPTIONS[DEFAULT_SELECTED_DATE_RANGE_OPTION],
);

export const buildDefaultDashboardFilters = (queryString, dashboardDefaultFilters = {}) => {
  const {
    dateRangeOption,
    startDate,
    endDate,
    filterAnonUsers,
    [PROJECT_FILTER_QUERY_NAME]: projects = [],
  } = convertObjectPropsToCamelCase(queryToObject(queryString, { gatherArrays: true }));
  const searchFilters = urlQueryToFilter(queryString, {
    filterNamesAllowList: FILTERED_SEARCH_SUPPORTED_TOKENS,
  });

  const isDateRangeFilterEnabled = dashboardDefaultFilters?.dateRange?.enabled;
  const optionKey = dateRangeOption || dashboardDefaultFilters?.dateRange?.defaultOption;
  const dateRangeOverride = DATE_RANGE_OPTION_KEYS.includes(optionKey)
    ? dateRangeOptionToFilter(getDateRangeOption(optionKey))
    : {};

  const customDateRange = isCustomOption(optionKey);

  return {
    ...(isDateRangeFilterEnabled && {
      ...DEFAULT_FILTER,
      // Override default filter with user defined option
      ...dateRangeOverride,
      // Override date range when selected option is custom date range
      ...(customDateRange && { startDate: newDate(startDate) }),
      ...(customDateRange && { endDate: newDate(endDate) }),
    }),
    filterAnonUsers: parseBoolean(filterAnonUsers),
    searchFilters,
    projects,
  };
};

export const filtersToQueryParams = ({
  dateRangeOption,
  startDate,
  endDate,
  filterAnonUsers,
  searchFilters,
  projects,
}) => {
  const customDateRange = isCustomOption(dateRangeOption);

  const searchFiltersQueryObj = filterToQueryObject(searchFilters);
  const additionalFiltersQueryObj = convertObjectPropsToSnakeCase({
    dateRangeOption,
    // Clear the date range unless the custom date range is selected
    startDate: customDateRange ? formatDate(startDate, ISO_SHORT_FORMAT) : null,
    endDate: customDateRange ? formatDate(endDate, ISO_SHORT_FORMAT) : null,
    // Clear the anon users filter unless truthy
    filterAnonUsers: filterAnonUsers || null,
    [PROJECT_FILTER_QUERY_NAME]: projects || [],
  });

  return { ...additionalFiltersQueryObj, ...searchFiltersQueryObj };
};

export function isDashboardFilterEnabled(filter) {
  return filter?.enabled || false;
}
