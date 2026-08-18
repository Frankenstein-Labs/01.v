import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LicenseComplianceNavItem from 'ee/merge_requests/reports/license_compliance/license_compliance_nav_item.vue';
import ReportListItem from '~/merge_requests/reports/components/report_list_item.vue';

describe('LicenseComplianceNavItem', () => {
  let wrapper;

  const findReportListItem = () => wrapper.findComponent(ReportListItem);

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(LicenseComplianceNavItem, {
      provide: {
        isLicenseComplianceLoading: false,
        statusIconName: 'success',
        ...provide,
      },
    });
  };

  describe('ReportListItem', () => {
    it('renders with correct route and text', () => {
      createComponent();

      expect(findReportListItem().text()).toBe('License compliance');
      expect(findReportListItem().props('to')).toBe('license-compliance');
    });

    it('passes isLoading to ReportListItem', () => {
      createComponent({ provide: { isLicenseComplianceLoading: true } });

      expect(findReportListItem().props('isLoading')).toBe(true);
    });
  });

  describe('statusIconName', () => {
    it('passes error icon', () => {
      createComponent({ provide: { statusIconName: 'error' } });

      expect(findReportListItem().props('statusIcon')).toBe('error');
    });

    it('passes warning icon', () => {
      createComponent({ provide: { statusIconName: 'warning' } });

      expect(findReportListItem().props('statusIcon')).toBe('warning');
    });

    it('passes success icon by default', () => {
      createComponent();

      expect(findReportListItem().props('statusIcon')).toBe('success');
    });
  });
});
