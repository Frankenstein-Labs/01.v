import { GlBadge, GlCard } from '@gitlab/ui';
import TracingHeader from 'ee/tracing/details/tracing_header.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RelatedIssuesBadge from '~/observability/components/related_issues_badge.vue';
import { createMockTrace } from '../mock_data';

describe('TracingHeader', () => {
  let wrapper;

  const defaultTrace = createMockTrace();

  const createComponent = (trace = defaultTrace, incomplete = false) => {
    wrapper = shallowMountExtended(TracingHeader, {
      propsData: {
        trace,
        incomplete,
        viewLogsUrl: 'testViewLogsUrl',
        viewMetricsUrl: 'testViewMetricsUrl',
        createIssueUrl: 'testCreateIssueUrl',
        totalErrors: 2,
        issues: [],
        fetchingIssues: false,
        relatedIssuesId: 'related-issues-1',
      },
      stubs: { GlCard },
    });
  };
  beforeEach(() => {
    createComponent();
  });

  const findHeading = () => wrapper.findComponent(PageHeading);
  const findRelatedIssuesBadge = () => wrapper.findComponent(RelatedIssuesBadge);

  it('renders the correct title', () => {
    expect(findHeading().text()).toContain('Service : Operation');
  });

  it('does not show the in progress label if incomplete=false', () => {
    expect(findHeading().findComponent(GlBadge).exists()).toBe(false);

    expect(findHeading().text()).not.toContain('In progress');
  });

  it('shows the in progress label when incomplete=true', () => {
    createComponent(
      {
        ...defaultTrace,
      },
      true,
    );

    expect(findHeading().findComponent(GlBadge).exists()).toBe(true);
    expect(findHeading().text()).toContain('In progress');
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

  it('renders the view logs button', () => {
    const button = wrapper.findByText('View logs');
    expect(button.attributes('href')).toBe('testViewLogsUrl');
  });

  it('renders the view metrics button', () => {
    const button = wrapper.findByText('View metrics');
    expect(button.attributes('href')).toBe('testViewMetricsUrl');
  });

  it('renders the create issue button', () => {
    const button = wrapper.findByText('Create issue');
    expect(button.text()).toBe('Create issue');
    const traceDetails = {
      fullUrl: 'http://test.host/',
      name: `Service : Operation`,
      traceId: '8335ed4c-c943-aeaa-7851-2b9af6c5d3b8',
      start: 'Mon, 14 Aug 2023 14:05:37 GMT',
      duration: '1s',
      totalSpans: 10,
      totalErrors: 2,
    };
    expect(button.attributes('href')).toBe(
      `testCreateIssueUrl?observability_trace_details=${encodeURIComponent(
        JSON.stringify(traceDetails),
      )}&${encodeURIComponent('issue[confidential]')}=true`,
    );
  });

  it('renders the correct trace date', () => {
    expect(wrapper.findByTestId('trace-date-card').text()).toMatchInterpolatedText(
      'Trace start Aug 14, 2023 14:05:37.219 UTC',
    );
  });

  it('renders the correct trace duration', () => {
    expect(wrapper.findByTestId('trace-duration-card').text()).toMatchInterpolatedText(
      'Duration 1s',
    );
  });

  it('renders the correct total spans', () => {
    expect(wrapper.findByTestId('trace-spans-card').text()).toMatchInterpolatedText(
      'Total spans 10',
    );
  });
});
