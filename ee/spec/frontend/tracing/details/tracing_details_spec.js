import { GlLoadingIcon, GlAlert, GlSprintf } from '@gitlab/ui';
import RelatedIssuesProvider from 'ee/tracing/details/related_issues/related_issues_provider.vue';
import TracingChart from 'ee/tracing/details/tracing_chart.vue';
import TracingHeader from 'ee/tracing/details/tracing_header.vue';
import TracingDrawer from 'ee/tracing/details/tracing_drawer.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingDetails from 'ee/tracing/details/tracing_details.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { mapTraceToSpanTrees } from 'ee/tracing/trace_utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import RelatedIssue from '~/observability/components/observability_related_issues.vue';
import { stubComponent } from 'helpers/stub_component';
import { helpPagePath } from '~/helpers/help_page_helper';

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));
jest.mock('ee/tracing/trace_utils');

describe('TracingDetails', () => {
  let wrapper;
  let observabilityClientMock;

  const tracingIndexUrl = 'https://www.gitlab.com/flightjs/Flight/-/tracing';
  const logsIndexUrl = 'https://www.gitlab.com/flightjs/Flight/-/logs';
  const metricsIndexUrl = 'https://www.gitlab.com/flightjs/Flight/-/metrics';
  const createIssueUrl = 'https://www.gitlab.com/flightjs/Flight/-/issues/new';
  const testTraceId = 'test-trace-id';
  const projectFullPath = 'foo/bar';

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const findTraceDetails = () => wrapper.findByTestId('trace-details');
  const findTraceChart = () => wrapper.findComponent(TracingChart);
  const findRelatedIssues = () => wrapper.findComponent(RelatedIssue);

  const findDrawer = () => wrapper.findComponent(TracingDrawer);
  const isDrawerOpen = () => findDrawer().props('open');
  const getDrawerSpan = () => findDrawer().props('span');

  const props = {
    traceId: testTraceId,
    tracingIndexUrl,
    logsIndexUrl,
    metricsIndexUrl,
    createIssueUrl,
    projectFullPath,
  };

  const mountComponent = async () => {
    wrapper = shallowMountExtended(TracingDetails, {
      propsData: {
        ...props,
        observabilityClient: observabilityClientMock,
      },
      stubs: {
        GlSprintf,
        RelatedIssuesProvider: stubComponent(RelatedIssuesProvider, {
          template: `<div>
            <slot :issues="[]" :loading="false" :error="null" />
          </div>`,
        }),
      },
    });
    await waitForPromises();
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const mockTrace = {
    traceId: 'test-trace-id',
    spans: [{ span_id: 'span-1' }, { span_id: 'span-2' }],
  };
  const mockTree = {
    roots: [{ span_id: 'span-1' }],
    incomplete: true,
    pruned: true,
    totalErrors: 2,
  };

  beforeEach(async () => {
    observabilityClientMock = createMockClient();

    observabilityClientMock.fetchTrace.mockResolvedValueOnce(mockTrace);
    mapTraceToSpanTrees.mockReturnValue(mockTree);

    await mountComponent();
  });

  it('tracks view_tracing_details_page', () => {
    mountComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    expect(trackEventSpy).toHaveBeenCalledWith('view_tracing_details_page', {}, undefined);
  });

  it('fetches the trace and renders the trace details', () => {
    expect(observabilityClientMock.fetchTrace).toHaveBeenCalled();
    expect(findLoadingIcon().exists()).toBe(false);
    expect(findTraceDetails().exists()).toBe(true);
  });

  it('renders the related-issue-provider', () => {
    const relatedIssuesProvider = wrapper.findComponent(RelatedIssuesProvider);

    expect(relatedIssuesProvider.props()).toEqual({
      projectFullPath,
      traceId: testTraceId,
    });
    expect(findRelatedIssues().attributes('id')).toBe('related-issues-1');
  });

  it('renders the chart component', () => {
    const chart = findTraceChart();
    expect(chart.exists()).toBe(true);
    expect(chart.props('trace')).toEqual(mockTrace);
    expect(chart.props('spanTrees')).toEqual(mockTree.roots);
  });

  it('renders the header', () => {
    const header = findTraceDetails().findComponent(TracingHeader);
    const { incomplete, totalErrors } = mockTree;

    expect(header.exists()).toBe(true);
    expect(header.props()).toStrictEqual({
      incomplete,
      trace: mockTrace,
      viewLogsUrl: `${logsIndexUrl}?traceId[]=test-trace-id&search=&date_range=30d`,
      viewMetricsUrl: `${metricsIndexUrl}?traceId[]=test-trace-id`,
      createIssueUrl,
      totalErrors,
      relatedIssuesId: 'related-issues-1',
      issues: [],
      fetchingIssues: false,
      error: null,
    });
  });

  it('renders the related issues', () => {
    expect(findRelatedIssues().props()).toStrictEqual({
      issues: [],
      fetchingIssues: false,
      error: null,
      helpPath: helpPagePath('/development/feature_development'),
    });
  });

  describe('details drawer', () => {
    it('renders the details drawer initially closed', () => {
      expect(findDrawer().exists()).toBe(true);
      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSpan()).toBe(null);
    });

    const selectSpan = (spanId = 'span-1') =>
      findTraceChart().vm.$emit('span-selected', { spanId });

    it('opens the drawer and set the selected span, upond selection', async () => {
      await selectSpan();

      expect(isDrawerOpen()).toBe(true);
      expect(getDrawerSpan()).toEqual({ span_id: 'span-1' });
    });

    it('closes the drawer upon receiving the close event', async () => {
      await selectSpan();

      await findDrawer().vm.$emit('close');

      expect(isDrawerOpen()).toBe(false);
      expect(getDrawerSpan()).toBe(null);
    });

    it('closes the drawer if the same span is selected', async () => {
      await selectSpan();

      expect(isDrawerOpen()).toBe(true);

      await selectSpan();

      expect(isDrawerOpen()).toBe(false);
    });

    it('changes the selected span and keeps the drawer open, upon selecting a different span', async () => {
      await selectSpan('span-1');

      expect(isDrawerOpen()).toBe(true);

      await selectSpan('span-2');

      expect(isDrawerOpen()).toBe(true);
      expect(getDrawerSpan()).toEqual({ span_id: 'span-2' });
    });

    it('set the selected-span-in on the chart component', async () => {
      expect(findTraceChart().props('selectedSpanId')).toBeNull();
      await selectSpan();
      expect(findTraceChart().props('selectedSpanId')).toBe('span-1');
    });
  });

  describe('pruning warning', () => {
    const findAlert = () => wrapper.findComponent(GlAlert);
    it('shows a warning if the trace is pruned', () => {
      expect(findAlert().text()).toBe(
        'This trace has 2 spans. For performance reasons, we only show the first 2000 spans.',
      );
    });

    it('does not show a warning if the trace is not pruned', async () => {
      mapTraceToSpanTrees.mockReturnValue({ ...mockTree, pruned: false });

      await mountComponent();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('error handling', () => {
    it('if fetchTrace fails, it renders an alert and empty page', async () => {
      observabilityClientMock.fetchTrace.mockRejectedValueOnce('error');

      await mountComponent();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load trace details. Try reloading the page.',
      });
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findTraceDetails().exists()).toBe(false);
    });
  });
});
