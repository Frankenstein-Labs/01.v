import { newDate } from '~/lib/utils/datetime_utility';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import {
  buildDefaultDashboardFilters,
  dateRangeOptionToFilter,
  filtersToQueryParams,
  getDateRangeOption,
  isDashboardFilterEnabled,
} from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTIONS,
  DATE_RANGE_OPTION_CUSTOM,
  DATE_RANGE_OPTION_TODAY,
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTION_LAST_90_DAYS,
  DEFAULT_SELECTED_DATE_RANGE_OPTION,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  mockDateRangeFilterChangePayload,
  mockFilteredSearchChangePayload,
  mockFilteredSearchEmptyQueryObj,
  mockFilteredSearchQueryObj,
} from '../../mock_data';

const option = DATE_RANGE_OPTIONS[DEFAULT_SELECTED_DATE_RANGE_OPTION];
describe('buildDefaultDashboardFilters', () => {
  const dateRangeFilter = { dateRange: { enabled: true } };
  const defaultOption = DATE_RANGE_OPTIONS[DEFAULT_SELECTED_DATE_RANGE_OPTION];

  it('returns the default filters for an empty query string', () => {
    expect(buildDefaultDashboardFilters('')).toStrictEqual({
      filterAnonUsers: false,
      searchFilters: {},
      projects: [],
    });
  });

  it('returns the default date range option for an empty query string with date range filter enabled', () => {
    expect(buildDefaultDashboardFilters('', dateRangeFilter)).toStrictEqual({
      startDate: defaultOption.startDate,
      endDate: defaultOption.endDate,
      dateRangeOption: defaultOption.key,
      filterAnonUsers: false,
      searchFilters: {},
      projects: [],
    });
  });

  it('returns the date range option that matches the date_range_option', () => {
    const queryString = `date_range_option=${option.key}`;

    expect(buildDefaultDashboardFilters(queryString, dateRangeFilter)).toStrictEqual({
      startDate: option.startDate,
      endDate: option.endDate,
      dateRangeOption: option.key,
      filterAnonUsers: false,
      searchFilters: {},
      projects: [],
    });
  });

  it('returns a custom range when the query string is custom and contains dates', () => {
    const queryString = `date_range_option=${DATE_RANGE_OPTION_CUSTOM}&start_date=2023-01-10&end_date=2023-02-08`;

    expect(buildDefaultDashboardFilters(queryString, dateRangeFilter)).toStrictEqual({
      startDate: newDate('2023-01-10'),
      endDate: newDate('2023-02-08'),
      dateRangeOption: DATE_RANGE_OPTION_CUSTOM,
      filterAnonUsers: false,
      searchFilters: {},
      projects: [],
    });
  });

  it('returns the date range option that matches the date_range_option and ignores the query dates when the option is not custom', () => {
    const queryString = `date_range_option=${option.key}&start_date=2023-01-10&end_date=2023-02-08`;

    expect(buildDefaultDashboardFilters(queryString, dateRangeFilter)).toStrictEqual({
      startDate: option.startDate,
      endDate: option.endDate,
      dateRangeOption: option.key,
      filterAnonUsers: false,
      searchFilters: {},
      projects: [],
    });
  });

  it('returns "filterAnonUsers=true" when the query param for filtering out anonymous users is true', () => {
    const queryString = 'filter_anon_users=true';

    expect(buildDefaultDashboardFilters(queryString)).toMatchObject({
      filterAnonUsers: true,
    });
  });

  it('returns the projectFullPath filter when project param is present', () => {
    const queryString = 'projects[]=foo&projects[]=bar';

    expect(buildDefaultDashboardFilters(queryString)).toMatchObject({
      projects: ['foo', 'bar'],
    });
  });

  it('returns populated `searchFilters` object when filtered search params are present in query string', () => {
    const queryString = `${TOKEN_TYPE_LABEL}[]=Afterpod&${TOKEN_TYPE_MILESTONE}[]=Any&${TOKEN_TYPE_AUTHOR}[]=root&${TOKEN_TYPE_ASSIGNEE}[]=root&not%5B${TOKEN_TYPE_ASSIGNEE}%5D[]=vsm-user-1-1737989060&fake_param=hello`;

    expect(buildDefaultDashboardFilters(queryString)).toStrictEqual({
      filterAnonUsers: false,
      searchFilters: mockFilteredSearchChangePayload,
      projects: [],
    });
  });

  describe('with dashboardDefaultFilters', () => {
    const selectedDateRangeOption = DATE_RANGE_OPTION_LAST_90_DAYS;
    const dashboardDefaultFilters = {
      dateRange: {
        enabled: true,
        defaultOption: selectedDateRangeOption,
      },
    };

    it('uses the dashboardDefaultFilters.dateRange if there is no queryString', () => {
      expect(buildDefaultDashboardFilters('', dashboardDefaultFilters)).toStrictEqual({
        startDate: newDate('2020-04-07'),
        endDate: defaultOption.endDate,
        filterAnonUsers: false,
        dateRangeOption: selectedDateRangeOption,
        searchFilters: {},
        projects: [],
      });
    });

    it('returns the option that matches the date_range_option', () => {
      const queryString = `date_range_option=${option.key}`;

      expect(buildDefaultDashboardFilters(queryString, dashboardDefaultFilters)).toStrictEqual({
        startDate: option.startDate,
        endDate: option.endDate,
        dateRangeOption: option.key,
        filterAnonUsers: false,
        searchFilters: {},
        projects: [],
      });
    });
  });
});

