import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScannerStatusIcon from 'ee/security_configuration/components/scan_profiles/scanner_status_icon.vue';
import {
  SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
  SCAN_PROFILE_SCANNER_HEALTH_STALE,
  SCAN_PROFILE_SCANNER_HEALTH_PENDING,
  SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED,
} from '~/security_configuration/constants';
import {
  GROUP_STATUS_ENABLED,
  GROUP_STATUS_FAILED,
  GROUP_STATUS_NOT_ENABLED,
  GROUP_STATUS_PENDING,
  GROUP_STATUS_STALE,
  GROUP_STATUS_WARNING,
} from 'ee/security_configuration/constants';

describe('ScannerStatusIcon', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(ScannerStatusIcon, { propsData });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findStatusText = () => wrapper.findByTestId('scanner-status');
  const findDetailText = () => wrapper.findByTestId('scanner-status-details');

  describe('icon name and class', () => {
    it.each([
      [SCAN_PROFILE_SCANNER_HEALTH_ACTIVE, 'status-success', 'gl-text-success'],
      [GROUP_STATUS_ENABLED, 'status-success', 'gl-text-success'],
      [SCAN_PROFILE_SCANNER_HEALTH_FAILED, 'status-failed', 'gl-text-danger'],
      [SCAN_PROFILE_SCANNER_HEALTH_WARNING, 'status_warning', 'gl-text-warning'],
      [SCAN_PROFILE_SCANNER_HEALTH_STALE, 'status-scheduled', 'gl-text-subtle'],
      [SCAN_PROFILE_SCANNER_HEALTH_PENDING, 'status-waiting', 'gl-text-subtle'],
      [SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED, 'clear', 'gl-text-subtle'],
      [GROUP_STATUS_NOT_ENABLED, 'clear', 'gl-text-subtle'],
    ])('renders correct icon for %s status', (status, expectedIcon, expectedClass) => {
      createComponent({ status });
      expect(findIcon().props('name')).toBe(expectedIcon);
      expect(findIcon().classes()).toContain(expectedClass);
    });

    it('renders fallback icon for unknown status', () => {
      createComponent({ status: 'unknown' });
      expect(findIcon().props('name')).toBe('status_failed');
      expect(findIcon().classes()).toContain('gl-text-subtle');
    });
  });

  describe('render scanner status label', () => {
    it.each([
      [GROUP_STATUS_ENABLED, 'Enabled'],
      [GROUP_STATUS_NOT_ENABLED, 'Not enabled'],
      [SCAN_PROFILE_SCANNER_HEALTH_ACTIVE, 'Active'],
      [SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED, 'Unconfigured'],
      [SCAN_PROFILE_SCANNER_HEALTH_PENDING, 'Pending'],
      [SCAN_PROFILE_SCANNER_HEALTH_FAILED, 'Failed'],
      [SCAN_PROFILE_SCANNER_HEALTH_WARNING, 'Warning'],
      [SCAN_PROFILE_SCANNER_HEALTH_STALE, 'Stale'],
    ])('renders "%s" label for %s status', (status, expectedLabel) => {
      createComponent({ status });
      expect(findStatusText().text().trim()).toBe(expectedLabel);
    });
  });

  describe('combined status when a profile is layered under a failed analyzer', () => {
    it.each([
      [GROUP_STATUS_ENABLED, 'Enabled, last scan failed'],
      [GROUP_STATUS_PENDING, 'Pending, last scan failed'],
    ])('renders "%s" combined with the failure', (profileStatus, expectedLabel) => {
      createComponent({ status: GROUP_STATUS_FAILED, profileStatus });
      expect(findStatusText().text().trim()).toBe(expectedLabel);
    });

    it('keeps the red failed icon so the row reads as degraded', () => {
      createComponent({
        status: GROUP_STATUS_FAILED,
        profileStatus: GROUP_STATUS_ENABLED,
      });
      expect(findIcon().props('name')).toBe('status-failed');
      expect(findIcon().classes()).toContain('gl-text-danger');
    });

    it.each([
      ['warning', GROUP_STATUS_WARNING],
      ['failed', GROUP_STATUS_FAILED],
      ['stale', GROUP_STATUS_STALE],
      ['not enabled', GROUP_STATUS_NOT_ENABLED],
    ])(
      'does not combine when the profile status is %s (already conveys a scan concern or a non-healthy state)',
      (_, profileStatus) => {
        createComponent({ status: GROUP_STATUS_FAILED, profileStatus });
        expect(findStatusText().text().trim()).toBe('Failed');
      },
    );

    it('renders the plain "Failed" label when no profile status is provided', () => {
      createComponent({ status: GROUP_STATUS_FAILED });
      expect(findStatusText().text().trim()).toBe('Failed');
    });
  });

  describe('render scanner status details', () => {
    describe('enabled status', () => {
      it('shows consecutive success count when available', () => {
        createComponent({ status: GROUP_STATUS_ENABLED, consecutiveSuccessCount: 3 });
        expect(findDetailText().text()).toContain('3');
      });

      it('shows nothing when consecutiveSuccessCount is not available', () => {
        createComponent({ status: GROUP_STATUS_ENABLED });
        expect(findDetailText().text().trim()).toBe('');
      });
    });

    describe('not enabled status', () => {
      it('shows "Apply profile to enable"', () => {
        createComponent({ status: GROUP_STATUS_NOT_ENABLED });
        expect(findDetailText().text().trim()).toBe('Apply profile to enable');
      });
    });

    describe('active status', () => {
      it('shows consecutive success count when available', () => {
        createComponent({ status: SCAN_PROFILE_SCANNER_HEALTH_ACTIVE, consecutiveSuccessCount: 5 });
        expect(findDetailText().text()).toContain('5');
      });

      it('shows nothing when consecutiveSuccessCount is zero', () => {
        createComponent({ status: SCAN_PROFILE_SCANNER_HEALTH_ACTIVE, consecutiveSuccessCount: 0 });
        expect(findDetailText().text().trim()).toBe('');
      });
    });

    describe('failed status', () => {
      it('shows consecutive failure count when available', () => {
        createComponent({ status: SCAN_PROFILE_SCANNER_HEALTH_FAILED, consecutiveFailureCount: 2 });
        expect(findDetailText().text()).toContain('2');
      });

      it('shows nothing when consecutiveFailureCount is not available', () => {
        createComponent({ status: SCAN_PROFILE_SCANNER_HEALTH_FAILED });
        expect(findDetailText().text().trim()).toBe('');
      });
    });
  });
});
