import { GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  DEFAULT_TIME_PER_UNIT,
  MAXIMUM_SECONDS,
  MINIMUM_SECONDS,
  TIME_UNITS,
} from 'ee/security_orchestration/components/policy_editor/shared/duration_selector/constants';
import DurationSelector from 'ee/security_orchestration/components/policy_editor/shared/duration_selector/duration_selector.vue';

describe('DurationSelector', () => {
  let wrapper;
  const getTimeWindowProp = (value) => ({ distribution: 'random', value });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DurationSelector, {
      propsData: { timeWindow: getTimeWindowProp(3600), ...props },
    });
  };

  const findDurationInput = () => wrapper.findComponent(GlFormInput);
  const findTimeUnitDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('rendering', () => {
    it('renders the time unit dropdown with correct options', () => {
      createComponent();
      const timeUnitDropdown = findTimeUnitDropdown();
      expect(timeUnitDropdown.exists()).toBe(true);
      expect(timeUnitDropdown.props('items')).toEqual([
        { value: TIME_UNITS.MINUTE, text: 'Minutes' },
        { value: TIME_UNITS.HOUR, text: 'Hours' },
        { value: TIME_UNITS.DAY, text: 'Days' },
      ]);
    });

    it('selects hours as default unit for 3600 seconds (1 hour)', () => {
      createComponent({ timeWindow: getTimeWindowProp(3600) });
      expect(findTimeUnitDropdown().props('selected')).toBe(TIME_UNITS.HOUR);
      expect(findDurationInput().props('value')).toBe(1);
    });

    it('selects days as default unit for 86400 seconds (1 day)', () => {
      createComponent({ timeWindow: getTimeWindowProp(86400) });
      expect(findTimeUnitDropdown().props('selected')).toBe(TIME_UNITS.DAY);
      expect(findDurationInput().props('value')).toBe(1);
    });

    it('selects minutes as default unit for non-divisible values', () => {
      createComponent({ timeWindow: getTimeWindowProp(400) });
      expect(findTimeUnitDropdown().props('selected')).toBe(TIME_UNITS.MINUTE);
      expect(findDurationInput().props('value')).toBe(6);
    });

    it('uses minimum value when duration would be 0', () => {
      createComponent({
        minimumSeconds: 600,
        timeWindow: getTimeWindowProp(0),
        timeWindowRequired: true,
      });
      expect(findDurationInput().props('value')).toBe(10);
    });

    it('uses 0 when time window is not required', () => {
      createComponent({ timeWindow: getTimeWindowProp(0) });
      expect(findDurationInput().props('value')).toBe(0);
    });
  });

  describe('hasError prop', () => {
    it('sets state to null on GlFormInput when hasError is false (default)', () => {
      createComponent();
      expect(findDurationInput().props('state')).toBeNull();
    });

    it('sets state to false on GlFormInput when hasError is true', () => {
      createComponent({ hasError: true });
      expect(findDurationInput().props('state')).toBe(false);
    });
  });

  describe('event handling', () => {
    it('updates time_window.value when duration value changes', async () => {
      createComponent({ timeWindow: getTimeWindowProp(3600) });
      await findDurationInput().vm.$emit('input', 2);

      expect(wrapper.emitted('changed')[0][0]).toEqual(
        getTimeWindowProp(7200), // 2 hours = 7200 seconds
      );
    });

    it('updates time_window.value with minimum limit when duration is too small', async () => {
      createComponent({ timeWindow: getTimeWindowProp(1) });
      await findDurationInput().vm.$emit('input', 1);

      // With TIME_UNITS.MINUTE selected, 1 minute = 60 seconds, which is below MINIMUM_SECONDS (600)
      // So it should be capped at MINIMUM_SECONDS
      expect(wrapper.emitted('changed')[0][0].value).toBe(MINIMUM_SECONDS);
    });

    it('updates time_window.value with maximum limit when duration is too large', async () => {
      createComponent({ timeWindow: getTimeWindowProp(3600) });
      // Set time unit to days first
      await findTimeUnitDropdown().vm.$emit('select', TIME_UNITS.DAY);

      // Then set a very large number of days
      await findDurationInput().vm.$emit('input', 100);

      // 100 days exceeds MAXIMUM_SECONDS, so it should be capped
      expect(wrapper.emitted('changed')[1][0].value).toBe(MAXIMUM_SECONDS);
    });

    it('updates time_window.value with DEFAULT_TIME_PER_UNIT when time unit changes', async () => {
      createComponent({ timeWindow: getTimeWindowProp(3600) });
      await findTimeUnitDropdown().vm.$emit('select', TIME_UNITS.DAY);

      expect(wrapper.emitted('changed')[0][0].value).toBe(DEFAULT_TIME_PER_UNIT[TIME_UNITS.DAY]);
    });

    it.each(['', undefined, null, 'hello'])(
      'does not update time_window.value if it is the invalid value of %s',
      async (input) => {
        createComponent({ timeWindow: getTimeWindowProp(3600) });
        await findDurationInput().vm.$emit('update', input);

        // Should not emit a change event for empty input
        expect(wrapper.emitted('changed')).toBe(undefined);
      },
    );
  });
});
