import { GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OptimizedScanSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/optimized_scan_selector.vue';
import {
  REPORT_TYPE_SAST,
  REPORT_TYPE_SECRET_DETECTION,
} from '~/vue_shared/security_reports/constants';
import { SCAN_EXECUTION_SCANNERS } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { buildScannerAction } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';

const OPTIMIZED_SCANNER_COUNT = Object.keys(SCAN_EXECUTION_SCANNERS).length - 1;

describe('OptimizedScanSelector', () => {
  let wrapper;

  const createComponent = ({ actions = [], disabled = false } = {}) => {
    wrapper = shallowMountExtended(OptimizedScanSelector, {
      propsData: {
        actions,
        disabled,
      },
    });
  };

  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findCheckboxByScanner = (scanner) => wrapper.findComponentByTestId(`${scanner}-checkbox`);

  const createOptimizedScanAction = (scanner) => buildScannerAction({ scanner, isOptimized: true });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a title', () => {
      expect(wrapper.find('h5').text()).toBe('Security scans to execute');
    });

    it('does not render checkbox for DAST', () => {
      expect(findCheckboxes()).toHaveLength(OPTIMIZED_SCANNER_COUNT);
      expect(wrapper.text()).not.toContain('DAST');
    });

    it('does not render a checkbox for DAST', () => {
      const dastCheckbox = findCheckboxByScanner('dast');
      expect(dastCheckbox.exists()).toBe(false);
    });
  });

  describe('checkbox state', () => {
    it('checks boxes for selected scanners', () => {
      createComponent({
        actions: [createOptimizedScanAction(REPORT_TYPE_SAST)],
      });

      const sastCheckbox = findCheckboxByScanner(REPORT_TYPE_SAST);
      const secretDetectionCheckbox = findCheckboxByScanner(REPORT_TYPE_SECRET_DETECTION);

      expect(sastCheckbox.attributes('checked')).toBe('true');
      expect(secretDetectionCheckbox.attributes('checked')).toBe(undefined);
    });

    it('disables unselected checkboxes when disabled prop is true', () => {
      createComponent({
        actions: [createOptimizedScanAction(REPORT_TYPE_SAST)],
        disabled: true,
      });

      const sastCheckbox = findCheckboxByScanner(REPORT_TYPE_SAST);
      const secretDetectionCheckbox = findCheckboxByScanner(REPORT_TYPE_SECRET_DETECTION);

      // Selected scanner should not be disabled
      expect(sastCheckbox.attributes().disabled).toBe(undefined);
      // Unselected scanner should be disabled
      expect(secretDetectionCheckbox.attributes().disabled).toBe('true');
    });

    it('does not disable any checkboxes when disabled prop is false', () => {
      createComponent({
        actions: [createOptimizedScanAction(REPORT_TYPE_SAST)],
        disabled: false,
      });

      const sastCheckbox = findCheckboxByScanner(REPORT_TYPE_SAST);
      const secretDetectionCheckbox = findCheckboxByScanner(REPORT_TYPE_SECRET_DETECTION);

      expect(sastCheckbox.attributes().disabled).toBe(undefined);
      expect(secretDetectionCheckbox.attributes().disabled).toBe(undefined);
    });
    it('handles empty actions', () => {
      createComponent({ actions: [] });

      findCheckboxes().wrappers.forEach((checkbox) => {
        expect(checkbox.attributes('checked')).toBe(undefined);
      });
    });
  });

  describe('events', () => {
    it('emits change event with correct payload when checkbox is checked', async () => {
      createComponent();
      const checkbox = findCheckboxByScanner(REPORT_TYPE_SAST);

      await checkbox.vm.$emit('change', true);

      expect(wrapper.emitted().change).toHaveLength(1);
      expect(wrapper.emitted().change[0]).toEqual([{ enabled: true, scanner: REPORT_TYPE_SAST }]);
    });

    it('emits change event with correct payload when checkbox is unchecked', async () => {
      createComponent({
        actions: [createOptimizedScanAction(REPORT_TYPE_SAST)],
      });

      const checkbox = findCheckboxByScanner(REPORT_TYPE_SAST);
      await checkbox.vm.$emit('change', false);

      expect(wrapper.emitted().change).toHaveLength(1);
      expect(wrapper.emitted().change[0]).toEqual([{ enabled: false, scanner: REPORT_TYPE_SAST }]);
    });
  });
});
