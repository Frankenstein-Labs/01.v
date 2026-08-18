import { GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScheduleEventsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/schedule_events_configuration.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import {
  FLOW_TRIGGER_TYPE_SCHEDULE,
  SCHEDULE_FREQUENCIES,
  SCHEDULE_FREQUENCY_EVERY_15_MINUTES,
  SCHEDULE_FREQUENCY_EVERY_30_MINUTES,
  SCHEDULE_FREQUENCY_HOURLY,
  SCHEDULE_FREQUENCY_DAILY,
  SCHEDULE_FREQUENCY_WEEKDAYS,
  SCHEDULE_FREQUENCY_WEEKLY,
  SCHEDULE_FREQUENCY_MONTHLY,
} from 'ee/ai/duo_agents_platform/constants';

const SCOPE = FLOW_TRIGGER_TYPE_SCHEDULE.value;
const USER_TIMEZONE = 'America/Chicago';
const TIMEZONE_DATA = [
  { identifier: 'America/Chicago', name: 'Central Time (US & Canada)', offset: -21600 },
  { identifier: 'Etc/UTC', name: 'UTC', offset: 0 },
];

describe('ScheduleEventsConfiguration', () => {
  let wrapper;

  const findFrequencyListbox = () => wrapper.findComponentByTestId('frequency-listbox');
  const findDayOfWeekListbox = () => wrapper.findComponentByTestId('day-of-week-listbox');
  const findDayOfMonthListbox = () => wrapper.findComponentByTestId('day-of-month-listbox');
  const findHourInput = () => wrapper.findComponentByTestId('hour-input');
  const findMinuteListbox = () => wrapper.findComponentByTestId('minute-listbox');
  const findTimezoneDropdown = () => wrapper.findComponent(TimezoneDropdown);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  const filterFor = (schedule) => ({ [SCOPE]: schedule });
  const lastEmittedSchedule = () => {
    const calls = wrapper.emitted('input');
    return calls[calls.length - 1][0][SCOPE];
  };

  const createWrapper = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(ScheduleEventsConfiguration, {
      propsData: { value: {}, ...props },
      provide: { timezoneData: TIMEZONE_DATA, userTimezone: USER_TIMEZONE, ...provide },
    });
  };

  describe('frequency selection', () => {
    it('renders the frequency listbox with the seven presets and a placeholder', () => {
      createWrapper();

      expect(findFrequencyListbox().props('items')).toBe(SCHEDULE_FREQUENCIES);
      expect(findFrequencyListbox().props('toggleText')).toBe('Select frequency');
    });

    it('renders no contextual pickers before a frequency is selected', () => {
      createWrapper();

      expect(findHourInput().exists()).toBe(false);
      expect(findMinuteListbox().exists()).toBe(false);
      expect(findTimezoneDropdown().exists()).toBe(false);
      expect(findDayOfWeekListbox().exists()).toBe(false);
      expect(findDayOfMonthListbox().exists()).toBe(false);
    });

    describe('with randomization stubbed to its lowest values', () => {
      beforeEach(() => {
        jest.spyOn(Math, 'random').mockReturnValue(0);
      });

      it('populates daily defaults and the user timezone on selection', () => {
        createWrapper();

        findFrequencyListbox().vm.$emit('select', SCHEDULE_FREQUENCY_DAILY);

        expect(lastEmittedSchedule()).toEqual({
          frequency: SCHEDULE_FREQUENCY_DAILY,
          minute: 0,
          hour: 0,
          timezone: USER_TIMEZONE,
        });
      });

      it('adds a randomized day-of-week for the weekly preset', () => {
        createWrapper();

        findFrequencyListbox().vm.$emit('select', SCHEDULE_FREQUENCY_WEEKLY);

        expect(lastEmittedSchedule()).toEqual({
          frequency: SCHEDULE_FREQUENCY_WEEKLY,
          minute: 0,
          hour: 0,
          dayOfWeek: 0,
          timezone: USER_TIMEZONE,
        });
      });

      it('adds a randomized day-of-month for the monthly preset', () => {
        createWrapper();

        findFrequencyListbox().vm.$emit('select', SCHEDULE_FREQUENCY_MONTHLY);

        expect(lastEmittedSchedule()).toEqual({
          frequency: SCHEDULE_FREQUENCY_MONTHLY,
          minute: 0,
          hour: 0,
          dayOfMonth: 1,
          timezone: USER_TIMEZONE,
        });
      });

      it('only stores the frequency for sub-hour presets', () => {
        createWrapper();

        findFrequencyListbox().vm.$emit('select', SCHEDULE_FREQUENCY_EVERY_15_MINUTES);

        expect(lastEmittedSchedule()).toEqual({ frequency: SCHEDULE_FREQUENCY_EVERY_15_MINUTES });
      });

      it('preserves other filter scopes when selecting a frequency', () => {
        const otherScope = { pipeline_hooks: { rules: [] } };
        createWrapper({ value: { ...otherScope } });

        findFrequencyListbox().vm.$emit('select', SCHEDULE_FREQUENCY_DAILY);

        expect(wrapper.emitted('input')[0][0].pipeline_hooks).toEqual(otherScope.pipeline_hooks);
      });
    });
  });

  describe('contextual pickers per frequency', () => {
    it.each`
      frequency                              | hour     | minute   | dayOfWeek | dayOfMonth | timezone
      ${SCHEDULE_FREQUENCY_EVERY_15_MINUTES} | ${false} | ${false} | ${false}  | ${false}   | ${false}
      ${SCHEDULE_FREQUENCY_EVERY_30_MINUTES} | ${false} | ${false} | ${false}  | ${false}   | ${false}
      ${SCHEDULE_FREQUENCY_HOURLY}           | ${false} | ${true}  | ${false}  | ${false}   | ${true}
      ${SCHEDULE_FREQUENCY_DAILY}            | ${true}  | ${true}  | ${false}  | ${false}   | ${true}
      ${SCHEDULE_FREQUENCY_WEEKDAYS}         | ${true}  | ${true}  | ${false}  | ${false}   | ${true}
      ${SCHEDULE_FREQUENCY_WEEKLY}           | ${true}  | ${true}  | ${true}   | ${false}   | ${true}
      ${SCHEDULE_FREQUENCY_MONTHLY}          | ${true}  | ${true}  | ${false}  | ${true}    | ${true}
    `(
      'shows the expected pickers for $frequency',
      ({ frequency, hour, minute, dayOfWeek, dayOfMonth, timezone }) => {
        createWrapper({ value: filterFor({ frequency }) });

        expect(findHourInput().exists()).toBe(hour);
        expect(findMinuteListbox().exists()).toBe(minute);
        expect(findDayOfWeekListbox().exists()).toBe(dayOfWeek);
        expect(findDayOfMonthListbox().exists()).toBe(dayOfMonth);
        expect(findTimezoneDropdown().exists()).toBe(timezone);
      },
    );

    it('explains the standalone minute picker when no hour is shown', () => {
      createWrapper({ value: filterFor({ frequency: SCHEDULE_FREQUENCY_HOURLY }) });

      expect(wrapper.text()).toContain('minutes past the hour');
    });

    it('omits the minutes-past-the-hour hint when an hour is shown', () => {
      createWrapper({ value: filterFor({ frequency: SCHEDULE_FREQUENCY_DAILY }) });

      expect(wrapper.text()).not.toContain('minutes past the hour');
    });
  });

  describe('pre-filling existing values', () => {
    beforeEach(() => {
      createWrapper({
        value: filterFor({
          frequency: SCHEDULE_FREQUENCY_MONTHLY,
          minute: 30,
          hour: 14,
          dayOfMonth: 12,
          timezone: 'Etc/UTC',
        }),
      });
    });

    it('selects the stored frequency', () => {
      expect(findFrequencyListbox().props('selected')).toBe(SCHEDULE_FREQUENCY_MONTHLY);
    });

    it('renders the stored hour as a 24-hour value', () => {
      expect(findHourInput().props('value')).toBe(14);
    });

    it('selects the stored minute and zero-pads the toggle text', () => {
      expect(findMinuteListbox().props('selected')).toBe(30);
      expect(findMinuteListbox().props('toggleText')).toBe('30');
    });

    it('labels the minute listbox via a dedicated sr-only label', () => {
      const label = wrapper.find('.gl-sr-only');

      expect(label.text()).toBe('Minute');
      expect(findMinuteListbox().props('toggleAriaLabelledBy')).toBe(label.attributes('id'));
    });

    it('passes the stored timezone and the injected timezone data to the dropdown', () => {
      expect(findTimezoneDropdown().props('value')).toBe('Etc/UTC');
      expect(findTimezoneDropdown().props('timezoneData')).toBe(TIMEZONE_DATA);
    });

    it('selects the stored day-of-month', () => {
      expect(findDayOfMonthListbox().props('selected')).toBe(12);
    });
  });

  describe('editing a configured schedule', () => {
    beforeEach(() => {
      createWrapper({
        value: filterFor({
          frequency: SCHEDULE_FREQUENCY_WEEKLY,
          minute: 0,
          hour: 9,
          dayOfWeek: 1,
          timezone: USER_TIMEZONE,
        }),
      });
    });

    it('stores the entered 24-hour value directly', () => {
      findHourInput().vm.$emit('input', '17');

      expect(lastEmittedSchedule().hour).toBe(17);
    });

    it('clamps an out-of-range hour entry to the 0–23 range', () => {
      findHourInput().vm.$emit('input', '30');

      expect(lastEmittedSchedule().hour).toBe(23);
    });

    it.each(['', 'abc'])(
      'ignores an invalid hour entry (%p), keeping the last valid value',
      (value) => {
        findHourInput().vm.$emit('input', value);

        expect(wrapper.emitted('input')).toBeUndefined();
      },
    );

    it('emits the selected minute', () => {
      findMinuteListbox().vm.$emit('select', 45);

      expect(lastEmittedSchedule().minute).toBe(45);
    });

    it('emits the selected day-of-week', () => {
      findDayOfWeekListbox().vm.$emit('select', 4);

      expect(lastEmittedSchedule().dayOfWeek).toBe(4);
    });

    it('emits the selected day-of-month', () => {
      createWrapper({
        value: filterFor({ frequency: SCHEDULE_FREQUENCY_MONTHLY, dayOfMonth: 12 }),
      });

      findDayOfMonthListbox().vm.$emit('select', 25);

      expect(lastEmittedSchedule().dayOfMonth).toBe(25);
    });

    it('emits the identifier of the selected timezone', () => {
      findTimezoneDropdown().vm.$emit('input', { identifier: 'Etc/UTC', name: 'UTC' });

      expect(lastEmittedSchedule().timezone).toBe('Etc/UTC');
    });
  });

  describe('timezone defaulting', () => {
    const selectDaily = () => findFrequencyListbox().vm.$emit('select', SCHEDULE_FREQUENCY_DAILY);

    it('prefers a selectable profile timezone over the browser timezone', () => {
      jest
        .spyOn(Intl, 'DateTimeFormat')
        .mockReturnValue({ resolvedOptions: () => ({ timeZone: 'Etc/UTC' }) });
      createWrapper({}, { userTimezone: 'America/Chicago' });

      selectDaily();

      expect(lastEmittedSchedule().timezone).toBe('America/Chicago');
    });

    it('falls back to the browser timezone when no profile timezone is set', () => {
      jest
        .spyOn(Intl, 'DateTimeFormat')
        .mockReturnValue({ resolvedOptions: () => ({ timeZone: 'Etc/UTC' }) });
      createWrapper({}, { userTimezone: '' });

      selectDaily();

      expect(lastEmittedSchedule().timezone).toBe('Etc/UTC');
    });

    it('falls back to the browser timezone when the profile timezone is absent from the dropdown data', () => {
      jest
        .spyOn(Intl, 'DateTimeFormat')
        .mockReturnValue({ resolvedOptions: () => ({ timeZone: 'Etc/UTC' }) });
      createWrapper({}, { userTimezone: 'Antarctica/Troll' });

      selectDaily();

      expect(lastEmittedSchedule().timezone).toBe('Etc/UTC');
    });

    it('falls back to UTC when the browser zone is absent from the dropdown data', () => {
      jest
        .spyOn(Intl, 'DateTimeFormat')
        .mockReturnValue({ resolvedOptions: () => ({ timeZone: 'Antarctica/Troll' }) });
      createWrapper({}, { userTimezone: '' });

      selectDaily();

      expect(lastEmittedSchedule().timezone).toBe('Etc/UTC');
    });

    it('leaves the timezone empty when UTC is also absent from the dropdown data', () => {
      jest
        .spyOn(Intl, 'DateTimeFormat')
        .mockReturnValue({ resolvedOptions: () => ({ timeZone: 'Antarctica/Troll' }) });
      createWrapper(
        {},
        {
          userTimezone: '',
          timezoneData: [
            { identifier: 'America/Chicago', name: 'Central Time (US & Canada)', offset: -21600 },
          ],
        },
      );

      selectDaily();

      expect(lastEmittedSchedule().timezone).toBe('');
    });
  });

  describe('invalidFeedback prop', () => {
    it('keeps the frequency group valid when invalidFeedback is null', () => {
      createWrapper();

      expect(findFormGroup().attributes('state')).toBe('true');
      expect(findFormGroup().attributes('invalid-feedback')).toBeUndefined();
    });

    it('marks the frequency group invalid and shows the message when invalidFeedback is set', () => {
      const message = 'Configure the schedule.';
      createWrapper({ invalidFeedback: message });

      expect(findFormGroup().attributes('state')).toBeUndefined();
      expect(findFormGroup().attributes('invalid-feedback')).toBe(message);
    });
  });
});
