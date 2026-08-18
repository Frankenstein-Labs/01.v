import { GlCollapsibleListbox, GlDaterangePicker } from '@gitlab/ui';
import timezoneMock from 'timezone-mock';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import DateRangeFilter from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/date_range_filter.vue';
import {
  THIS_MONTH,
  LAST_MONTH,
  LAST_7_DAYS,
  LAST_30_DAYS,
  CUSTOM,
} from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/constants';

const DATE_RANGE_OPTIONS = [THIS_MONTH, LAST_MONTH, LAST_7_DAYS, LAST_30_DAYS, CUSTOM];

describe('DateRangeFilter', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const presetOption = THIS_MONTH;
  const anotherPresetOption = LAST_7_DAYS;
  const customOption = CUSTOM;

  const defaultProps = {
    value: {
      value: presetOption.value,
      startDate: presetOption.startDate,
      endDate: presetOption.endDate,
    },
    options: DATE_RANGE_OPTIONS,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DateRangeFilter, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDaterangePicker = () => wrapper.findComponent(GlDaterangePicker);
  const findHumanTimeframe = () => wrapper.findComponent(HumanTimeframe);

  describe('listbox', () => {
    beforeEach(() => createComponent());

    it('renders with the selected value', () => {
      expect(findListbox().props('selected')).toBe(presetOption.value);
    });

    it('renders all options', () => {
      expect(findListbox().props('items')).toBe(DATE_RANGE_OPTIONS);
    });

    it('renders the toggle text from the selected option', () => {
      expect(findListbox().props('toggleText')).toBe(presetOption.text);
    });
  });

  describe('when a preset option is selected', () => {
    beforeEach(() => createComponent());

    it('emits input with value, startDate, endDate from the option', async () => {
      await findListbox().vm.$emit('select', anotherPresetOption.value);

      expect(wrapper.emitted('input')).toEqual([
        [
          {
            value: anotherPresetOption.value,
            startDate: anotherPresetOption.startDate,
            endDate: anotherPresetOption.endDate,
          },
        ],
      ]);
    });
  });

  describe('preset range display', () => {
    beforeEach(() => createComponent());

    it('shows HumanTimeframe with the current startDate and endDate', () => {
      expect(findHumanTimeframe().props('from')).toBe(presetOption.startDate);
      expect(findHumanTimeframe().props('till')).toBe(presetOption.endDate);
    });

    it('does not show the date range picker', () => {
      expect(findDaterangePicker().exists()).toBe(false);
    });
  });

  describe('when custom option is selected', () => {
    describe('switching to custom', () => {
      beforeEach(() => createComponent());

      it('emits input with custom value and carries over previous dates', async () => {
        await findListbox().vm.$emit('select', CUSTOM.value);

        expect(wrapper.emitted('input')).toEqual([
          [
            {
              value: CUSTOM.value,
              startDate: presetOption.startDate,
              endDate: presetOption.endDate,
            },
          ],
        ]);
      });
    });

    describe('when value is custom', () => {
      beforeEach(() =>
        createComponent({
          value: {
            value: CUSTOM.value,
            startDate: '2026-01-01',
            endDate: '2026-01-31',
          },
        }),
      );

      it('shows the date range picker', () => {
        expect(findDaterangePicker().exists()).toBe(true);
      });

      it('does not show HumanTimeframe', () => {
        expect(findHumanTimeframe().exists()).toBe(false);
      });

      it('passes startDate to the picker', () => {
        expect(findDaterangePicker().props('defaultStartDate')).toEqual(newDate('2026-01-01'));
      });

      it('passes endDate to the picker', () => {
        expect(findDaterangePicker().props('defaultEndDate')).toEqual(newDate('2026-01-31'));
      });

      it('emits input with local ISO dates when custom range is picked', async () => {
        await findDaterangePicker().vm.$emit('input', {
          startDate: newDate('2026-02-01'),
          endDate: newDate('2026-02-28'),
        });

        expect(wrapper.emitted('input')).toEqual([
          [
            {
              value: CUSTOM.value,
              startDate: '2026-02-01',
              endDate: '2026-02-28',
            },
          ],
        ]);
      });
    });

    describe('when value is custom with no dates', () => {
      beforeEach(() =>
        createComponent({
          value: { value: CUSTOM.value, startDate: null, endDate: null },
        }),
      );

      it('shows the date range picker', () => {
        expect(findDaterangePicker().exists()).toBe(true);
      });

      it('passes null as defaultStartDate', () => {
        expect(findDaterangePicker().props('defaultStartDate')).toBeNull();
      });

      it('passes null as defaultEndDate', () => {
        expect(findDaterangePicker().props('defaultEndDate')).toBeNull();
      });
    });
  });

  describe('customDateRangeLimit prop', () => {
    it('passes dateRangeLimit to the picker', () => {
      createComponent({
        value: { value: CUSTOM.value, startDate: null, endDate: null },
        customDateRangeLimit: 30,
      });

      expect(findDaterangePicker().props('maxDateRange')).toBe(30);
    });
  });

  describe('customDateRangeMaxDate prop', () => {
    it('passes maxDate to the picker', () => {
      const maxDate = newDate('2026-04-21');
      createComponent({
        value: { value: CUSTOM.value, startDate: null, endDate: null },
        customDateRangeMaxDate: maxDate,
      });

      expect(findDaterangePicker().props('defaultMaxDate')).toBe(maxDate);
    });
  });

  describe('custom option text', () => {
    it('renders the toggle text for the custom option', () => {
      createComponent({
        value: { value: CUSTOM.value, startDate: null, endDate: null },
      });

      expect(findListbox().props('toggleText')).toBe(customOption.text);
    });
  });

  describe('timezone handling', () => {
    describe.each(['US/Pacific', 'US/Eastern', 'Brazil/East'])(
      '%s timezone (where local date may differ from UTC date)',
      (timezone) => {
        beforeAll(() => {
          timezoneMock.register(timezone);
        });

        afterAll(() => {
          timezoneMock.unregister();
        });

        beforeEach(() =>
          createComponent({
            value: { value: CUSTOM.value, startDate: null, endDate: null },
          }),
        );

        it('emits the local calendar date the user picked, not the UTC date', async () => {
          const localJan31 = newDate('2026-01-31');

          await findDaterangePicker().vm.$emit('input', {
            startDate: localJan31,
            endDate: localJan31,
          });

          expect(wrapper.emitted('input')[0][0].startDate).toBe('2026-01-31');
          expect(wrapper.emitted('input')[0][0].endDate).toBe('2026-01-31');
        });
      },
    );
  });
});
