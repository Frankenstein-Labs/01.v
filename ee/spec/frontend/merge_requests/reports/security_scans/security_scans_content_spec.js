import { nextTick } from 'vue';
import { GlButton, GlDisclosureDropdown, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import SecurityScansContent from 'ee/merge_requests/reports/security_scans/security_scans_content.vue';
import StatusIcon from '~/vue_merge_request_widget/components/widget/status_icon.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';

describe('SecurityScansContent', () => {
  let wrapper;

  const DEFAULT_MR_PROPS = {
    id: 12345,
    targetProjectFullPath: 'gitlab-org/gitlab',
    sourceProjectFullPath: 'namespace/project',
    sourceBranch: 'feature-branch',
    iid: 456,
    isPipelineActive: false,
    pipeline: {
      iid: 123,
      path: '/root/project/-/pipelines/123',
    },
  };

  const mockUpdateFindingState = jest.fn();

  const DEFAULT_PROVIDE = {
    findingReports: [],
    totalNewFindings: 0,
    highlights: {},
    topLevelErrorMessage: '',
    hasAtLeastOneReportWithMaxNewVulnerabilities: false,
    hasFindingReportErrors: false,
    hasFindings: false,
    hasEnabledScans: true,
    isLoadingScans: false,
    loadingMessage: '',
    statusMessage: '',
    statusIconName: 'success',
    updateFindingState: mockUpdateFindingState,
  };

  const createComponent = ({ mr = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(SecurityScansContent, {
      propsData: {
        mr: { ...DEFAULT_MR_PROPS, ...mr },
      },
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      stubs: {
        GlButton,
        VulnerabilityFindingModal: stubComponent(VulnerabilityFindingModal),
      },
    });
  };

  const findSecurityScansSummary = () => wrapper.findByTestId('security-scans-summary');
  const findStatusIcon = () => wrapper.findComponent(StatusIcon);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findActionButton = () => wrapper.findByText('View all pipeline findings');
  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findHelpPopover = () => wrapper.findComponent(HelpPopover);
  const findLearnMoreLink = () => findHelpPopover().findComponent(GlLink);
  const findReportDetails = () => wrapper.findAllComponents(ReportDetails);
  const findVulnerabilityFindingModal = () =>
    wrapper.findComponentByTestId('vulnerability-finding-modal');

  describe('rendering states', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createComponent({ provide: { isLoadingScans: true, loadingMessage: 'Loading…' } });
      });

      it('renders summary', () => {
        expect(findSecurityScansSummary().exists()).toBe(true);
      });

      it('shows StatusIcon with isLoading true', () => {
        expect(findStatusIcon().props('isLoading')).toBe(true);
      });

      it('displays loading message', () => {
        expect(findSecurityScansSummary().text()).toContain('Loading…');
      });

      it('does not render SummaryText', () => {
        expect(findSummaryText().exists()).toBe(false);
      });

      it('does not show actions', () => {
        expect(findActionButton().exists()).toBe(false);
      });

      it('does not show help popover', () => {
        expect(findHelpPopover().exists()).toBe(false);
      });
    });

    describe('when no pipeline', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            statusMessage:
              'No security scan results. Either CI/CD is not configured or the pipeline is not yet complete.',
            statusIconName: 'warning',
          },
          mr: { pipeline: {} },
        });
      });

      it('renders summary', () => {
        expect(findSecurityScansSummary().exists()).toBe(true);
      });

      it('displays status message', () => {
        expect(findSecurityScansSummary().text()).toContain(
          'No security scan results. Either CI/CD is not configured or the pipeline is not yet complete.',
        );
      });

      it('does not show actions when no pipeline path', () => {
        expect(findActionButton().exists()).toBe(false);
      });
    });

    describe('when error', () => {
      const errorMessage = 'Error while fetching enabled scans';

      beforeEach(() => {
        createComponent({
          provide: {
            statusMessage: errorMessage,
            statusIconName: 'error',
            topLevelErrorMessage: errorMessage,
            hasEnabledScans: true,
          },
        });
      });

      it('renders summary', () => {
        expect(findSecurityScansSummary().exists()).toBe(true);
      });

      it('displays error message', () => {
        expect(findSecurityScansSummary().text()).toContain(errorMessage);
      });

      it('shows error icon', () => {
        expect(findStatusIcon().props('iconName')).toBe('error');
      });

      it('still shows action button', () => {
        expect(findSecurityScansSummary().text()).toContain('View all pipeline findings');
      });

      it('shows help popover', () => {
        expect(findHelpPopover().exists()).toBe(true);
      });

      it('renders disclosure dropdown', () => {
        expect(findDisclosureDropdown().exists()).toBe(true);
      });
    });

    describe('when no scans are enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            statusMessage: 'No security scans enabled.',
            statusIconName: 'warning',
            hasEnabledScans: false,
          },
        });
      });

      it('renders summary', () => {
        expect(findSecurityScansSummary().exists()).toBe(true);
      });

      it('displays status message', () => {
        expect(findSecurityScansSummary().text()).toContain('No security scans enabled.');
      });

      it('does not show actions when no scans are enabled', () => {
        expect(findActionButton().exists()).toBe(false);
      });

      it('does not show help popover', () => {
        expect(findHelpPopover().exists()).toBe(false);
      });
    });

    describe('when pipeline is active', () => {
      it('shows loading message', () => {
        createComponent({
          provide: {
            isLoadingScans: true,
            loadingMessage: 'Security scanning is waiting for the pipeline to complete.',
          },
        });

        expect(findSecurityScansSummary().text()).toContain(
          'Security scanning is waiting for the pipeline to complete.',
        );
      });
    });

    describe('when ready with scans enabled', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders summary', () => {
        expect(findSecurityScansSummary().exists()).toBe(true);
      });

      it('shows StatusIcon with isLoading false', () => {
        expect(findStatusIcon().props('isLoading')).toBe(false);
      });
    });
  });

  describe('StatusIcon', () => {
    it.each`
      scenario            | statusIconName | expected
      ${'error'}          | ${'error'}     | ${'error'}
      ${'findings exist'} | ${'warning'}   | ${'warning'}
      ${'no findings'}    | ${'success'}   | ${'success'}
    `('shows $expected icon when $scenario', ({ statusIconName, expected }) => {
      createComponent({ provide: { statusIconName } });

      expect(findStatusIcon().props('iconName')).toBe(expected);
    });
  });

  describe('SummaryText', () => {
    it('passes totalNewVulnerabilities', () => {
      createComponent({ provide: { totalNewFindings: 5 } });

      expect(findSummaryText().props('totalNewVulnerabilities')).toBe(5);
    });

    it('passes isLoading as false in happy path', () => {
      createComponent();

      expect(findSummaryText().props('isLoading')).toBe(false);
    });

    it('passes showAtLeastHint when report has max vulnerabilities', () => {
      createComponent({ provide: { hasAtLeastOneReportWithMaxNewVulnerabilities: true } });

      expect(findSummaryText().props('showAtLeastHint')).toBe(true);
    });
  });

  describe('SummaryHighlights', () => {
    it('does not render when totalNewFindings is 0', () => {
      createComponent({ provide: { totalNewFindings: 0 } });

      expect(findSummaryHighlights().exists()).toBe(false);
    });

    it('does not render when loading', () => {
      createComponent({
        provide: { totalNewFindings: 5, isLoadingScans: true, loadingMessage: 'Loading…' },
      });

      expect(findSummaryHighlights().exists()).toBe(false);
    });

    it('renders when findings exist and not loading', () => {
      createComponent({
        provide: {
          totalNewFindings: 5,
          highlights: { [CRITICAL]: 1, [HIGH]: 2, other: 2 },
        },
      });

      expect(findSummaryHighlights().exists()).toBe(true);
    });

    it('passes highlights prop', () => {
      const highlights = { [CRITICAL]: 1, [HIGH]: 2, other: 2 };
      createComponent({
        provide: { totalNewFindings: 5, highlights },
      });

      expect(findSummaryHighlights().props('highlights')).toEqual(highlights);
    });
  });

  describe('Action Button', () => {
    const MOCK_BUTTON_HREF = '/root/project/-/pipelines/123/security';
    const findPipelineSecurityButton = () =>
      wrapper
        .findAllComponents(GlButton)
        .wrappers.find((w) => w.attributes('href')?.includes('/security'));

    beforeEach(() => {
      createComponent();
    });

    it('renders button with correct text', () => {
      expect(findActionButton().exists()).toBe(true);
    });

    it('links to pipeline security page', () => {
      expect(findPipelineSecurityButton().attributes('href')).toBe(MOCK_BUTTON_HREF);
    });

    it('returns undefined when pipeline path is missing', () => {
      createComponent({ mr: { pipeline: {} } });

      expect(findPipelineSecurityButton()).toBeUndefined();
    });

    it('renders disclosure dropdown with correct items', () => {
      expect(findDisclosureDropdown().props('items')).toEqual([
        {
          text: 'View all pipeline findings',
          href: MOCK_BUTTON_HREF,
        },
      ]);
    });

    it('does not render disclosure dropdown when pipeline path is missing', () => {
      createComponent({ mr: { pipeline: {} } });

      expect(findDisclosureDropdown().exists()).toBe(false);
    });
  });

  describe('HelpPopover', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes correct options prop', () => {
      expect(findHelpPopover().props('options')).toEqual({
        title: 'Security scan results',
      });
    });

    it('contains learn more link with correct href', () => {
      expect(findLearnMoreLink().attributes('href')).toBe(
        '/help/user/application_security/detect/security_scanning_results#merge-request-reports',
      );
    });
  });

  describe('ReportDetails', () => {
    it('does not render when loading', () => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindings: true,
          isLoadingScans: true,
          loadingMessage: 'Loading…',
        },
      });

      expect(findReportDetails()).toHaveLength(0);
    });

    it('renders ReportDetails for each report', () => {
      createComponent({
        provide: {
          findingReports: [
            { reportType: 'SAST', full: { numberOfNewFindings: 1 } },
            { reportType: 'DAST', full: { numberOfNewFindings: 2 } },
          ],
          hasFindings: true,
        },
      });

      expect(findReportDetails()).toHaveLength(2);
    });

    it('passes correct props to ReportDetails', () => {
      const report = { reportType: 'SAST', full: { numberOfNewFindings: 1 } };

      createComponent({
        provide: {
          findingReports: [report],
          hasFindings: true,
        },
      });

      expect(findReportDetails().at(0).props()).toMatchObject({
        report,
        mr: expect.objectContaining({ iid: DEFAULT_MR_PROPS.iid }),
        widgetName: 'SecurityScansContent',
        isReportsPage: true,
      });
    });

    it('does not render when no findings and no errors', () => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindings: false,
          hasFindingReportErrors: false,
        },
      });

      expect(findReportDetails()).toHaveLength(0);
    });

    it('renders when only fixed findings exist (no new findings)', () => {
      createComponent({
        provide: {
          findingReports: [
            { reportType: 'SAST', full: { numberOfNewFindings: 0, numberOfFixedFindings: 2 } },
          ],
          hasFindings: true,
          totalNewFindings: 0,
        },
      });

      expect(findReportDetails()).toHaveLength(1);
    });

    it('renders when hasFindings is true', () => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindings: true,
        },
      });

      expect(findReportDetails()).toHaveLength(1);
    });

    it('renders when hasFindingReportErrors is true', () => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindingReportErrors: true,
        },
      });

      expect(findReportDetails()).toHaveLength(1);
    });

    it('does not render when topLevelErrorMessage exists', () => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindings: true,
          topLevelErrorMessage: 'Error occurred',
        },
      });

      expect(findReportDetails()).toHaveLength(0);
    });

    it('does not render when statusMessage is set', () => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindings: true,
          statusMessage: 'No security scans enabled.',
        },
      });

      expect(findReportDetails()).toHaveLength(0);
    });
  });

  describe('VulnerabilityFindingModal', () => {
    const createFinding = (overrides = {}) => ({
      uuid: 'test-uuid',
      title: 'Test Vulnerability',
      foundByPipelineIid: 789,
      state: 'detected',
      ...overrides,
    });

    const openModalWithFinding = async (findingData) => {
      findReportDetails().at(0).vm.$emit('modal-data', findingData);
      await nextTick();
    };

    beforeEach(() => {
      createComponent({
        provide: {
          findingReports: [{ reportType: 'SAST', full: { numberOfNewFindings: 1 } }],
          hasFindings: true,
        },
      });
    });

    it('does not render modal by default', () => {
      expect(findVulnerabilityFindingModal().exists()).toBe(false);
    });

    it('renders modal when modal-data event is emitted', async () => {
      await openModalWithFinding(createFinding());

      expect(findVulnerabilityFindingModal().exists()).toBe(true);
    });

    it('passes correct props to modal', async () => {
      const finding = createFinding();
      await openModalWithFinding(finding);

      expect(findVulnerabilityFindingModal().props()).toMatchObject({
        findingUuid: finding.uuid,
        pipelineIid: finding.foundByPipelineIid,
        branchRef: DEFAULT_MR_PROPS.sourceBranch,
        projectFullPath: DEFAULT_MR_PROPS.targetProjectFullPath,
        sourceProjectFullPath: DEFAULT_MR_PROPS.sourceProjectFullPath,
        mergeRequestId: DEFAULT_MR_PROPS.id,
      });
    });

    it('clears modal when hidden event is emitted', async () => {
      await openModalWithFinding(createFinding());
      expect(findVulnerabilityFindingModal().exists()).toBe(true);

      findVulnerabilityFindingModal().vm.$emit('hidden');
      await nextTick();

      expect(findVulnerabilityFindingModal().exists()).toBe(false);
    });

    it('calls updateFindingState when dismissed event is emitted', async () => {
      const finding = createFinding();
      await openModalWithFinding(finding);

      findVulnerabilityFindingModal().vm.$emit('dismissed');
      await nextTick();

      expect(mockUpdateFindingState).toHaveBeenCalledWith(finding.uuid, 'dismissed');
    });

    it('calls updateFindingState when detected event is emitted', async () => {
      const finding = createFinding({ state: 'dismissed' });
      await openModalWithFinding(finding);

      findVulnerabilityFindingModal().vm.$emit('detected');
      await nextTick();

      expect(mockUpdateFindingState).toHaveBeenCalledWith(finding.uuid, 'detected');
    });

    describe('resolve with AI', () => {
      useMockLocationHelper();

      const aiCommentUrl = `${TEST_HOST}/project/merge_requests/2#note_1`;

      it('redirects and closes modal when resolve-with-ai-success is emitted', async () => {
        await openModalWithFinding(createFinding());

        findVulnerabilityFindingModal().vm.$emit('resolve-with-ai-success', aiCommentUrl);
        await nextTick();

        expect(window.location.assign).toHaveBeenCalledWith(aiCommentUrl);
        expect(findVulnerabilityFindingModal().exists()).toBe(false);
      });
    });
  });
});
