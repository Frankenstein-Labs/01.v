import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GlobalSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/global_settings.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import AgeFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/age_filter.vue';
import AttributeFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filters.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import {
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  STATUS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('GlobalSettings', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    severity_levels: [],
    vulnerability_states: ['new_needs_triage', 'detected', 'existing'],
    vulnerability_attributes: {
      [FIX_AVAILABLE]: true,
    },
  };

  const createComponent = (scanner = defaultRule) => {
    wrapper = shallowMountExtended(GlobalSettings, {
      propsData: {
        scanner,
      },
    });
  };

  const findSeverityFilter = () => wrapper.findComponent(SeverityFilter);
  const findStatusFilters = () => wrapper.findComponent(StatusFilters);
  const findAgeFilter = () => wrapper.findComponent(AgeFilter);
  const findAttributeFilters = () => wrapper.findComponent(AttributeFilters);
  const findFilterSelector = () => wrapper.findComponent(ScanFilterSelector);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders severity filter', () => {
      expect(findSeverityFilter().exists()).toBe(true);
    });

    it('renders status filters when status filter is selected', () => {
      expect(findStatusFilters().exists()).toBe(true);
    });

    it('renders attribute filters when attribute filter is selected', () => {
      expect(findAttributeFilters().exists()).toBe(true);
    });

    it('renders scan filter selector', () => {
      expect(findFilterSelector().exists()).toBe(true);
    });
  });

  describe('existing rule', () => {
    beforeEach(() => {
      createComponent({
        ...defaultRule,
        vulnerability_age: {
          operator: 'less_than',
          value: 1,
          interval: 'day',
        },
      });
    });

    it('returns all severity levels when none are defined', () => {
      expect(findSeverityFilter().props('selected')).toEqual(Object.keys(SEVERITY_LEVELS));
    });

    it('returns vulnerability age from initRule', () => {
      expect(findAgeFilter().props('selected')).toEqual({
        operator: 'less_than',
        value: 1,
        interval: 'day',
      });
    });

    it('returns vulnerability attributes', () => {
      expect(findAttributeFilters().props('selected')).toEqual({ [FIX_AVAILABLE]: true });
    });
  });

  describe('events', () => {
    describe('components visible by default', () => {
      beforeEach(() => {
        createComponent();
      });

      it('emits changed event when severity levels change', () => {
        const newLevels = ['high'];

        findSeverityFilter().vm.$emit('input', newLevels);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toMatchObject({
          severity_levels: newLevels,
        });
      });

      it('updates vulnerability states', () => {
        expect(findStatusFilters().props('selected')).toEqual({
          [NEWLY_DETECTED]: ['new_needs_triage'],
          [PREVIOUSLY_EXISTING]: ['detected'],
        });

        findStatusFilters().vm.$emit('input', {
          [NEWLY_DETECTED]: ['new_needs_triage', 'new_dismissed'],
          [PREVIOUSLY_EXISTING]: ['detected', 'dismissed'],
        });

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              ...defaultRule,
              vulnerability_states: ['new_needs_triage', 'new_dismissed', 'detected', 'dismissed'],
            },
          ],
        ]);
      });
    });

    describe('components visible when certain properties selected', () => {
      describe('vulnerability age', () => {
        beforeEach(() => {
          createComponent({
            ...defaultRule,
            vulnerability_age: {
              operator: 'less_than',
              value: 1,
              interval: 'day',
            },
          });
        });

        it('updates vulnerability age', () => {
          const payload = { value: 1, interval: 'month', operator: 'less_than' };

          expect(findAgeFilter().props('selected')).toEqual({
            operator: 'less_than',
            value: 1,
            interval: 'day',
          });

          findAgeFilter().vm.$emit('input', payload);

          expect(wrapper.emitted('changed')).toEqual([
            [{ ...defaultRule, vulnerability_age: payload }],
          ]);
        });

        it('removes age filter when remove is triggered', () => {
          findAgeFilter().vm.$emit('remove');

          expect(wrapper.emitted('changed')[0][0]).not.toHaveProperty('vulnerability_age');
        });
      });

      describe('vulnerability attributes', () => {
        beforeEach(() => {
          createComponent({
            ...defaultRule,
            vulnerability_attributes: {
              [FIX_AVAILABLE]: true,
            },
          });
        });

        it('updates vulnerability attribute', () => {
          const payload = { [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: false };

          expect(findAttributeFilters().props('selected')).toEqual({ [FIX_AVAILABLE]: true });

          findAttributeFilters().vm.$emit('input', payload);

          expect(wrapper.emitted('changed')).toEqual([
            [{ ...defaultRule, vulnerability_attributes: payload }],
          ]);
        });
      });
    });
  });

  describe('selecting filter', () => {
    beforeEach(() => {
      createComponent({ ...defaultRule, vulnerability_states: ['new_needs_triage'] });
    });

    it('adds new status filter', async () => {
      expect(findStatusFilters().props('selected')).toEqual({
        [NEWLY_DETECTED]: ['new_needs_triage'],
        [PREVIOUSLY_EXISTING]: undefined,
      });
      await findFilterSelector().vm.$emit('select', STATUS);

      expect(findFilterSelector().props('selected')).toEqual({
        age: false,
        newly_detected: true,
        previously_existing: true,
        false_positive: false,
        fix_available: true,
        status: false,
        attribute: false,
      });
    });
  });
});
