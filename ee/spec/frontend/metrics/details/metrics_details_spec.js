import { GlLoadingIcon, GlEmptyState, GlSprintf, GlButton } from '@gitlab/ui';
import MetricsDetails from 'ee/metrics/details/metrics_details.vue';
import RelatedTraces from 'ee/metrics/details/related_traces.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import MetricsLineChart from 'ee/metrics/details/metrics_line_chart.vue';
import MetricsHeatmap from 'ee/metrics/details/metrics_heatmap.vue';
import FilteredSearch from 'ee/metrics/details/filter_bar/metrics_filtered_search.vue';
import RelatedIssuesProvider from 'ee/metrics/details/related_issues/related_issues_provider.vue';
import { ingestedAtTimeAgo } from 'ee/metrics/utils';
import * as metricsDetailsUtils from 'ee/metrics/details/utils';
import { prepareTokens } from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import axios from '~/lib/utils/axios_utils';
import setWindowLocation from 'helpers/set_window_location_helper';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RelatedIssue from '~/observability/components/observability_related_issues.vue';
import { stubComponent } from 'helpers/stub_component';
import { helpPagePath } from '~/helpers/help_page_helper';
import RelatedIssuesBadge from '~/observability/components/related_issues_badge.vue';
import { uploadMetricsSnapshot } from 'ee/metrics/details/metrics_snapshot';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { logError } from '~/lib/logger';

jest.mock('ee/metrics/details/metrics_snapshot');

