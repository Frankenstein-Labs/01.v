import { GlDrawer, GlLink, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LogsDrawer from 'ee/logs/list/logs_drawer.vue';
import RelatedIssuesProvider from 'ee/logs/list/related_issues/related_issues_provider.vue';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import setWindowLocation from 'helpers/set_window_location_helper';
import { stubComponent } from 'helpers/stub_component';
import RelatedIssue from '~/observability/components/observability_related_issues.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import RelatedIssuesBadge from '~/observability/components/related_issues_badge.vue';
import { mockLogs } from '../mock_data';

jest.mock('~/lib/utils/dom_utils');
jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: (input) => `${input}1`,
}));

describe('LogsDrawer', () => {
  let wrapper;

  const findDrawer = () => wrapper.findComponent(GlDrawer);

  const mockLog = mockLogs[0];

  const testTracingIndexUrl = 'https://tracing-index-url.com';
  const testCreateIssueUrl = 'https://create-issue-url.com';
  const testProjectFullPath = 'foo/bar';

  const mountComponent = ({ open = true, log = mockLog } = {}) => {
    wrapper = shallowMountExtended(LogsDrawer, {
      propsData: {
        log,
        open,
        tracingIndexUrl: testTracingIndexUrl,
        createIssueUrl: testCreateIssueUrl,
        projectFullPath: testProjectFullPath,
      },
      stubs: {
        RelatedIssuesProvider: stubComponent(RelatedIssuesProvider, {
          template: `<div>
            <slot :issues="[]" :loading="false" :error="null" />
          </div>`,
        }),
      },
    });
  };

  const findSection = (sectionId) => {
    const section = wrapper.findByTestId(sectionId);
    const title = section.find('[data-testid="section-title"]').text();
    const lines = section.findAll('[data-testid="section-line"]').wrappers.map((w) => ({
      name: w.find('[data-testid="section-line-name"]').text(),
      value: w.find('[data-testid="section-line-value"]').text(),
    }));
    return {
      title,
      lines,
    };
  };

  const findRelatedIssues = () => wrapper.findComponent(RelatedIssue);
  const findRelatedIssuesProvider = () => wrapper.findComponent(RelatedIssuesProvider);
  const findRelatedIssuesBadge = () => wrapper.findComponent(RelatedIssuesBadge);

  const getSectionLineWrapperByName = (name) =>
    wrapper
      .findByTestId('section-log-details')
      .findAll('[data-testid="section-line"]')
      .wrappers.find((w) => w.find('[data-testid="section-line-name"]').text() === name);

  beforeEach(() => {
    setWindowLocation('http://test.gdk/logs?fingerprint=1234');
    mountComponent();
  });

  it('renders the component properly', () => {
    expect(wrapper.exists()).toBe(true);
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props('open')).toBe(true);
    expect(findDrawer().attributes('id')).toBe('log-drawer-1');
  });

  it('renders the related-issue-provider', () => {
    expect(findRelatedIssuesProvider().props()).toEqual({
      projectFullPath: testProjectFullPath,
      log: mockLog,
    });
  });

  it('renders the relate issues badge', () => {
    expect(findRelatedIssuesBadge().props()).toStrictEqual({
      issuesTotal: 0,
      loading: false,
      error: null,
      anchorId: 'related-issues-1',
      parentScrollingId: 'log-drawer-1',
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

  it('emits close', () => {
    findDrawer().vm.$emit('close');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('displays the correct title', () => {
    expect(wrapper.findByTestId('drawer-title').text()).toContain('Jan 28 2024 10:36:08.296 UTC');
  });

  it.each([
    [
      'section-log-details',
      'Metadata',
      [
        { name: 'body', value: mockLog.body },
        { name: 'fingerprint', value: mockLog.fingerprint },
        { name: 'service_name', value: mockLog.service_name },
        { name: 'severity_number', value: `${mockLog.severity_number}` },
        { name: 'severity_text', value: mockLog.severity_text },
        { name: 'span_id', value: mockLog.span_id },
        { name: 'timestamp', value: mockLog.timestamp },
        { name: 'trace_flags', value: `${mockLog.trace_flags}` },
        { name: 'trace_id', value: mockLog.trace_id },
      ],
    ],
    [
      'section-log-attributes',
      'Attributes',
      [
        {
          name: 'userId',
          value: mockLog.log_attributes.userId,
        },
      ],
    ],
    [
      'section-resource-attributes',
      'Resource attributes',
      [
        {
          name: 'container.id',
          value: mockLog.resource_attributes['container.id'],
        },
        { name: 'k8s.deployment.name', value: mockLog.resource_attributes['k8s.deployment.name'] },
      ],
    ],
  ])('displays the %s section in expected order', (sectionId, expectedTitle, expectedLines) => {
    const { title, lines } = findSection(sectionId);
    expect(title).toBe(expectedTitle);
    expect(lines).toEqual(expectedLines);
  });

  it.each([
    ['log_attributes', 'section-log-attributes'],
    ['resource_attributes', 'section-resource-attributes'],
  ])('if %s is missing, it does not render %s', (attrKey, sectionId) => {
    mountComponent({ log: { ...mockLog, [attrKey]: undefined } });
    expect(wrapper.findByTestId(sectionId).exists()).toBe(false);
  });

  it('renders a link to the trace', () => {
    const traceLine = getSectionLineWrapperByName('trace_id');
    expect(traceLine.findComponent(GlLink).exists()).toBe(true);
    expect(traceLine.findComponent(GlLink).attributes('href')).toBe(
      `${testTracingIndexUrl}/trace-id`,
    );
  });

  describe('with no log', () => {
    beforeEach(() => {
      mountComponent({ log: null });
    });

    it('does not render any section', () => {
      expect(wrapper.findByTestId('section-log-details').exists()).toBe(false);
      expect(wrapper.findByTestId('section-log-attributes').exists()).toBe(false);
      expect(wrapper.findByTestId('section-resource-attributes').exists()).toBe(false);
    });

    it('sets the log prop to null on the related-issues-provider', () => {
      expect(wrapper.findComponent(RelatedIssuesProvider).props('log')).toBeNull();
    });
  });

  describe('header height', () => {
    beforeEach(() => {
      getContentWrapperHeight.mockClear();
      getContentWrapperHeight.mockReturnValue(`1234px`);
    });

    it('does not set the header height if not open', () => {
      mountComponent({ open: false });

      expect(findDrawer().props('headerHeight')).toBe('0');
      expect(getContentWrapperHeight).not.toHaveBeenCalled();
    });

    it('sets the header height to match contentWrapperHeight if open', async () => {
      mountComponent({ open: true });
      await nextTick();

      expect(findDrawer().props('headerHeight')).toBe('1234px');
      expect(getContentWrapperHeight).toHaveBeenCalled();
    });
  });

  it('renders the create issue button', () => {
    const button = wrapper.findComponent(GlButton);
    expect(button.text()).toBe('Create issue');
    const logsDetails = {
      body: mockLog.body,
      fingerprint: mockLog.fingerprint,
      fullUrl: 'http://test.gdk/logs?fingerprint=1234',
      service: mockLog.service_name,
      severityNumber: mockLog.severity_number,
      timestamp: mockLog.timestamp,
      traceId: mockLog.trace_id,
    };
    expect(button.attributes('href')).toBe(
      `${testCreateIssueUrl}?observability_log_details=${encodeURIComponent(
        JSON.stringify(logsDetails),
      )}&${encodeURIComponent('issue[confidential]')}=true`,
    );
  });
});