describe('filtersToQueryParams', () => {
  const customOption = {
    ...mockDateRangeFilterChangePayload,
    dateRangeOption: DATE_RANGE_OPTION_CUSTOM,
  };

  const nonCustomOption = {
    ...mockDateRangeFilterChangePayload,
    dateRangeOption: 'foobar',
  };

  it('returns the dateRangeOption with null date params when the option is not custom', () => {
    expect(filtersToQueryParams(nonCustomOption)).toStrictEqual({
      date_range_option: 'foobar',
      end_date: null,
      start_date: null,
      filter_anon_users: null,
      projects: [],
    });
  });

  it('returns the dateRangeOption and date params when the option is custom', () => {
    expect(filtersToQueryParams(customOption)).toStrictEqual({
      date_range_option: DATE_RANGE_OPTION_CUSTOM,
      start_date: '2016-01-01',
      end_date: '2016-02-01',
      filter_anon_users: null,
      projects: [],
    });
  });

  it('returns "filter_anon_users=true" when filtering out anonymous users', () => {
    expect(filtersToQueryParams({ filterAnonUsers: true })).toMatchObject({
      filter_anon_users: true,
    });
  });

  it('returns filtered search params when search filters are present', () => {
    expect(filtersToQueryParams({ searchFilters: mockFilteredSearchChangePayload })).toStrictEqual({
      date_range_option: undefined,
      start_date: null,
      end_date: null,
      filter_anon_users: null,
      projects: [],
      ...mockFilteredSearchEmptyQueryObj,
      ...mockFilteredSearchQueryObj,
    });
  });

  it('return the project param when project filter is present', () => {
    expect(filtersToQueryParams({ projects: ['project/path'] })).toMatchObject({
      projects: ['project/path'],
    });
  });
});

describe('getDateRangeOption', () => {
  it('should return the date range option', () => {
    expect(getDateRangeOption(option.key)).toStrictEqual(option);
  });
});

describe('dateRangeOptionToFilter', () => {
  it('filters data by `name` for the provided search term', () => {
    expect(dateRangeOptionToFilter(option)).toStrictEqual({
      startDate: option.startDate,
      endDate: option.endDate,
      dateRangeOption: option.key,
    });
  });
});

describe('isDashboardFilterEnabled', () => {
  it('should return true when the filter is enabled', () => {
    expect(isDashboardFilterEnabled({ enabled: true })).toBe(true);
  });

  it('should return false when the filter is disabled', () => {
    expect(isDashboardFilterEnabled({ enabled: false })).toBe(false);
  });

  it('should return false when the filter object is empty', () => {
    const emptyFilter = {};
    expect(isDashboardFilterEnabled(emptyFilter)).toBe(false);
  });

  it('should return false when the filter is null or undefined', () => {
    expect(isDashboardFilterEnabled(null)).toBe(false);
    expect(isDashboardFilterEnabled(undefined)).toBe(false);
  });
});

describe('getDateRange', () => {
  it('will return the date range when valid', () => {
    expect(getDateRange(DATE_RANGE_OPTION_TODAY).key).toBe('today');
  });

  it('will return the default option when the date range is invalid', () => {
    expect(getDateRange('15d').key).toBe('7d');
  });

  it('can override the default date range', () => {
    expect(getDateRange('15d', DATE_RANGE_OPTION_LAST_30_DAYS).key).toBe('30d');
  });
});