jest.mock('~/alert');
jest.mock('~/lib/utils/axios_utils');
jest.mock('ee/metrics/utils');
jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('MetricsDetails', () => {
  let wrapper;
  let observabilityClientMock;

  const metricId = 'test.metric';
  const metricType = 'Sum';
  const metricsIndexUrl = 'https://www.gitlab.com/flightjs/Flight/-/metrics';
  const createIssueUrl = 'https://www.gitlab.com/flightjs/Flight/-/issues/new';
  const tracingIndexUrl = 'https://www.gitlab.com/flightjs/Flight/-/tracing';
  const projectFullPath = 'test/project';
  const projectId = 1234;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMetricDetails = () => wrapper.findByTestId('metric-details');
  const findHeader = () => wrapper.findComponent(PageHeading);
  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const findChart = () => wrapper.findComponent(`[data-testid="metric-chart"]`);
  const findEmptyState = () => findMetricDetails().findComponent(GlEmptyState);
  const findFilteredSearch = () => findMetricDetails().findComponent(FilteredSearch);
  const findRelatedIssues = () => wrapper.findComponent(RelatedIssue);
  const findRelatedIssuesProvider = () => wrapper.findComponent(RelatedIssuesProvider);
  const findRelatedIssuesBadge = () => wrapper.findComponent(RelatedIssuesBadge);
  const findRelatedTraces = () => wrapper.findComponent(RelatedTraces);

  const setFilters = async (attributes, dateRange, groupBy) => {
    findFilteredSearch().vm.$emit('submit', {
      attributes: prepareTokens(attributes),
      dateRange,
      groupBy,
    });
    await waitForPromises();
  };

  const defaultProps = {
    metricId,
    metricType,
    metricsIndexUrl,
    createIssueUrl,
    projectFullPath,
    tracingIndexUrl,
    projectId,
  };

  const showToast = jest.fn();

  const mountComponent = async (props = {}, stubs = {}) => {
    wrapper = shallowMountExtended(MetricsDetails, {
      mocks: {
        $toast: {
          show: showToast,
        },
      },
      propsData: {
        ...defaultProps,
        ...props,
        observabilityClient: observabilityClientMock,
      },
      stubs: {
        GlSprintf,
        MetricsHeatMap: stubComponent(MetricsHeatmap, {
          template: `<div ref="chartComponent"><div ref="chart"></div></div>`,
        }),
        MetricsLineChart: stubComponent(MetricsLineChart, {
          template: `<div ref="chartComponent"><div ref="chart"></div></div>`,
        }),
        RelatedIssuesProvider: stubComponent(RelatedIssuesProvider, {
          template: `<div>
            <slot :issues="[]" :loading="false" :error="null" />
          </div>`,
        }),
        ...stubs,
      },
    });
    await waitForPromises();
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    setWindowLocation('?type=Sum');

    jest.spyOn(urlUtility, 'isValidURL').mockReturnValue(true);

    ingestedAtTimeAgo.mockReturnValue('3 days ago');

    jest.spyOn(metricsDetailsUtils, 'metricHasRelatedTraces').mockReturnValue(true);

    observabilityClientMock = createMockClient();
  });

  it('tracks view_metrics_details_page', () => {
    mountComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    expect(trackEventSpy).toHaveBeenCalledWith('view_metrics_details_page', {}, undefined);
  });

  const mockMetricData = [
    {
      name: 'container_cpu_usage_seconds_total',
      type: 'Gauge',
      unit: 'gb',
      attributes: {
        beta_kubernetes_io_arch: 'amd64',
        beta_kubernetes_io_instance_type: 'n1-standard-4',
        beta_kubernetes_io_os: 'linux',
        env: 'production',
      },
      values: [
        [1700118610000, 0.25595267476015443],
        [1700118660000, 0.1881374588830907],
        [1700118720000, 0.28915416028993485],
      ],
    },
  ];

  const mockSearchMetadata = {
    name: 'cpu_seconds_total',
    type: 'sum',
    description: 'System disk operations',
    last_ingested_at: 1705374438711900000,
    attribute_keys: ['host.name', 'host.dc', 'host.type'],
    supported_aggregations: ['1m', '1h'],
    supported_functions: ['min', 'max', 'avg', 'sum', 'count'],
    default_group_by_attributes: ['host.name'],
    default_group_by_function: ['avg'],
  };

  beforeEach(async () => {
    observabilityClientMock.fetchMetric.mockResolvedValue(mockMetricData);
    observabilityClientMock.fetchMetricSearchMetadata.mockResolvedValue(mockSearchMetadata);

    await mountComponent();
  });

  it('renders the related-issue-provider', () => {
    expect(findRelatedIssuesProvider().props()).toEqual({
      metricName: defaultProps.metricId,
      metricType: defaultProps.metricType,
      projectFullPath: defaultProps.projectFullPath,
    });
  });

  it('renders the loading indicator while fetching data', () => {
    mountComponent();

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findMetricDetails().exists()).toBe(false);
  });

  it('fetches data', () => {
    expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(
      metricId,
      metricType,
      expect.any(Object),
    );
    expect(observabilityClientMock.fetchMetricSearchMetadata).toHaveBeenCalledWith(
      metricId,
      metricType,
    );
  });

  describe('when metric type is an histogram', () => {
    beforeEach(async () => {
      observabilityClientMock.fetchMetric.mockClear();

      await mountComponent({ metricType: 'histogram' });
    });

    it('fetches data with heatmap visual', () => {
      expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(metricId, 'histogram', {
        abortController: expect.any(AbortController),
        filters: expect.any(Object),
        visual: 'heatmap',
      });
    });

    it('renders the heatmap chart', () => {
      expect(findMetricDetails().findComponent(MetricsLineChart).exists()).toBe(false);
      expect(findMetricDetails().findComponent(MetricsHeatmap).exists()).toBe(true);
    });
  });

  it('renders the metrics details', () => {
    expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(metricId, metricType, {
      abortController: expect.any(AbortController),
      filters: expect.any(Object),
    });
    expect(findLoadingIcon().exists()).toBe(false);
    expect(findMetricDetails().exists()).toBe(true);
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      setWindowLocation(
        '?type=Sum&foo.bar[]=eq-val' +
          '&not%5Bfoo.bar%5D[]=not-eq-val' +
          '&like%5Bfoo.baz%5D[]=like-val' +
          '&not_like%5Bfoo.baz%5D[]=not-like-val' +
          '&group_by_fn=avg' +
          '&group_by_attrs[]=foo' +
          '&group_by_attrs[]=bar' +
          '&date_range=custom' +
          '&date_start=2020-01-01T00%3A00%3A00.000Z' +
          '&date_end=2020-01-02T00%3A00%3A00.000Z',
      );
      observabilityClientMock.fetchMetric.mockClear();
      observabilityClientMock.fetchMetricSearchMetadata.mockClear();
      await mountComponent();
    });

    it('renders the FilteredSearch component', () => {
      const filteredSearch = findFilteredSearch();
      expect(filteredSearch.exists()).toBe(true);
      expect(filteredSearch.props('searchMetadata')).toBe(mockSearchMetadata);
    });

    it('does not render the filtered search component if fetching metadata fails', async () => {
      observabilityClientMock.fetchMetricSearchMetadata.mockRejectedValueOnce('error');
      await mountComponent();
      expect(findFilteredSearch().exists()).toBe(false);
    });

    it('fetches metrics with filters', () => {
      expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(metricId, metricType, {
        abortController: expect.any(AbortController),
        filters: {
          attributes: {
            'foo.bar': [
              { operator: '=', value: 'eq-val' },
              { operator: '!=', value: 'not-eq-val' },
            ],
            'foo.baz': [
              { operator: '=~', value: 'like-val' },
              { operator: '!~', value: 'not-like-val' },
            ],
          },
          groupBy: {
            func: 'avg',
            attributes: ['foo', 'bar'],
          },
          dateRange: {
            value: 'custom',
            startDate: new Date('2020-01-01'),
            endDate: new Date('2020-01-02'),
          },
        },
      });
    });

    it('initialises filtered-search props with values from query', () => {
      expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
        endDate: new Date('2020-01-02T00:00:00.000Z'),
        startDate: new Date('2020-01-01T00:00:00.000Z'),
        value: 'custom',
      });

      expect(findFilteredSearch().props('groupByFilter')).toEqual({
        attributes: ['foo', 'bar'],
        func: 'avg',
      });

      expect(findFilteredSearch().props('attributeFilters')).toEqual(
        prepareTokens({
          'foo.bar': [
            { operator: '=', value: 'eq-val' },
            { operator: '!=', value: 'not-eq-val' },
          ],
          'foo.baz': [
            { operator: '=~', value: 'like-val' },
            { operator: '!~', value: 'not-like-val' },
          ],
        }),
      );
    });

    it('renders UrlSync and sets query prop', () => {
      expect(findUrlSync().props('query')).toEqual({
        'foo.bar': ['eq-val'],
        'not[foo.bar]': ['not-eq-val'],
        'like[foo.bar]': null,
        'not_like[foo.bar]': null,
        'foo.baz': null,
        'not[foo.baz]': null,
        'like[foo.baz]': ['like-val'],
        'not_like[foo.baz]': ['not-like-val'],
        group_by_fn: 'avg',
        group_by_attrs: ['foo', 'bar'],
        date_range: 'custom',
        date_end: '2020-01-02T00:00:00.000Z',
        date_start: '2020-01-01T00:00:00.000Z',
      });
    });

    it('sets the default date range if not specified', async () => {
      setWindowLocation('?type=Sum');

      await mountComponent();

      expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
        value: '1h',
      });
      expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(metricId, metricType, {
        abortController: expect.any(AbortController),
        filters: {
          attributes: {},
          groupBy: {},
          dateRange: {
            value: '1h',
          },
        },
      });
      expect(findUrlSync().props('query')).toEqual({
        date_range: '1h',
      });
    });

    describe('on search cancel', () => {
      let abortSpy;
      beforeEach(() => {
        abortSpy = jest.spyOn(AbortController.prototype, 'abort');
      });
      it('does not abort the api call when canceled if a search was not initiated', () => {
        findFilteredSearch().vm.$emit('cancel');

        expect(abortSpy).not.toHaveBeenCalled();
      });

      it('aborts the api call when canceled if a search was initiated', () => {
        findFilteredSearch().vm.$emit('submit', {
          attributes: [],
        });

        expect(abortSpy).not.toHaveBeenCalled();

        findFilteredSearch().vm.$emit('cancel');

        expect(abortSpy).toHaveBeenCalled();
      });

      describe('when cancelled', () => {
        beforeEach(async () => {
          axios.isCancel = jest.fn().mockReturnValueOnce(true);
          observabilityClientMock.fetchMetric.mockRejectedValueOnce('cancelled');
          findFilteredSearch().vm.$emit('submit', {
            attributes: [],
          });
          await waitForPromises();
        });

        it('renders a toast and message', () => {
          expect(showToast).toHaveBeenCalledWith('Metrics search has been cancelled.', {
            variant: 'danger',
          });
        });

        it('sets cancelled prop on the chart component', () => {
          expect(findChart().props('cancelled')).toBe(true);
        });

        it('reset cancelled prop after issuing a new search', async () => {
          observabilityClientMock.fetchMetric.mockResolvedValue(mockMetricData);
          findFilteredSearch().vm.$emit('submit', {
            attributes: [],
          });
          await waitForPromises();

          expect(findChart().props('cancelled')).toBe(false);
        });
      });
    });

    describe('while searching', () => {
      beforeEach(() => {
        observabilityClientMock.fetchMetric.mockReturnValue(new Promise(() => {}));

        findFilteredSearch().vm.$emit('submit', {
          attributes: [],
        });
      });

      it('does not show the loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('sets the loading prop on the filtered-search component', () => {
        expect(findFilteredSearch().props('loading')).toBe(true);
      });

      it('sets the loading prop on the chart component', () => {
        expect(findChart().props('loading')).toBe(true);
      });
    });

    it('renders the loading indicator while fetching new data with currently empty data', async () => {
      observabilityClientMock.fetchMetric.mockResolvedValue([]);
      await mountComponent();

      await findFilteredSearch().vm.$emit('submit', {
        attributes: [],
      });

      expect(findLoadingIcon().exists()).toBe(true);
    });

    describe('on search submit', () => {
      const updatedMetricData = [
        {
          name: 'container_cpu_usage_seconds_total',
          type: 'Gauge',
          unit: 'gb',
          attributes: {
            beta_kubernetes_io_arch: 'amd64',
          },
          values: [[1700118610000, 0.25595267476015443]],
        },
      ];
      beforeEach(async () => {
        observabilityClientMock.fetchMetric.mockResolvedValue(updatedMetricData);
        await setFilters(
          {
            'key.one': [{ operator: '=', value: 'test' }],
          },
          {
            endDate: new Date('2020-07-06T00:00:00.000Z'),
            startDarte: new Date('2020-07-05T23:00:00.000Z'),
            value: '30d',
          },
          {
            func: 'sum',
            attributes: ['attr_1', 'attr_2'],
          },
        );
      });

      it('fetches traces with updated filters', () => {
        expect(observabilityClientMock.fetchMetric).toHaveBeenLastCalledWith(metricId, metricType, {
          abortController: expect.any(AbortController),
          filters: {
            attributes: {
              'key.one': [{ operator: '=', value: 'test' }],
            },
            dateRange: {
              endDate: new Date('2020-07-06T00:00:00.000Z'),
              startDarte: new Date('2020-07-05T23:00:00.000Z'),
              value: '30d',
            },
            groupBy: {
              func: 'sum',
              attributes: ['attr_1', 'attr_2'],
            },
          },
        });
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toEqual({
          'key.one': ['test'],
          'not[key.one]': null,
          'like[key.one]': null,
          'not_like[key.one]': null,
          group_by_fn: 'sum',
          group_by_attrs: ['attr_1', 'attr_2'],
          date_range: '30d',
        });
      });

      it('updates FilteredSearch props', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
          endDate: new Date('2020-07-06T00:00:00.000Z'),
          startDarte: new Date('2020-07-05T23:00:00.000Z'),
          value: '30d',
        });
        expect(findFilteredSearch().props('attributeFilters')).toEqual(
          prepareTokens({
            'key.one': [{ operator: '=', value: 'test' }],
          }),
        );
        expect(findFilteredSearch().props('groupByFilter')).toEqual({
          func: 'sum',
          attributes: ['attr_1', 'attr_2'],
        });
      });

      it('updates the details chart data', () => {
        expect(findChart().props('metricData')).toEqual(updatedMetricData);
      });
    });
  });

  it('renders the details chart', () => {
    const chart = findChart();
    expect(chart.exists()).toBe(true);
    expect(chart.props('metricData')).toEqual(mockMetricData);
    expect(chart.props('cancelled')).toBe(false);
    expect(chart.props('loading')).toBe(false);
    expect(findChart().props('chartInteractive')).toBe(true);
  });

  it('sets the datapoints when the chart emits selected', async () => {
    const dataPoints = [
      {
        seriesName: 'Something',
        color: '#fff',
        timestamp: 1725467764487,
        value: 1,
        traceIds: [],
      },
    ];

    await findChart().vm.$emit('selected', dataPoints);

    expect(findRelatedTraces().props()).toMatchObject({ dataPoints });
  });

  it('renders a line chart by default', () => {
    expect(findMetricDetails().findComponent(MetricsLineChart).exists()).toBe(true);
    expect(findMetricDetails().findComponent(MetricsHeatmap).exists()).toBe(false);
  });

  it('renders the details header', () => {
    expect(findHeader().exists()).toBe(true);
    expect(findHeader().props('heading')).toBe(metricId);
    expect(findHeader().text()).toContain(`Type:\u00a0${metricType}`);
    expect(findHeader().text()).toContain('System disk operations');
    expect(findHeader().text()).toContain('Last ingested:\u00a03 days ago');
    expect(ingestedAtTimeAgo).toHaveBeenCalledWith(mockSearchMetadata.last_ingested_at);
  });

  describe('create issue', () => {
    const findButton = () => findHeader().findComponent(GlButton);
    const onButtonClicked = async () => {
      await findButton().vm.$emit('click');
      await waitForPromises();
    };

    const metricsDetails = {
      fullUrl:
        'http://test.host/?type=Sum&date_range=custom&date_start=2020-07-05T23%3A00%3A00.000Z&date_end=2020-07-06T00%3A00%3A00.000Z',
      name: 'test.metric',
      type: 'Sum',
      timeframe: ['Sun, 05 Jul 2020 23:00:00 GMT', 'Mon, 06 Jul 2020 00:00:00 GMT'],
    };

    let visitUrlMock;
    let visitUrlWithAlertsMock;

    beforeEach(() => {
      visitUrlMock = jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});
      visitUrlWithAlertsMock = jest.spyOn(urlUtility, 'visitUrlWithAlerts').mockReturnValue({});
      uploadMetricsSnapshot.mockResolvedValue('http://test.host/share/url');
    });

    it('renders the create issue button', () => {
      const button = findButton();
      expect(button.text()).toBe('Create issue');
    });

    describe('on button clicked', () => {
      beforeEach(async () => {
        await onButtonClicked();
      });

      it('uploads the metric snapshot', () => {
        expect(uploadMetricsSnapshot).toHaveBeenCalledWith(
          wrapper.vm.$refs.chartComponent.$refs.chart,
          projectId,
          {
            metricName: metricsDetails.name,
            metricType: metricsDetails.type,
            filters: expect.objectContaining({
              dateRange: { value: '1h' },
            }),
          },
        );
      });

      it('does not add the loading icon to the create issue button when done uploading the snapshot', () => {
        expect(findButton().props('loading')).toBe(false);
      });

      it('appends the share url to the create issue params if uploadMetricsSnapshot succeeds', () => {
        expect(visitUrlMock).toHaveBeenCalledWith(
          `${createIssueUrl}?observability_metric_details=${encodeURIComponent(
            JSON.stringify({ ...metricsDetails, imageSnapshotUrl: 'http://test.host/share/url' }),
          )}&${encodeURIComponent('issue[confidential]')}=true`,
        );
      });
    });

    it('redirects to the create issue page without the image url if share url is not returned', async () => {
      uploadMetricsSnapshot.mockResolvedValue(null);

      await onButtonClicked();

      expect(visitUrlMock).toHaveBeenCalledWith(
        `${createIssueUrl}?observability_metric_details=${encodeURIComponent(
          JSON.stringify(metricsDetails),
        )}&${encodeURIComponent('issue[confidential]')}=true`,
      );
    });

    it('does not upload the metric snapshot if the chart does not exist', async () => {
      await mountComponent(
        {},
        {
          MetricsLineChart: stubComponent(MetricsLineChart, {
            template: `<div ref="chartComponent"></div>`,
          }),
        },
      );

      await onButtonClicked();

      expect(uploadMetricsSnapshot).not.toHaveBeenCalled();
    });

    it('redirects to the create issue page with alerts if an unexpected error is thrown', async () => {
      const mockError = new Error('Upload failed');

      uploadMetricsSnapshot.mockRejectedValue(mockError);

      await onButtonClicked();

      expect(logError).toHaveBeenCalledWith('Unexpected error while uploading image', mockError);
      expect(Sentry.captureException).toHaveBeenCalledWith(mockError);
      expect(visitUrlWithAlertsMock).toHaveBeenCalledWith(
        `${createIssueUrl}?observability_metric_details=${encodeURIComponent(
          JSON.stringify(metricsDetails),
        )}&${encodeURIComponent('issue[confidential]')}=true`,
        [
          {
            id: 'metrics-snapshot-creation-failed',
            message: 'Error: Unable to create metric snapshot image.',
            variant: 'danger',
          },
        ],
      );
    });

    describe('while uploading the snapshot', () => {
      beforeEach(async () => {
        uploadMetricsSnapshot.mockReturnValue(new Promise(() => {}));
        await onButtonClicked();
      });

      it('adds a loading icon to the create issue button while uploading the snapshot', () => {
        expect(findButton().props('loading')).toBe(true);
      });
    });
  });

  it('renders the relate issues badge', () => {
    expect(findRelatedIssuesBadge().props()).toStrictEqual({
      issuesTotal: 0,
      loading: false,
      error: null,
      anchorId: 'related-issues-1',
      parentScrollingId: null,
    });
  });

  it('renders the related issues', () => {
    expect(findRelatedIssues().props()).toStrictEqual({
      issues: [],
      fetchingIssues: false,
      error: null,
      helpPath: helpPagePath('/development/feature_development'),
    });
    expect(findRelatedIssues().attributes('id')).toBe('related-issues-1');
  });

  it('renders the related traces', () => {
    expect(findRelatedTraces().props()).toStrictEqual({
      dataPoints: [],
      tracingIndexUrl,
    });
  });

  describe('when metric has no related traces', () => {
    beforeEach(async () => {
      metricsDetailsUtils.metricHasRelatedTraces.mockReturnValue(false);

      await mountComponent();
    });

    it('does not render the related traces', () => {
      expect(findRelatedTraces().exists()).toBe(false);
    });

    it('disable chart interactivity', () => {
      expect(findChart().props('chartInteractive')).toBe(false);
    });
  });

  describe('with no data', () => {
    beforeEach(async () => {
      observabilityClientMock.fetchMetric.mockResolvedValue([]);

      await mountComponent();
    });

    it('renders the header', () => {
      expect(findHeader().exists()).toBe(true);
      expect(findHeader().props('heading')).toBe(metricId);
      expect(findHeader().text()).toContain(`Type:\u00a0${metricType}`);
      expect(findHeader().text()).toContain('System disk operations');
      expect(findHeader().text()).toContain('Last ingested:\u00a03 days ago');
    });

    it('renders the empty state, with description for selected time range', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().text()).toMatchInterpolatedText(
        'No data found for the selected time range (last 1 hour) Last ingested: 3 days ago',
      );
    });

    it('renders the empty state, with no description for the selected time range', async () => {
      await setFilters({}, { value: 'custom' });
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().text()).toMatchInterpolatedText(
        'No data found for the selected time range Last ingested: 3 days ago',
      );
    });

    it('does not render the related traces', () => {
      expect(findRelatedTraces().exists()).toBe(false);
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      observabilityClientMock.fetchMetric.mockResolvedValue([]);
      observabilityClientMock.fetchMetricSearchMetadata.mockResolvedValue({});
    });

    describe.each([
      ['fetchMetricSearchMetadata', () => observabilityClientMock.fetchMetricSearchMetadata],
      ['fetchMetric', () => observabilityClientMock.fetchMetric],
    ])('when %s fails', (_, mockFn) => {
      beforeEach(async () => {
        mockFn().mockRejectedValue('error');
        await mountComponent();
      });
      it('renders an alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error: Failed to load metrics details. Try reloading the page.',
        });
      });

      it('only renders the empty state and header', () => {
        expect(findMetricDetails().exists()).toBe(true);
        expect(findEmptyState().exists()).toBe(true);
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findHeader().exists()).toBe(true);
        expect(findChart().exists()).toBe(false);
      });
    });

    it('renders an alert if metricId is missing', async () => {
      await mountComponent({ metricId: '' });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load metrics details. Try reloading the page.',
      });
    });

    it('renders an alert if metricType is missing', async () => {
      await mountComponent({ metricType: '' });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load metrics details. Try reloading the page.',
      });
    });
  });
});
