import { GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import TracingAnalytics from 'ee/tracing/list/tracing_analytics.vue';
import FilteredSearch from 'ee/tracing/list/filter_bar/tracing_filtered_search.vue';
import TracingTableList from 'ee/tracing/list/tracing_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingList from 'ee/tracing/list/tracing_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockClient } from 'helpers/mock_observability_client';
import * as commonUtils from '~/lib/utils/common_utils';
import axios from '~/lib/utils/axios_utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ObservabilityNoDataEmptyState from '~/observability/components/observability_no_data_empty_state.vue';

jest.mock('~/lib/utils/axios_utils');

jest.mock('~/alert');

describe('TracingList', () => {
  let wrapper;
  let observabilityClientMock;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTableList = () => wrapper.findComponent(TracingTableList);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const findTracesCountLegend = () => wrapper.findByTestId('tracing-count-legend');
  const findLoadMoreButton = () => wrapper.findComponentByTestId('load-more-button');
  const findAnalytics = () => wrapper.findComponent(TracingAnalytics);
  const findNoDataEmptyState = () => wrapper.findComponent(ObservabilityNoDataEmptyState);
  const loadMore = async () => {
    findLoadMoreButton().vm.$emit('click');
    await waitForPromises();
  };

  const setFilters = async (filters) => {
    findFilteredSearch().vm.$emit('filter', filters);
    await waitForPromises();
  };

  const mockResponse = {
    traces: [{ trace_id: 'trace1' }, { trace_id: 'trace2' }],
    next_page_token: 'page-2',
  };

  const mockAnalytics = [
    {
      interval: 1706456580,
      count: 272,
      p90_duration_nano: 79431434,
      p95_duration_nano: 172512624,
      p75_duration_nano: 33666014,
      p50_duration_nano: 13540992,
      trace_rate: 4.533333333333333,
    },
    {
      interval: 1706456640,
      count: 322,
      p90_duration_nano: 245701137,
      p95_duration_nano: 410402110,
      p75_duration_nano: 126097516,
      p50_duration_nano: 26955796,
      trace_rate: 5.366666666666666,
    },
  ];

  const mountComponent = async () => {
    wrapper = shallowMountExtended(TracingList, {
      propsData: {
        observabilityClient: observabilityClientMock,
      },
      stubs: {
        GlSprintf,
      },
    });
    await waitForPromises();
  };

  beforeEach(() => {
    observabilityClientMock = createMockClient();

    observabilityClientMock.fetchTraces.mockResolvedValue(mockResponse);
    observabilityClientMock.fetchTracesAnalytics.mockResolvedValue(mockAnalytics);
  });

  describe('trace list', () => {
    describe('while fetching traces', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(async () => {
        observabilityClientMock.fetchTraces.mockReturnValue(new Promise(() => {}));

        await mountComponent();
      });

      it('tracks view_tracing_page', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).toHaveBeenCalledWith('view_tracing_page', {}, undefined);
      });

      it('fetches traces', () => {
        expect(observabilityClientMock.fetchTraces).toHaveBeenCalled();
      });

      it('renders the loading icon while fetching traces', () => {
        expect(findLoadingIcon().exists()).toBe(true);
        expect(findTableList().exists()).toBe(false);
        expect(findNoDataEmptyState().exists()).toBe(false);
        expect(findFilteredSearch().exists()).toBe(true);
        expect(findLoadMoreButton().exists()).toBe(false);
      });
    });

    describe('when fetching traces completes', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTraces.mockResolvedValue(mockResponse);

        await mountComponent();
      });
      it('renders the trace list with filtered search', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findTableList().exists()).toBe(true);
        expect(findFilteredSearch().exists()).toBe(true);
        expect(findUrlSync().exists()).toBe(true);
        expect(findNoDataEmptyState().exists()).toBe(false);
        expect(findTableList().props('traces')).toEqual(mockResponse.traces);
        expect(findLoadMoreButton().exists()).toBe(true);
      });

      it('renders the header', () => {
        expect(wrapper.findComponent(PageHeading).props('heading')).toBe('Tracing');
        expect(wrapper.find('header').text()).toBe(
          'Inspect application requests across services. Send trace data to this project using OpenTelemetry. Learn more.',
        );
      });

      it('renders the empty state if no data is found', async () => {
        observabilityClientMock.fetchTraces.mockResolvedValue({ traces: [] });

        await mountComponent();

        expect(findNoDataEmptyState().exists()).toBe(true);
        expect(findTableList().exists()).toBe(false);
      });

      it('does not render the footer if no data is found', async () => {
        observabilityClientMock.fetchTraces.mockResolvedValue({ traces: [] });

        await mountComponent();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findTracesCountLegend().exists()).toBe(false);
        expect(findLoadMoreButton().exists()).toBe(false);
      });
    });
  });

  describe('analytics', () => {
    describe('while fetching analytics', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTracesAnalytics.mockReturnValue(new Promise(() => {}));
        await mountComponent();
      });

      it('fetches analytics', () => {
        expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenCalled();
      });

      it('sets loading prop while fetching analytics', () => {
        expect(findAnalytics().exists()).toBe(true);
        expect(findAnalytics().props('loading')).toBe(true);
      });
    });

    describe('when fetching analytics is done', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTracesAnalytics.mockResolvedValue(mockAnalytics);

        await mountComponent();
      });
      it('renders the analytics component', () => {
        expect(findAnalytics().exists()).toBe(true);
        expect(findAnalytics().props('analytics')).toEqual(mockAnalytics);
        expect(findAnalytics().props('loading')).toBe(false);
      });
    });

    describe('chart height', () => {
      const mountWithSize = (contentTop, innerHeight) => {
        jest.spyOn(commonUtils, 'contentTop').mockReturnValue(contentTop);
        window.innerHeight = innerHeight;
      };
      it('sets the chart height to 20% of the container height', async () => {
        mountWithSize(200, 1000);

        await mountComponent();

        expect(findAnalytics().props('chartHeight')).toBe(160);
      });

      it('sets the min height to 100px', async () => {
        mountWithSize(20, 200);

        await mountComponent();

        expect(findAnalytics().props('chartHeight')).toBe(100);
      });

      it('resize the chart on window resize', async () => {
        mountWithSize(200, 1000);

        await mountComponent();

        expect(findAnalytics().props('chartHeight')).toBe(160);

        jest.spyOn(commonUtils, 'contentTop').mockReturnValue(200);
        window.innerHeight = 800;
        window.dispatchEvent(new Event('resize'));

        await nextTick();

        expect(findAnalytics().props('chartHeight')).toBe(120);
      });
    });
  });

  describe('on trace-clicked', () => {
    let visitUrlMock;
    beforeEach(async () => {
      setWindowLocation('base_path');
      visitUrlMock = jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});

      await mountComponent();
    });

    it('redirects to the details url', () => {
      findTableList().vm.$emit('trace-clicked', { traceId: 'test-trace-id' });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith('/base_path/test-trace-id', false);
    });

    it('opens a new tab if clicked with meta key', () => {
      findTableList().vm.$emit('trace-clicked', {
        traceId: 'test-trace-id',
        clickEvent: { metaKey: true },
      });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith('/base_path/test-trace-id', true);
    });
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      setWindowLocation(
        '?sortBy=duration_desc' +
          '&date_range=custom' +
          '&date_end=2020-01-02T00%3A00%3A00.000Z' +
          '&date_start=2020-01-01T00%3A00%3A00.000Z' +
          '&status[]=ok' +
          '&service[]=loadgenerator' +
          '&service[]=test-service' +
          '&operation[]=test-op' +
          '&trace_id[]=test_trace&' +
          'gt%5BdurationMs%5D[]=100' +
          '&attribute[]=foo%3Dbar',
      );
      await mountComponent();
    });
    const attributesFilterObj = {
      service: [
        { operator: '=', value: 'loadgenerator' },
        { operator: '=', value: 'test-service' },
      ],
      operation: [{ operator: '=', value: 'test-op' }],
      traceId: [{ operator: '=', value: 'test_trace' }],
      durationMs: [{ operator: '>', value: '100' }],
      attribute: [{ operator: '=', value: 'foo=bar' }],
      status: [{ operator: '=', value: 'ok' }],
    };

    it('sets the client prop', () => {
      expect(findFilteredSearch().props('observabilityClient')).toBe(observabilityClientMock);
    });

    it('initialises filtered-search props with values from query', () => {
      expect(findFilteredSearch().props('attributesFilters')).toEqual(attributesFilterObj);
      expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
        endDate: new Date('2020-01-02T00:00:00.000Z'),
        startDate: new Date('2020-01-01T00:00:00.000Z'),
        value: 'custom',
      });
      expect(findFilteredSearch().props('initialSort')).toBe('duration_desc');
    });

    it('sets FilteredSearch initialSort the default sort order if not specified in the query', async () => {
      setWindowLocation('?');
      await mountComponent();

      expect(findFilteredSearch().props('initialSort')).toBe('timestamp_desc');
    });

    it('renders UrlSync and sets query prop', () => {
      expect(findUrlSync().props('query')).toEqual({
        attribute: ['foo=bar'],
        durationMs: null,
        'filtered-search-term': null,
        'gt[durationMs]': ['100'],
        'lt[durationMs]': null,
        'not[attribute]': null,
        'not[durationMs]': null,
        'not[filtered-search-term]': null,
        'not[operation]': null,
        'not[service]': null,
        'not[trace_id]': null,
        'not[status]': null,
        operation: ['test-op'],
        status: ['ok'],
        service: ['loadgenerator', 'test-service'],
        sortBy: 'duration_desc',
        trace_id: ['test_trace'],
        date_range: 'custom',
        date_end: '2020-01-02T00:00:00.000Z',
        date_start: '2020-01-01T00:00:00.000Z',
      });
    });

    describe('if no date range is provided', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTraces.mockClear();
        observabilityClientMock.fetchTracesAnalytics.mockClear();
        setWindowLocation('?sortBy=duration_desc');

        await mountComponent();
      });

      it('sets data-range-filter prop to the default date range', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({ value: '1h' });
      });

      it('fetches data with default time range filter', () => {
        const filters = {
          dateRange: {
            value: '1h',
          },
          attributes: {},
        };
        expect(observabilityClientMock.fetchTraces).toHaveBeenCalledWith({
          filters,
          pageSize: 50,
          pageToken: null,
          sortBy: 'duration_desc',
          abortController: expect.any(AbortController),
        });
        expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenCalledWith({
          filters,
          abortController: expect.any(AbortController),
        });
      });
    });

    it('fetches traces and analytics with options', () => {
      const expectedFilters = {
        attributes: attributesFilterObj,
        dateRange: {
          value: 'custom',
          startDate: new Date('2020-01-01'),
          endDate: new Date('2020-01-02'),
        },
      };
      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          ...expectedFilters,
        },
        pageSize: 50,
        pageToken: null,
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });
      expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenLastCalledWith({
        filters: {
          ...expectedFilters,
        },
        abortController: expect.any(AbortController),
      });
    });

    describe('on search submit', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTracesAnalytics.mockReset();
        observabilityClientMock.fetchTracesAnalytics.mockReturnValue(mockAnalytics);
        await setFilters({
          attributes: {
            service: [{ operator: '=', value: 'frontend' }],
            operation: [{ operator: '=', value: 'op' }],
            traceId: [{ operator: '=', value: 'another_trace' }],
            durationMs: [{ operator: '>', value: '200' }],
            attribute: [{ operator: '=', value: 'foo=baz' }],
            status: [{ operator: '=', value: 'error' }],
          },
          dateRange: {
            value: '7d',
          },
        });
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toEqual({
          attribute: ['foo=baz'],
          durationMs: null,
          'filtered-search-term': null,
          'gt[durationMs]': ['200'],
          'lt[durationMs]': null,
          'not[attribute]': null,
          'not[durationMs]': null,
          'not[filtered-search-term]': null,
          'not[operation]': null,
          'not[service]': null,
          'not[trace_id]': null,
          'not[status]': null,
          operation: ['op'],
          service: ['frontend'],
          sortBy: 'duration_desc',
          trace_id: ['another_trace'],
          status: ['error'],
          date_end: undefined,
          date_range: '7d',
          date_start: undefined,
        });
      });

      it('fetches traces and analytics with updated filters', () => {
        const expectedFilters = {
          attributes: {
            service: [{ operator: '=', value: 'frontend' }],
            operation: [{ operator: '=', value: 'op' }],
            traceId: [{ operator: '=', value: 'another_trace' }],
            durationMs: [{ operator: '>', value: '200' }],
            attribute: [{ operator: '=', value: 'foo=baz' }],
            status: [{ operator: '=', value: 'error' }],
          },
          dateRange: {
            value: '7d',
          },
        };
        expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
          filters: {
            ...expectedFilters,
          },
          pageSize: 50,
          pageToken: null,
          sortBy: 'duration_desc',
          abortController: expect.any(AbortController),
        });

        expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenLastCalledWith({
          filters: {
            ...expectedFilters,
          },
          abortController: expect.any(AbortController),
        });
      });

      it('updates the filtered search props', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({ value: '7d' });
        expect(findFilteredSearch().props('attributesFilters')).toEqual({
          service: [{ operator: '=', value: 'frontend' }],
          operation: [{ operator: '=', value: 'op' }],
          traceId: [{ operator: '=', value: 'another_trace' }],
          durationMs: [{ operator: '>', value: '200' }],
          attribute: [{ operator: '=', value: 'foo=baz' }],
          status: [{ operator: '=', value: 'error' }],
        });
      });
    });

    describe('cancelling pending requests', () => {
      let abortSpy;
      beforeEach(async () => {
        axios.isCancel = jest.fn().mockReturnValue(true);
        abortSpy = jest.spyOn(AbortController.prototype, 'abort');

        observabilityClientMock.fetchTracesAnalytics.mockReturnValue(new Promise(() => {}));
        observabilityClientMock.fetchTraces.mockReturnValue(new Promise(() => {}));

        await mountComponent();
      });

      it('cancels pending requests', async () => {
        expect(abortSpy).not.toHaveBeenCalled();

        await setFilters({});

        // cancel fetchTraces and fetchAnalytics
        expect(abortSpy).toHaveBeenCalledTimes(2);
      });

      it('does not show any alert', async () => {
        observabilityClientMock.fetchTraces.mockRejectedValue('cancelled');
        observabilityClientMock.fetchTracesAnalytics.mockRejectedValue('cancelled');

        await setFilters({});

        expect(createAlert).not.toHaveBeenCalled();
      });

      it('does not hide the loading indicators', async () => {
        await setFilters({});

        expect(findLoadingIcon().exists()).toBe(true);
        expect(findAnalytics().props('loading')).toBe(true);
      });
    });

    describe('on sort order changed', () => {
      beforeEach(async () => {
        setWindowLocation('?sortBy=duration_desc');
        await mountComponent();

        observabilityClientMock.fetchTracesAnalytics.mockReset();

        findFilteredSearch().vm.$emit('sort', 'timestamp_asc');
        await waitForPromises();
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toMatchObject({
          sortBy: 'timestamp_asc',
        });
      });

      it('fetches traces with new sort order', () => {
        expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
          filters: { attributes: {}, dateRange: { value: '1h' } },
          pageSize: 50,
          pageToken: null,
          sortBy: 'timestamp_asc',
          abortController: expect.any(AbortController),
        });
      });

      it('does not fetch analytics', () => {
        expect(observabilityClientMock.fetchTracesAnalytics).not.toHaveBeenCalled();
      });

      it('updates FilteredSearch initial sort', () => {
        expect(findFilteredSearch().props('initialSort')).toEqual('timestamp_asc');
      });
    });
  });

  describe('load more / pagination', () => {
    beforeEach(async () => {
      setWindowLocation('?date_range=12h&service[]=loadgenerator&sortBy=duration_desc');
      await mountComponent();
    });

    it('renders the list with a load more button', () => {
      expect(findTableList().exists()).toBe(true);
      expect(findTableList().props('traces')).toEqual(mockResponse.traces);
      expect(findLoadMoreButton().exists()).toBe(true);
    });

    it('fetches the next page when the load more button is clicked', async () => {
      const nextPageResponse = {
        traces: [{ trace_id: 'trace-3' }],
        next_page_token: 'page-3',
      };
      observabilityClientMock.fetchTraces.mockReturnValueOnce(nextPageResponse);

      await loadMore();

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          attributes: {
            attribute: undefined,
            durationMs: undefined,
            operation: undefined,
            search: undefined,
            service: [{ operator: '=', value: 'loadgenerator' }],
            traceId: undefined,
          },
          dateRange: {
            value: '12h',
          },
        },
        pageSize: 50,
        pageToken: 'page-2',
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });

      expect(findTableList().props('traces')).toEqual([
        ...mockResponse.traces,
        ...nextPageResponse.traces,
      ]);
    });

    it('does not fetch analytics when the load more button is clicked', async () => {
      observabilityClientMock.fetchTracesAnalytics.mockReset();

      await loadMore();

      expect(observabilityClientMock.fetchTracesAnalytics).not.toHaveBeenCalled();
      expect(findAnalytics().exists()).toBe(true);
    });

    it('hides the load more button after reaching the last page', async () => {
      observabilityClientMock.fetchTraces.mockReturnValue({
        traces: [],
      });

      await loadMore();

      expect(observabilityClientMock.fetchTraces).toHaveBeenCalledTimes(2);
      expect(findLoadMoreButton().exists()).toBe(false);
    });

    it('shows the number of fetched items as the legend', () => {
      expect(findTracesCountLegend().text()).toBe(`Showing ${mockResponse.traces.length} traces`);
    });

    it('shows the loading icon and hides the button while fetching the next page', async () => {
      findLoadMoreButton().vm.$emit('click');
      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTracesCountLegend().exists()).toBe(false);
      expect(findLoadMoreButton().exists()).toBe(false);
    });

    it('when filters change, pagination and traces are reset', async () => {
      observabilityClientMock.fetchTraces.mockReturnValueOnce({
        traces: [{ trace_id: 'trace-3' }],
        next_page_token: 'page-3',
      });
      await loadMore();

      await setFilters({ durationMs: [{ operator: '>', value: '100' }] });

      const expectedFilters = {
        attribute: undefined,
        durationMs: [{ operator: '>', value: '100' }],
        operation: undefined,
        search: undefined,
        service: undefined,
        traceId: undefined,
      };

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: { ...expectedFilters },
        pageSize: 50,
        pageToken: null,
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });
      expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenCalledWith({
        filters: { ...expectedFilters },
        abortController: expect.any(AbortController),
      });

      expect(findTableList().props('traces')).toEqual(mockResponse.traces);
    });

    it('when sort order is changed, pagination and traces are reset', async () => {
      observabilityClientMock.fetchTracesAnalytics.mockReset();
      observabilityClientMock.fetchTraces.mockReturnValueOnce({
        traces: [{ trace_id: 'trace-3' }],
        next_page_token: 'page-3',
      });
      await loadMore();

      findFilteredSearch().vm.$emit('sort', 'duration_asc');
      await waitForPromises();

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          attributes: {
            attribute: undefined,
            durationMs: undefined,
            operation: undefined,
            search: undefined,
            service: [{ operator: '=', value: 'loadgenerator' }],
            traceId: undefined,
          },
          dateRange: {
            value: '12h',
          },
        },
        pageSize: 50,
        pageToken: null,
        sortBy: 'duration_asc',
        abortController: expect.any(AbortController),
      });
      expect(observabilityClientMock.fetchTracesAnalytics).not.toHaveBeenCalled();

      expect(findTableList().props('traces')).toEqual(mockResponse.traces);
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      axios.isCancel = jest.fn().mockReturnValue(false);
    });
    it('if fetchTraces fails, it renders the empty state with an alert', async () => {
      observabilityClientMock.fetchTraces.mockRejectedValue('error');

      await mountComponent();

      expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load traces.' });
      expect(findTableList().exists()).toBe(false);
      expect(findNoDataEmptyState().exists()).toBe(true);
      expect(findAnalytics().exists()).toBe(true);
    });

    it('if fetchTracesAnalytics fails, it renders an alert', async () => {
      observabilityClientMock.fetchTracesAnalytics.mockRejectedValue('error');

      await mountComponent();

      expect(createAlert).toHaveBeenLastCalledWith({
        message: 'Failed to load tracing analytics.',
      });
    });
  });
});
