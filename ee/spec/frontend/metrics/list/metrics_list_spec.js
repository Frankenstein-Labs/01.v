import { GlLoadingIcon, GlInfiniteScroll, GlSprintf } from '@gitlab/ui';
import { filterObjToFilterToken } from 'ee/metrics/list/filters';
import MetricsTable from 'ee/metrics/list/metrics_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MetricsList from 'ee/metrics/list/metrics_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockClient } from 'helpers/mock_observability_client';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ObservabilityNoDataEmptyState from '~/observability/components/observability_no_data_empty_state.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { useFakeDate } from 'helpers/fake_date';
import { mockMetricsListResponse } from '../mock_data';

jest.mock('~/alert');

describe('MetricsComponent', () => {
  let wrapper;
  let observabilityClientMock;

  const mockResponse = { ...mockMetricsListResponse };
  const mockAvailableAttributes = [...mockMetricsListResponse.all_available_attributes];

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findInfiniteScrolling = () => wrapper.findComponent(GlInfiniteScroll);
  const findMetricsTable = () => wrapper.findComponent(MetricsTable);
  const findNoDataEmptyState = () => wrapper.findComponent(ObservabilityNoDataEmptyState);

  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const setFilters = async (filters) => {
    findFilteredSearchBar().vm.$emit('on-filter', filterObjToFilterToken(filters));
    await waitForPromises();
  };

  // eslint-disable-next-line no-console
  console.error = jest.fn();

  const mountComponent = async () => {
    wrapper = shallowMountExtended(MetricsList, {
      propsData: {
        observabilityClient: observabilityClientMock,
      },
      stubs: {
        GlSprintf,
      },
    });
    await waitForPromises();
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    observabilityClientMock = createMockClient();
    observabilityClientMock.fetchMetrics.mockResolvedValue(mockResponse);
  });

  it('tracks view_metrics_page', () => {
    mountComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    expect(trackEventSpy).toHaveBeenCalledWith('view_metrics_page', {}, undefined);
  });

  describe('initial metrics fetching', () => {
    it('renders the loading indicator and search bar while fetching metrics', () => {
      mountComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findFilteredSearchBar().exists()).toBe(true);
      expect(findInfiniteScrolling().exists()).toBe(false);
      expect(findNoDataEmptyState().exists()).toBe(false);

      expect(observabilityClientMock.fetchMetrics).toHaveBeenCalledWith({
        filters: { search: undefined },
        limit: 50,
      });
    });

    describe('when done', () => {
      beforeEach(async () => {
        await mountComponent();
      });
      it('does not render the loading indicator', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('renders the search bar', () => {
        expect(findFilteredSearchBar().exists()).toBe(true);
      });

      it('renders infinite scrolling list', () => {
        expect(findInfiniteScrolling().exists()).toBe(true);
        expect(findInfiniteScrolling().props('fetchedItems')).toBe(mockResponse.metrics.length);
        expect(
          findInfiniteScrolling().find('[data-testid="metrics-infinite-scrolling-legend"]').text(),
        ).toBe('');
      });

      it('renders the metrics table within the infinite-scrolling', () => {
        expect(findMetricsTable().exists()).toBe(true);
        expect(findNoDataEmptyState().exists()).toBe(false);
        expect(findMetricsTable().props('metrics')).toEqual(mockResponse.metrics);
      });

      it('renders the header', () => {
        expect(wrapper.findComponent(PageHeading).props('heading')).toBe('Metrics');
        expect(wrapper.find('header').text()).toBe(
          'Track health data from your systems. Send metric data to this project using OpenTelemetry. Learn more.',
        );
      });

      it('renders the empty state if no data is found', async () => {
        observabilityClientMock.fetchMetrics.mockResolvedValue({ metrics: [] });

        await mountComponent();

        expect(findNoDataEmptyState().exists()).toBe(true);
        expect(findMetricsTable().exists()).toBe(false);
      });
    });
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      setWindowLocation('?search=foo+bar&attribute[]=test.attr&traceId[]=test-trace-id');
      await mountComponent();
    });

    it('renders FilteredSeach with initial filters parsed from window.location', () => {
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(
        filterObjToFilterToken({
          search: [{ value: 'foo bar' }],
          attribute: [{ value: 'test.attr', operator: '=' }],
          traceId: [{ value: 'test-trace-id', operator: '=' }],
        }),
      );
    });

    it('renders FilteredSeach with Attribute token', () => {
      const token = findFilteredSearchBar()
        .props('tokens')
        .find(({ type }) => type === 'attribute');

      expect(token).toBeDefined();
      expect(token.options).toEqual(
        mockAvailableAttributes.map((attribute) => ({ title: attribute, value: attribute })),
      );
    });

    it('renders FilteredSeach with TraceId token', () => {
      const token = findFilteredSearchBar()
        .props('tokens')
        .find(({ type }) => type === 'trace-id');

      expect(token).toBeDefined();
      expect(token.unique).toBe(true);
    });

    it('renders UrlSync and sets query prop', () => {
      expect(findUrlSync().props('query')).toEqual({
        search: 'foo bar',
        attribute: ['test.attr'],
        'not[attribute]': null,
        traceId: ['test-trace-id'],
        'not[traceId]': null,
      });
    });

    it('fetches metrics with filters and limit', () => {
      expect(observabilityClientMock.fetchMetrics).toHaveBeenLastCalledWith({
        filters: {
          search: [{ value: 'foo bar' }],
          attribute: [{ value: 'test.attr', operator: '=' }],
          traceId: [{ value: 'test-trace-id', operator: '=' }],
        },
        limit: 50,
      });
    });

    describe('on search submit', () => {
      beforeEach(async () => {
        await setFilters({
          search: [{ value: 'search query' }],
          attribute: [{ value: 'updated.attr.filter', operator: '=' }],
          traceId: [{ value: 'updated-trace-id', operator: '=' }],
        });
      });

      it('hides the loading indicator when done', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findFilteredSearchBar().exists()).toBe(true);
        expect(findInfiniteScrolling().exists()).toBe(true);
        expect(findMetricsTable().exists()).toBe(true);
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toEqual({
          search: 'search query',
          attribute: ['updated.attr.filter'],
          'not[attribute]': null,
          traceId: ['updated-trace-id'],
          'not[traceId]': null,
        });
      });

      it('fetches metrics with updated filters', () => {
        expect(observabilityClientMock.fetchMetrics).toHaveBeenLastCalledWith({
          filters: {
            search: [{ value: 'search query' }],
            attribute: [{ value: 'updated.attr.filter', operator: '=' }],
            traceId: [{ value: 'updated-trace-id', operator: '=' }],
          },
          limit: 50,
        });
      });

      it('updates FilteredSearch initialFilters', () => {
        expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(
          filterObjToFilterToken({
            search: [{ value: 'search query' }],
            attribute: [{ value: 'updated.attr.filter', operator: '=' }],
            traceId: [{ value: 'updated-trace-id', operator: '=' }],
          }),
        );
      });
    });
  });

  describe('error handling', () => {
    it('if fetchMetrics fails, it renders an alert and empty state', async () => {
      observabilityClientMock.fetchMetrics.mockRejectedValue('error');
      await mountComponent();

      expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load metrics.' });
      expect(findMetricsTable().exists()).toBe(false);
      expect(findNoDataEmptyState().exists()).toBe(true);
    });
  });

  describe('on metric-clicked', () => {
    let visitUrlMock;

    const mockMetrics = mockMetricsListResponse.metrics;
    const mockMetricSelected = mockMetrics[0];

    beforeEach(async () => {
      setWindowLocation('http://test.host/projectX/-/metrics?search=query');
      visitUrlMock = jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});

      await mountComponent();
    });

    it('redirects to the details url', () => {
      findMetricsTable().vm.$emit('metric-clicked', { metricId: mockMetricSelected.name });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith(
        `http://test.host/projectX/-/metrics/${mockMetricSelected.name}?type=${mockMetricSelected.type}`,
        false,
      );
    });

    it('opens a new tab if clicked with meta key', () => {
      findMetricsTable().vm.$emit('metric-clicked', {
        metricId: mockMetricSelected.name,
        clickEvent: { metaKey: true },
      });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith(
        `http://test.host/projectX/-/metrics/${mockMetricSelected.name}?type=${mockMetricSelected.type}`,
        true,
      );
    });

    it('does not redirect if metric type cannot be found', () => {
      findMetricsTable().vm.$emit('metric-clicked', {
        metricId: 'unknown-metric',
      });
      expect(visitUrlMock).not.toHaveBeenCalled();
    });

    describe('when the selected metric has timestamp_of_datapoint_with_traceId', () => {
      useFakeDate('2024-08-29 11:00:00');

      beforeEach(async () => {
        const mockTimestampOfDatapointNano = Date.now() * 1e6;
        observabilityClientMock.fetchMetrics.mockResolvedValue({
          metrics: [
            {
              ...mockMetrics[0],
              timestamp_of_datapoint_with_traceId: mockTimestampOfDatapointNano,
            },
          ],
          all_available_attributes: mockAvailableAttributes,
        });

        await mountComponent();

        findMetricsTable().vm.$emit('metric-clicked', { metricId: mockMetrics[0].name });
      });

      it('redirects to the details url and sets the date range interval to be 1min around the datapoint', () => {
        expect(visitUrlMock).toHaveBeenCalledWith(
          `http://test.host/projectX/-/metrics/${mockMetricSelected.name}?type=${mockMetricSelected.type}&date_range=custom&date_start=2024-08-29T10%3A59%3A00.000Z&date_end=2024-08-29T11%3A01%3A00.000Z`,
          false,
        );
      });
    });
  });
});
