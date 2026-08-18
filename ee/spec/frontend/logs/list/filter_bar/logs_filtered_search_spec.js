import { nextTick } from 'vue';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LogsFilteredSeach from 'ee/logs/list/filter_bar/logs_filtered_search.vue';
import { filterObjToFilterToken } from 'ee/logs/list/filter_bar/filters';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

describe('LogsFilteredSeach', () => {
  let wrapper;

  const defaultProps = {
    dateRangeFilter: {
      endDate: new Date('2020-07-06T00:00:00.000Z'),
      startDarte: new Date('2020-07-05T23:00:00.000Z'),
      value: '1h',
    },
    attributesFilters: {
      service: [{ operator: '=', value: 'serviceName' }],
      severityName: [{ operator: '!=', value: 'warning' }],
    },
  };

  const mount = (props = defaultProps) => {
    wrapper = shallowMountExtended(LogsFilteredSeach, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    mount();
  });

  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);

  describe('search hints', () => {
    const findToken = (type) =>
      findFilteredSearchBar()
        .props('tokens')
        .find((t) => t.type === type);

    describe.each([undefined, {}])('when no metadata is provided', (metadata) => {
      beforeEach(() => {
        mount({ ...defaultProps, searchMetadata: metadata });
      });
      it('set default severity options', () => {
        expect(findToken('severity-name').options.map((o) => o.value)).toEqual([
          'trace',
          'trace2',
          'trace3',
          'trace4',
          'debug',
          'debug2',
          'debug3',
          'debug4',
          'info',
          'info2',
          'info3',
          'info4',
          'warn',
          'warn2',
          'warn3',
          'warn4',
          'error',
          'error2',
          'error3',
          'error4',
          'fatal',
          'fatal2',
          'fatal3',
          'fatal4',
        ]);
      });

      it('sets no suggestions for the service token', () => {
        expect(findToken('service-name').options).toEqual([]);
      });

      it('sets no suggestions for the trace-flags token', () => {
        expect(findToken('trace-flags').options).toEqual([]);
      });
    });

    describe('when search metadata is provided', () => {
      beforeEach(() => {
        mount({
          ...defaultProps,
          searchMetadata: {
            severity_names: ['info', 'warn'],
            service_names: ['service1', 'service2'],
            trace_flags: ['trace1', 'trace2'],
          },
        });
      });

      it('set default severity options', () => {
        expect(findToken('severity-name').options.map((o) => o.value)).toEqual(['info', 'warn']);
      });

      it('sets no suggestions for the service token', () => {
        expect(findToken('service-name').options.map((o) => o.value)).toEqual([
          'service1',
          'service2',
        ]);
      });

      it('sets no suggestions for the trace-flags token', () => {
        expect(findToken('trace-flags').options.map((o) => o.value)).toEqual(['trace1', 'trace2']);
      });
    });
  });

  describe('date range filter', () => {
    it('renders the date range filter', () => {
      expect(findDateRangeFilter().exists()).toBe(true);
    });

    it('sets the selected date range', () => {
      expect(findDateRangeFilter().props('selected')).toEqual(defaultProps.dateRangeFilter);
    });

    it('emits the filter event when the date range is changed', async () => {
      const dateRange = {
        value: '24h',
        startDate: new Date('2022-01-01'),
        endDate: new Date('2022-01-02'),
      };

      findDateRangeFilter().vm.$emit('on-date-range-selected', dateRange);
      await nextTick();

      expect(wrapper.emitted('filter')).toEqual([
        [
          {
            dateRange,
            attributes: expect.any(Object),
          },
        ],
      ]);
      expect(findDateRangeFilter().props('selected')).toEqual(dateRange);
    });
  });

  describe('attributes filters', () => {
    it('renders the FilteredSearch', () => {
      expect(findFilteredSearchBar().exists()).toBe(true);
    });

    it('sets the initial attributes filter by converting it to tokens', () => {
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(
        filterObjToFilterToken(defaultProps.attributesFilters),
      );
    });

    it('emits the filter event when the search is submitted', async () => {
      const filterObj = {
        search: [{ value: 'some-search' }],
        fingerprint: [{ operator: '=', value: 'fingerprint' }],
      };

      const filterTokens = filterObjToFilterToken(filterObj);

      findFilteredSearchBar().vm.$emit('on-filter', filterTokens);
      await nextTick();

      expect(wrapper.emitted('filter')).toEqual([
        [
          {
            dateRange: expect.any(Object),
            attributes: filterObj,
          },
        ],
      ]);
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(filterTokens);
    });
  });
});
