import { GlLoadingIcon, GlInfiniteScroll, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import LogsTable from 'ee/logs/list/logs_table.vue';
import LogsVolume from 'ee/logs/list/logs_volume.vue';
import LogsDrawer from 'ee/logs/list/logs_drawer.vue';
import LogsFilteredSearch from 'ee/logs/list/filter_bar/logs_filtered_search.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LogsList from 'ee/logs/list/logs_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockClient } from 'helpers/mock_observability_client';
import * as commonUtils from '~/lib/utils/common_utils';
import axios from '~/lib/utils/axios_utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ObservabilityNoDataEmptyState from '~/observability/components/observability_no_data_empty_state.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { mockLogs, mockMetadata } from '../mock_data';

jest.mock('~/lib/utils/axios_utils');
jest.mock('~/alert');

describe('LogsList', () => {
  let wrapper;
  let observabilityClientMock;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findLogsTable = () => wrapper.findComponent(LogsTable);
  const findInfiniteScrolling = () => wrapper.findComponent(GlInfiniteScroll);
  const findInfiniteScrollingLegend = () =>
    findInfiniteScrolling().find('[data-testid="logs-infinite-scrolling-legend"]');
  const findNoDataEmptyState = () => wrapper.findComponent(ObservabilityNoDataEmptyState);

  const bottomReached = async () => {
    findInfiniteScrolling().vm.$emit('bottomReached');
    await waitForPromises();
  };

  const findDrawer = () => wrapper.findComponent(LogsDrawer);
  const isDrawerOpen = () => findDrawer().props('open');
  const getDrawerSelectedLog = () => findDrawer().props('log');

  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const findLogsVolumeChart = () => wrapper.findComponent(LogsVolume);

  const findFilteredSearch = () => wrapper.findComponent(LogsFilteredSearch);
  const setFilters = async (filters = { dateRange: {}, attributes: {} }) => {
    await findFilteredSearch().vm.$emit('filter', filters);
    await waitForPromises();
  };

  const testTracingIndexUrl = 'https://test.gdk/tracing';
  const testCreateIssueUrl = 'https://test.gdk/issues/new';
  const testProjectFullPath = 'foo/bar';

  const mountComponent = async () => {
    wrapper = shallowMountExtended(LogsList, {
      propsData: {
        observabilityClient: observabilityClientMock,
        tracingIndexUrl: testTracingIndexUrl,
        createIssueUrl: testCreateIssueUrl,
        projectFullPath: testProjectFullPath,
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
    observabilityClientMock.fetchLogs.mockResolvedValue({
      logs: mockLogs,
      nextPageToken: 'page-2',
    });
    observabilityClientMock.fetchLogsSearchMetadata.mockResolvedValue(mockMetadata);
  });

  it('tracks view_logs_page', () => {
    mountComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    expect(trackEventSpy).toHaveBeenCalledWith('view_logs_page', {}, undefined);
  });

  it('renders the loading indicator while fetching logs data', () => {
    mountComponent();

    expect(findFilteredSearch().exists()).toBe(true);
    expect(findLogsVolumeChart().props('loading')).toBe(true);
    expect(findLoadingIcon().exists()).toBe(true);
    expect(findLogsTable().exists()).toBe(false);
    expect(findNoDataEmptyState().exists()).toBe(false);
    expect(observabilityClientMock.fetchLogs).toHaveBeenCalled();
    expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalled();
  });

  it('renders the LogsTable when fetching logs is done', async () => {
    await mountComponent();

    expect(findLoadingIcon().exists()).toBe(false);
    expect(findLogsTable().exists()).toBe(true);
    expect(findNoDataEmptyState().exists()).toBe(false);
    expect(findLogsTable().props('logs')).toEqual(mockLogs);
  });

  it('renders the empty state if no data is found', async () => {
    observabilityClientMock.fetchLogs.mockResolvedValue({ logs: [] });

    await mountComponent();

    expect(findNoDataEmptyState().exists()).toBe(true);
    expect(findLogsTable().exists()).toBe(false);
  });

  it('renders the header', async () => {
    await mountComponent();

    expect(wrapper.findComponent(PageHeading).props('heading')).toBe('Logs');
    expect(wrapper.find('header').text()).toBe(
      'Monitor log events captured from your systems. Send log data to this project using OpenTelemetry. Learn more.',
    );
  });

  it('if fetchLogs fails, it renders an alert and empty state', async () => {
    observabilityClientMock.fetchLogs.mockRejectedValue('error');

    await mountComponent();

    expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load logs.' });
    expect(findLogsTable().exists()).toBe(false);
    expect(findNoDataEmptyState().exists()).toBe(true);
  });

  it('renders an alert when fetchLogsSearchMetadata fails', async () => {
    observabilityClientMock.fetchLogsSearchMetadata.mockRejectedValue('error');

    await mountComponent();

    expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load metadata.' });
  });

  describe('details drawer', () => {
    beforeEach(async () => {
      await mountComponent();
    });
    it('renders the details drawer initially closed', () => {
      expect(findDrawer().exists()).toBe(true);
      expect(findDrawer().props('tracingIndexUrl')).toBe(testTracingIndexUrl);
      expect(findDrawer().props('createIssueUrl')).toBe(testCreateIssueUrl);
      expect(findDrawer().props('projectFullPath')).toBe(testProjectFullPath);
      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSelectedLog()).toBe(null);
    });

    const selectLogByIndex = (logIndex) =>
      findLogsTable().vm.$emit('log-selected', { fingerprint: mockLogs[logIndex].fingerprint });

    const selectLog = (log) =>
      findLogsTable().vm.$emit('log-selected', { fingerprint: log.fingerprint });

    it('opens the drawer and set the selected log, upond selection', async () => {
      await selectLogByIndex(1);

      expect(isDrawerOpen()).toBe(true);
      expect(getDrawerSelectedLog()).toEqual(mockLogs[1]);
    });

    it('closes the drawer upon receiving the close event', async () => {
      await selectLogByIndex(1);

      await findDrawer().vm.$emit('close');

      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSelectedLog()).toBe(null);
    });

    it('closes the drawer if the same log is selected', async () => {
      await selectLogByIndex(1);

      expect(isDrawerOpen()).toBe(true);

      await selectLogByIndex(1);

      expect(isDrawerOpen()).toBe(false);
    });

    it('changes the selected log and keeps the drawer open, upon selecting a different log', async () => {
      await selectLogByIndex(1);

      expect(isDrawerOpen()).toBe(true);

      await selectLogByIndex(2);

      expect(isDrawerOpen()).toBe(true);
      expect(getDrawerSelectedLog()).toEqual(mockLogs[2]);
    });

    it('handles invalid logs', async () => {
      await findLogsTable().vm.$emit('log-selected', { fingerprint: 'i-do-not-exist' });

      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSelectedLog()).toBe(null);
    });

    it('updates the URL query params based on the selected log', async () => {
      const selectedLog = mockLogs[2];
      await selectLog(selectedLog);

      expect(findUrlSync().props('query')).toEqual({
        attribute: null,
        fingerprint: [selectedLog.fingerprint],
        'not[fingerprint]': null,
        'not[resourceAttribute]': null,
        'not[service]': null,
        'not[severityName]': null,
        'not[severityNumber]': null,
        'not[spanId]': null,
        'not[traceFlags]': null,
        'not[traceId]': null,
        'not[attribute]': null,
        resourceAttribute: null,
        search: '',
        service: [selectedLog.service_name],
        severityName: null,
        severityNumber: [selectedLog.severity_number],
        spanId: null,
        traceFlags: null,
        traceId: [selectedLog.trace_id],
        timestamp: selectedLog.timestamp,
        drawerOpen: true,
      });
    });

    it('restore the query param to the old value after closing the panel', async () => {
      setWindowLocation('?fingerprint[]=fingerprint');

      await mountComponent();

      expect(findUrlSync().props('query')).toMatchObject({
        fingerprint: ['fingerprint'],
      });

      await selectLogByIndex(1);

      expect(findUrlSync().props('query')).not.toMatchObject({
        fingerprint: ['fingerprint'],
      });

      await selectLogByIndex(1); // close

      expect(findUrlSync().props('query')).toMatchObject({
        fingerprint: ['fingerprint'],
        drawerOpen: undefined,
      });
    });

    it('automatically opens the drawer if drawerOpen is true', async () => {
      setWindowLocation(`?fingerprint[]=${mockLogs[2].fingerprint}&drawerOpen=true`);

      await mountComponent();

      expect(isDrawerOpen()).toBe(true);
      expect(getDrawerSelectedLog()).toEqual(mockLogs[2]);
    });

    it('does not automatically open the drawer if drawerOpen is not true', async () => {
      setWindowLocation(`?fingerprint[]=${mockLogs[2].fingerprint}&drawerOpen=false`);

      await mountComponent();

      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSelectedLog()).toBe(null);
    });

    it('does not automatically open the drawer if fingerprint is not set', async () => {
      setWindowLocation(`?drawerOpen=true`);

      await mountComponent();

      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSelectedLog()).toBe(null);
    });

    it('does not automatically open the drawer if fingerprint does not exist', async () => {
      setWindowLocation(`?fingerprint[]=foo&drawerOpen=true`);

      await mountComponent();

      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSelectedLog()).toBe(null);
    });
  });

  describe('infinite scrolling / pagination', () => {
    describe('when data is returned', () => {
      beforeEach(async () => {
        await mountComponent();
      });

      it('renders the list with infinite scrolling', () => {
        const infiniteScrolling = findInfiniteScrolling();
        expect(infiniteScrolling.exists()).toBe(true);
        expect(infiniteScrolling.props('fetchedItems')).toBe(mockLogs.length);
        expect(infiniteScrolling.getComponent(LogsTable).exists()).toBe(true);
      });

      it('fetches the next page when bottom reached', async () => {
        const nextPageResponse = {
          logs: [{ fingerprint: 'log-1' }],
          next_page_token: 'page-3',
        };
        observabilityClientMock.fetchLogs.mockReturnValueOnce(nextPageResponse);

        await bottomReached();

        expect(observabilityClientMock.fetchLogs).toHaveBeenLastCalledWith({
          pageSize: 100,
          pageToken: 'page-2',
          filters: { dateRange: { value: '1h' }, attributes: {} },
          abortController: expect.any(AbortController),
        });

        expect(findInfiniteScrolling().props('fetchedItems')).toBe(
          mockLogs.length + nextPageResponse.logs.length,
        );
        expect(findLogsTable().props('logs')).toEqual([...mockLogs, ...nextPageResponse.logs]);
      });

      it('after reaching the last page, on bottom reached, it keeps fetching logs from the last available page', async () => {
        // Initial call from mounting
        expect(observabilityClientMock.fetchLogs).toHaveBeenCalledTimes(1);
        expect(observabilityClientMock.fetchLogs).toHaveBeenLastCalledWith({
          pageSize: 100,
          pageToken: null,
          abortController: expect.any(AbortController),
          filters: { dateRange: { value: '1h' }, attributes: {} },
        });

        // hit last page (no logs, no page token)
        observabilityClientMock.fetchLogs.mockReturnValue({
          logs: [],
        });
        await bottomReached();

        expect(observabilityClientMock.fetchLogs).toHaveBeenCalledTimes(2);
        expect(observabilityClientMock.fetchLogs).toHaveBeenLastCalledWith({
          pageSize: 100,
          pageToken: 'page-2',
          filters: { dateRange: { value: '1h' }, attributes: {} },
          abortController: expect.any(AbortController),
        });

        await bottomReached();

        expect(observabilityClientMock.fetchLogs).toHaveBeenCalledTimes(3);
        expect(observabilityClientMock.fetchLogs).toHaveBeenLastCalledWith({
          pageSize: 100,
          pageToken: 'page-2',
          filters: { dateRange: { value: '1h' }, attributes: {} },
          abortController: expect.any(AbortController),
        });
      });

      it('shows the number of fetched items as the legend', () => {
        expect(findInfiniteScrollingLegend().text()).toBe(`Showing ${mockLogs.length} logs`);
      });

      it('shows the spinner when fetching the next page', async () => {
        bottomReached();
        await nextTick();

        expect(findInfiniteScrolling().findComponent(GlLoadingIcon).exists()).toBe(true);
        expect(findInfiniteScrollingLegend().exists()).toBe(false);
      });

      it('does not reload metadata', async () => {
        expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalledTimes(1);

        await bottomReached();

        expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalledTimes(1);
      });
    });

    describe('when no data is returned', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchLogs.mockReturnValue({
          logs: [],
        });
        await mountComponent();
      });

      // an empty legend is needed to override the default legend
      it('shows an empty legend when there are 0 items', () => {
        expect(findInfiniteScrollingLegend().text()).toBe('');
      });
    });
  });

  describe('filtered search', () => {
    const attributesFiltersObj = {
      service: [
        { operator: '=', value: 'serviceName' },
        { operator: '!=', value: 'serviceName2' },
      ],
      severityName: [
        { operator: '=', value: 'info' },
        { operator: '!=', value: 'warning' },
      ],
      severityNumber: [
        { operator: '=', value: '9' },
        { operator: '!=', value: '10' },
      ],
      traceId: [{ operator: '=', value: 'traceId' }],
      spanId: [{ operator: '=', value: 'spanId' }],
      fingerprint: [{ operator: '=', value: 'fingerprint' }],
      traceFlags: [
        { operator: '=', value: '1' },
        { operator: '!=', value: '2' },
      ],
      attribute: [{ operator: '=', value: 'attr=bar' }],
      resourceAttribute: [{ operator: '=', value: 'res=foo' }],
      search: [{ value: 'some-search' }],
    };

    beforeEach(async () => {
      setWindowLocation(
        '?attribute[]=attr%3Dbar' +
          '&fingerprint[]=fingerprint' +
          '&service[]=serviceName' +
          '&not%5Bservice%5D[]=serviceName2' +
          '&resourceAttribute[]=res%3Dfoo' +
          '&search[]=some-search' +
          '&severityName[]=info' +
          '&not%5BseverityName%5D[]=warning' +
          '&severityNumber[]=9' +
          '&not%5BseverityNumber%5D[]=10' +
          '&spanId[]=spanId' +
          '&traceFlags[]=1' +
          '&not%5BtraceFlags%5D[]=2' +
          '&traceId[]=traceId' +
          '&date_range=custom' +
          '&date_end=2020-01-02T00%3A00%3A00.000Z' +
          '&date_start=2020-01-01T00%3A00%3A00.000Z',
      );
      await mountComponent();
    });

    it('renders the FilteredSearch component', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('initialises filtered-search props with values from query', () => {
      expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
        endDate: new Date('2020-01-02T00:00:00.000Z'),
        startDate: new Date('2020-01-01T00:00:00.000Z'),
        value: 'custom',
      });

      expect(findFilteredSearch().props('attributesFilters')).toEqual(attributesFiltersObj);
    });

    it('passes metadata to the filtered search', () => {
      expect(findFilteredSearch().props('searchMetadata')).toEqual(mockMetadata.summary);
    });

    it('renders UrlSync and sets query prop', () => {
      expect(findUrlSync().props('query')).toEqual({
        attribute: ['attr=bar'],
        fingerprint: ['fingerprint'],
        'not[fingerprint]': null,
        'not[resourceAttribute]': null,
        'not[service]': ['serviceName2'],
        'not[severityName]': ['warning'],
        'not[severityNumber]': ['10'],
        'not[spanId]': null,
        'not[traceFlags]': ['2'],
        'not[traceId]': null,
        'not[attribute]': null,
        resourceAttribute: ['res=foo'],
        search: 'some-search',
        service: ['serviceName'],
        severityName: ['info'],
        severityNumber: ['9'],
        spanId: ['spanId'],
        traceFlags: ['1'],
        traceId: ['traceId'],
        date_range: 'custom',
        date_end: '2020-01-02T00:00:00.000Z',
        date_start: '2020-01-01T00:00:00.000Z',
      });
    });

    it('fetches logs and metadata with filters', () => {
      const filters = {
        attributes: attributesFiltersObj,
        dateRange: {
          value: 'custom',
          startDate: new Date('2020-01-01'),
          endDate: new Date('2020-01-02'),
        },
      };
      expect(observabilityClientMock.fetchLogs).toHaveBeenCalledWith({
        filters,
        abortController: expect.any(AbortController),
        pageSize: 100,
        pageToken: null,
      });

      expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalledWith({
        filters,
        abortController: expect.any(AbortController),
      });
    });

    describe('if no date range is provided', () => {
      beforeEach(async () => {
        setWindowLocation('?');

        await mountComponent();
      });

      it('sets data-range-filter prop to the default date range', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({ value: '1h' });
      });

      it('fetches logs and metadata with default time range filter', () => {
        const filters = {
          dateRange: {
            value: '1h',
          },
          attributes: {},
        };
        expect(observabilityClientMock.fetchLogs).toHaveBeenCalledWith({
          filters,
          pageSize: 100,
          pageToken: null,
          abortController: expect.any(AbortController),
        });
        expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalledWith({
          filters,
          abortController: expect.any(AbortController),
        });
      });
    });

    describe('when a timestamp is provided', () => {
      beforeEach(async () => {
        setWindowLocation('?timestamp=2024-02-19T16%3A10%3A15.4433398Z&service[]=testservice');

        await mountComponent();
      });
      it('fetches logs and metadata with the proper filters', () => {
        const filters = {
          dateRange: {
            value: 'custom',
            endDate: new Date('2024-02-19T16:10:15.443Z'),
            startDate: new Date('2024-02-19T16:10:15.443Z'),
            timestamp: '2024-02-19T16:10:15.4433398Z',
          },
          attributes: {
            service: [{ operator: '=', value: 'testservice' }],
          },
        };
        expect(observabilityClientMock.fetchLogs).toHaveBeenCalledWith({
          filters,
          pageSize: 100,
          pageToken: null,
          abortController: expect.any(AbortController),
        });
        expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalledWith({
          filters,
          abortController: expect.any(AbortController),
        });
      });

      it('initialises filtered-search props', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
          value: 'custom',
          endDate: new Date('2024-02-19T16:10:15.443Z'),
          startDate: new Date('2024-02-19T16:10:15.443Z'),
          timestamp: '2024-02-19T16:10:15.4433398Z',
        });

        expect(findFilteredSearch().props('attributesFilters')).toEqual({
          service: [{ operator: '=', value: 'testservice' }],
        });
      });

      it('sets query prop', () => {
        expect(findUrlSync().props('query')).toEqual({
          attribute: null,
          fingerprint: null,
          'not[fingerprint]': null,
          'not[resourceAttribute]': null,
          'not[service]': null,
          'not[severityName]': null,
          'not[severityNumber]': null,
          'not[spanId]': null,
          'not[traceFlags]': null,
          'not[traceId]': null,
          'not[attribute]': null,
          resourceAttribute: null,
          search: '',
          service: ['testservice'],
          severityName: null,
          severityNumber: null,
          spanId: null,
          traceFlags: null,
          traceId: null,
          timestamp: '2024-02-19T16:10:15.4433398Z',
          date_end: '2024-02-19T16:10:15.443Z',
          date_range: 'custom',
          date_start: '2024-02-19T16:10:15.443Z',
        });
      });
    });

    describe('when filter changes', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchLogs.mockClear();
        observabilityClientMock.fetchLogsSearchMetadata.mockClear();

        await setFilters({
          dateRange: { value: '7d' },
          attributes: { search: [{ value: 'some-log' }] },
        });
      });

      it('fetches logs and metadata with the updated filters', () => {
        const filters = {
          dateRange: {
            value: '7d',
          },
          attributes: { search: [{ value: 'some-log' }] },
        };
        expect(observabilityClientMock.fetchLogs).toHaveBeenCalledTimes(1);
        expect(observabilityClientMock.fetchLogs).toHaveBeenLastCalledWith({
          filters,
          pageSize: 100,
          pageToken: null,
          abortController: expect.any(AbortController),
        });
        expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenCalledTimes(1);
        expect(observabilityClientMock.fetchLogsSearchMetadata).toHaveBeenLastCalledWith({
          filters,
          abortController: expect.any(AbortController),
        });
      });

      it('updates the filtered search props', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({ value: '7d' });
        expect(findFilteredSearch().props('attributesFilters')).toEqual({
          search: [{ value: 'some-log' }],
        });
      });

      it('updates the query', () => {
        expect(findUrlSync().props('query')).toEqual({
          attribute: null,
          date_end: undefined,
          date_range: '7d',
          date_start: undefined,
          fingerprint: null,
          'not[attribute]': null,
          'not[fingerprint]': null,
          'not[resourceAttribute]': null,
          'not[service]': null,
          'not[severityName]': null,
          'not[severityNumber]': null,
          'not[spanId]': null,
          'not[traceFlags]': null,
          'not[traceId]': null,
          resourceAttribute: null,
          search: 'some-log',
          service: null,
          severityName: null,
          severityNumber: null,
          spanId: null,
          traceFlags: null,
          traceId: null,
        });
      });
    });

    describe('logs volume chart', () => {
      it('renders the volume component', () => {
        expect(findLogsVolumeChart().exists()).toBe(true);
      });

      it('sets logsCount prop to severity_numbers_counts', () => {
        expect(findLogsVolumeChart().props('logsCount')).toBe(mockMetadata.severity_numbers_counts);
      });

      describe('chart height', () => {
        const mountWithSize = async (contentTop, innerHeight) => {
          jest.spyOn(commonUtils, 'contentTop').mockReturnValue(contentTop);
          window.innerHeight = innerHeight;

          await mountComponent();
        };
        it('sets the chart height to 20% of the container height', async () => {
          await mountWithSize(200, 1000);

          expect(findLogsVolumeChart().props('height')).toBe(160);
          expect(findInfiniteScrolling().props('maxListHeight')).toBe(550);
        });

        it('sets the min height to 100px', async () => {
          await mountWithSize(20, 200);

          expect(findLogsVolumeChart().props('height')).toBe(100);
        });

        it('resize the chart on window resize', async () => {
          await mountWithSize(200, 1000);

          expect(findLogsVolumeChart().props('height')).toBe(160);

          jest.spyOn(commonUtils, 'contentTop').mockReturnValue(200);
          window.innerHeight = 800;
          window.dispatchEvent(new Event('resize'));

          await nextTick();

          expect(findLogsVolumeChart().props('height')).toBe(120);
        });
      });
    });
  });

  describe('cancelling pending requests', () => {
    let abortSpy;
    beforeEach(async () => {
      axios.isCancel = jest.fn().mockReturnValue(true);
      abortSpy = jest.spyOn(AbortController.prototype, 'abort');

      await mountComponent();

      observabilityClientMock.fetchLogsSearchMetadata.mockReturnValue(new Promise(() => {}));
      observabilityClientMock.fetchLogs.mockReturnValue(new Promise(() => {}));
    });

    it('cancels pending requests', async () => {
      expect(abortSpy).not.toHaveBeenCalled();

      await setFilters();
      await setFilters();

      // cancel fetchLogs and fetchAnalytics
      expect(abortSpy).toHaveBeenCalledTimes(2);
    });

    it('does not show any alert', async () => {
      observabilityClientMock.fetchLogs.mockRejectedValue('cancelled');
      observabilityClientMock.fetchLogsSearchMetadata.mockRejectedValue('cancelled');

      await setFilters();

      expect(createAlert).not.toHaveBeenCalled();
    });

    it('does not hide the loading indicator', async () => {
      await setFilters();

      expect(findLoadingIcon().exists()).toBe(true);
    });
  });
});
