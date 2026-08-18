import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LicenseComplianceContent from 'ee/merge_requests/reports/license_compliance/license_compliance_content.vue';
import ReportSection from '~/merge_requests/reports/components/report_section.vue';

describe('LicenseComplianceContent', () => {
  let wrapper;

  const DEFAULT_MR_PROPS = {
    licenseCompliance: {
      license_scanning: { full_report_path: '/full-report' },
    },
  };

  const MOCK_SECTIONS = [{ header: 'Denied', text: 'Out-of-compliance', children: [] }];
  const LICENSE_REPORT_STATUS_MESSAGE =
    'This merge request does not have license scanning reports.';
  const LICENSE_REPORT_ERROR_MESSAGE = 'License Compliance failed loading results';

  const DEFAULT_PROVIDE = {
    newLicensesCount: 3,
    existingLicensesCount: 5,
    hasDeniedLicense: false,
    hasApprovalRequired: false,
    isLicenseComplianceLoading: false,
    statusIconName: 'warning',
    statusMessage: '',
    errorMessage: '',
    sections: MOCK_SECTIONS,
    loadingMessage: 'License Compliance test metrics results are being parsed',
  };

  const findReportSection = () => wrapper.findComponent(ReportSection);

  const createComponent = ({ provide = {}, mr = DEFAULT_MR_PROPS } = {}) => {
    wrapper = shallowMountExtended(LicenseComplianceContent, {
      propsData: { mr },
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
    });
  };

  describe('rendering', () => {
    it('renders ReportSection', () => {
      createComponent();

      expect(findReportSection().exists()).toBe(true);
    });

    it('passes isLoading to ReportSection', () => {
      createComponent({ provide: { isLicenseComplianceLoading: true } });

      expect(findReportSection().props('isLoading')).toBe(true);
    });

    it('passes loading text to ReportSection', () => {
      createComponent();

      expect(findReportSection().props('loadingText')).toContain(
        'License Compliance test metrics results are being parsed',
      );
    });
  });

  describe('summary text', () => {
    it('shows new license count', () => {
      createComponent();

      expect(findReportSection().props('summary').title).toContain('3');
    });

    it('shows "no new licenses" when existing licenses exist', () => {
      createComponent({ provide: { newLicensesCount: 0, existingLicensesCount: 5 } });

      expect(findReportSection().props('summary').title).toContain('detected no new licenses');
    });

    it('shows "no licenses for the source branch only" when no existing licenses', () => {
      createComponent({ provide: { newLicensesCount: 0, existingLicensesCount: 0 } });

      expect(findReportSection().props('summary').title).toContain(
        'detected no licenses for the source branch only',
      );
    });

    it('shows policy violation when denied', () => {
      createComponent({ provide: { newLicensesCount: 1, hasDeniedLicense: true } });

      expect(findReportSection().props('summary').title).toContain('policy violation');
    });

    it('shows approval required when denied and approval required', () => {
      createComponent({
        provide: { newLicensesCount: 1, hasDeniedLicense: true, hasApprovalRequired: true },
      });

      expect(findReportSection().props('summary').title).toContain('approval required');
    });
  });

  describe('status icon', () => {
    it('passes statusIconName from provider', () => {
      createComponent({ provide: { statusIconName: 'error' } });

      expect(findReportSection().props('statusIconName')).toBe('error');
    });

    it('passes default statusIconName', () => {
      createComponent();

      expect(findReportSection().props('statusIconName')).toBe('warning');
    });
  });

  describe('help popover', () => {
    it('passes help popover to ReportSection', () => {
      createComponent();

      const { helpPopover } = findReportSection().props();

      expect(helpPopover.options.title).toContain('License scan results');
      expect(helpPopover.content.learnMorePath).toContain('license_approval_policies');
    });

    it('passes null for help popover when statusMessage is set', () => {
      createComponent({
        provide: { statusMessage: LICENSE_REPORT_STATUS_MESSAGE },
      });

      expect(findReportSection().props('helpPopover')).toBeNull();
    });

    it('passes null for help popover when fullReportPath is missing', () => {
      createComponent({ mr: {} });

      expect(findReportSection().props('helpPopover')).toBeNull();
    });
  });

  describe('action buttons', () => {
    it('passes full report action button to ReportSection', () => {
      createComponent();

      expect(findReportSection().props('actionButtons')).toEqual([
        expect.objectContaining({
          text: expect.stringContaining('Full report'),
          href: '/full-report',
        }),
      ]);
    });

    it('passes empty action buttons when statusMessage is set', () => {
      createComponent({
        provide: { statusMessage: LICENSE_REPORT_STATUS_MESSAGE },
      });

      expect(findReportSection().props('actionButtons')).toEqual([]);
    });

    it('passes empty action buttons when fullReportPath is missing', () => {
      createComponent({ mr: {} });

      expect(findReportSection().props('actionButtons')).toEqual([]);
    });

    it('passes action buttons when errorMessage is set but no statusMessage', () => {
      createComponent({
        provide: { errorMessage: LICENSE_REPORT_ERROR_MESSAGE },
      });

      expect(findReportSection().props('actionButtons')).toEqual([
        expect.objectContaining({
          text: expect.stringContaining('Full report'),
          href: '/full-report',
        }),
      ]);
    });
  });

  describe('sections', () => {
    it('passes sections to ReportSection', () => {
      createComponent();

      expect(findReportSection().props('sections')).toEqual(MOCK_SECTIONS);
    });

    it('passes empty sections when none provided', () => {
      createComponent({ provide: { sections: [] } });

      expect(findReportSection().props('sections')).toEqual([]);
    });
  });

  describe('error handling', () => {
    it('shows error message as summary text when errorMessage is set', () => {
      createComponent({
        provide: { errorMessage: LICENSE_REPORT_ERROR_MESSAGE, statusIconName: 'error' },
      });

      expect(findReportSection().props('summary').title).toBe(LICENSE_REPORT_ERROR_MESSAGE);
    });

    it('shows status message as summary text when statusMessage is set', () => {
      createComponent({
        provide: { statusMessage: LICENSE_REPORT_STATUS_MESSAGE, statusIconName: 'warning' },
      });

      expect(findReportSection().props('summary').title).toBe(LICENSE_REPORT_STATUS_MESSAGE);
    });

    it('shows statusMessage over errorMessage when both are set', () => {
      createComponent({
        provide: {
          statusMessage: LICENSE_REPORT_STATUS_MESSAGE,
          errorMessage: LICENSE_REPORT_ERROR_MESSAGE,
          statusIconName: 'warning',
        },
      });

      expect(findReportSection().props('summary').title).toBe(LICENSE_REPORT_STATUS_MESSAGE);
    });
  });
});
