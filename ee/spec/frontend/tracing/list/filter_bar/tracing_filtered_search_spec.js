import { nextTick } from 'vue';
import { GlAlert } from '@gitlab/ui';
import OperationToken from 'ee/tracing/list/filter_bar/operation_search_token.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceToken from 'ee/tracing/list/filter_bar/service_search_token.vue';
import AttributeSearchToken from 'ee/tracing/list/filter_bar/attribute_search_token.vue';
import TracingListFilteredSearch from 'ee/tracing/list/filter_bar/tracing_filtered_search.vue';
import TracingBaseSearchToken from 'ee/tracing/list/filter_bar/tracing_base_search_token.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { filterObjToFilterToken, PERIOD_FILTER_OPTIONS } from 'ee/tracing/list/filter_bar/filters';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { useFakeDate } from 'helpers/fake_date';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';

describe('TracingListFilteredSearch', () => {
  let wrapper;
  let observabilityClientMock;

  const defaultProps = {
    dateRangeFilter: {
      endDate: new Date('2020-07-06T00:00:00.000Z'),
      startDarte: new Date('2020-07-05T23:00:00.000Z'),
      value: '1h',
    },
    attributesFilters: {
      service: [{ operator: '=', value: 'example-service' }],
    },
    initialSort: 'duration_desc',
  };

  // June 7thth, 2024
  useFakeDate(2024, 5, 7);

  beforeEach(() => {
    observabilityClientMock = createMockClient();

    wrapper = shallowMountExtended(TracingListFilteredSearch, {
      propsData: {
        ...defaultProps,
        observabilityClient: observabilityClientMock,
      },
    });
  });

  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const getTokens = () => findFilteredSearchBar().props('tokens');

  describe('date range filter', () => {
    it('initialise the date range filter', () => {
      expect(findDateRangeFilter().exists()).toBe(true);

      expect(findDateRangeFilter().props('selected')).toEqual(defaultProps.dateRangeFilter);
      expect(findDateRangeFilter().props('maxDateRange')).toEqual(2);
      expect(findDateRangeFilter().props('dateOptions')).toEqual(PERIOD_FILTER_OPTIONS);
      expect(findDateRangeFilter().props('defaultMinDate')).toEqual(new Date('2024-05-08'));
    });

    it('emits the filter event when the date range is changed', async () => {
      const dateRange = {
        value: '5m',
      };

      await findDateRangeFilter().vm.$emit('on-date-range-selected', dateRange);

      expect(findAlert().exists()).toBe(false);
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

    it('sets the dateTimeRangePickerState prop to true', () => {
      expect(findDateRangeFilter().props('dateTimeRangePickerState')).toBe(true);
    });

    describe('if date range is larger than 12h', () => {
      beforeEach(async () => {
        await findDateRangeFilter().vm.$emit('on-date-range-selected', {
          value: 'custom',
          startDate: new Date('2022-01-01'),
          endDate: new Date('2022-01-02'),
        });
      });
      it('does not emit a filter event', () => {
        expect(wrapper.emitted('filter')).toBeUndefined();
      });

      it('shows an alert and does not emi', () => {
        expect(findAlert().exists()).toBe(true);
      });

      it('clears the alert when selecting a correct date range', async () => {
        await findDateRangeFilter().vm.$emit('on-date-range-selected', {
          value: 'custom',
          startDate: new Date('2022-01-01'),
          endDate: new Date('2022-01-01T01:00:00'),
        });

        expect(findAlert().exists()).toBe(false);
        expect(wrapper.emitted('filter')).toHaveLength(1);
      });

      it('sets the dateTimeRangePickerState prop to false', () => {
        expect(findDateRangeFilter().props('dateTimeRangePickerState')).toBe(false);
      });
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
        service: [{ operator: '=', value: 'some-service' }],
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

  describe('sorting', () => {
    it('sets initialSortBy prop correctly', () => {
      expect(findFilteredSearchBar().props('initialSortBy')).toBe(wrapper.props('initialSort'));
    });

    it('emits sort event on-sort', () => {
      findFilteredSearchBar().vm.$emit('on-sort', 'duration_desc');

      expect(wrapper.emitted('sort')).toStrictEqual([['duration_desc']]);
    });
  });

  describe('tokens', () => {
    it('configure the attribute token', () => {
      const tokens = getTokens();
      const attributeToken = tokens.find((t) => t.type === 'attribute');
      expect(attributeToken.token).toBe(AttributeSearchToken);
    });

    it('configure the service token', () => {
      const tokens = getTokens();
      const serviceToken = tokens.find((t) => t.type === 'service-name');
      expect(serviceToken.token).toBe(ServiceToken);
      expect(serviceToken.fetchServices).toBe(observabilityClientMock.fetchServices);
    });

    it('configure the operation token', () => {
      const tokens = getTokens();
      const operationToken = tokens.find((t) => t.type === 'operation');
      expect(operationToken.token).toBe(OperationToken);
      expect(operationToken.fetchOperations).toBe(observabilityClientMock.fetchOperations);
    });

    it('configure the trace-id token', () => {
      const tokens = getTokens();
      expect(tokens.find((t) => t.type === 'trace-id').token).toBe(BaseToken);
    });

    it('configure the status token', () => {
      const tokens = getTokens();
      expect(tokens.find((t) => t.type === 'status').token).toBe(TracingBaseSearchToken);
    });

    it('configure the duration token', () => {
      const tokens = getTokens();
      expect(tokens.find((t) => t.type === 'duration-ms').token).toBe(TracingBaseSearchToken);
    });
  });
});
