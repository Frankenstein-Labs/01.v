import { GlCollapsibleListbox, GlIcon, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';
import SnoozeForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/snooze_form.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import DurationSelector from 'ee/security_orchestration/components/policy_editor/shared/duration_selector/duration_selector.vue';
import { MAX_SCHEDULE_BRANCHES } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/constants';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  getHostname: jest.fn().mockReturnValue('gitlab.example.com'),
}));

describe('ScheduleForm', () => {
  let wrapper;
  const defaultSchedule = {
    type: 'daily',
    time_window: { distribution: 'random', value: 3600 },
  };
  const mockTimezones = [
    { identifier: 'America/New_York', name: 'Eastern Time' },
    { identifier: 'America/Los_Angeles', name: 'Pacific Time' },
  ];

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(ScheduleForm, {
      propsData: { schedule: defaultSchedule, ...props },
      stubs: { GlSprintf },
      provide: { timezones: mockTimezones, ...provide },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findBranchesInput = () => wrapper.findComponentByTestId('branches-input');
  const findBranchesInfoIcon = () => wrapper.findComponent(GlIcon);
  const findDurationSelector = () => wrapper.findComponent(DurationSelector);
  const findTimezoneDropdown = () => wrapper.findComponent(TimezoneDropdown);
  const findTimeDropdown = () => wrapper.findComponentByTestId('time-dropdown');
  const findWeekdayDropdown = () => wrapper.findComponentByTestId('weekday-dropdown');
  const findMonthlyDaysDropdown = () => wrapper.findComponentByTestId('monthly-days-dropdown');
  const findSnoozeForm = () => wrapper.findComponent(SnoozeForm);

  describe('rendering', () => {
    it('displays the message', () => {
      createComponent();
      expect(wrapper.text()).toContain('Schedule to run for');
    });

    it('displays the details', () => {
      createComponent();
      expect(wrapper.text()).toContain('at the following times:');
    });

    it('renders the cadence selector with correct options', () => {
      createComponent();
      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('items')).toEqual([
        { value: 'daily', text: 'Daily' },
        { value: 'weekly', text: 'Weekly' },
        { value: 'monthly', text: 'Monthly' },
      ]);
      expect(listbox.props('toggleText')).toBe('daily');
    });

    it('renders the cadence selector with when the cadence is invalid', () => {
      createComponent({ schedule: { type: 'invalid' } });
      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('toggleText')).toBe('Select a cadence');
    });

    it('sets the selected value based on schedule prop', () => {
      createComponent({ schedule: { type: 'weekly' } });
      expect(findListbox().props('selected')).toBe('weekly');
    });

    describe('branches input', () => {
      it('renders the branches input', () => {
        createComponent();
        expect(findBranchesInput().exists()).toBe(true);
      });

      it('renders the branches info icon with tooltip', () => {
        createComponent();
        const icon = findBranchesInfoIcon();
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('information-o');
        expect(icon.attributes('title')).toContain(`${MAX_SCHEDULE_BRANCHES}`);
      });

      it('displays existing branches as comma-separated values', () => {
        createComponent({ schedule: { type: 'daily', branches: ['main', 'develop'] } });
        expect(findBranchesInput().attributes('value')).toBe('main, develop');
      });

      it('displays empty string when no branches are set', () => {
        createComponent();
        expect(findBranchesInput().attributes('value')).toBe('');
      });
    });

    describe('timezone dropdown', () => {
      it('renders the timezone dropdown with the default timezone', () => {
        createComponent();
        const timezoneDropdown = findTimezoneDropdown();
        expect(timezoneDropdown.exists()).toBe(true);
        expect(timezoneDropdown.props()).toMatchObject({
          timezoneData: mockTimezones,
          value: 'Etc/UTC',
          headerText: 'Select timezone',
        });
        expect(timezoneDropdown.attributes('title')).toBe('on gitlab.example.com');
      });

      it('renders the timezone if specified in the schedule', () => {
        createComponent({ schedule: { type: 'daily', timezone: 'America/New_York' } });
        expect(findTimezoneDropdown().props('value')).toBe('America/New_York');
      });
    });

    it('renders time dropdown', () => {
      createComponent({ schedule: { type: 'daily', start_time: '09:00' } });
      const timeDropdown = findTimeDropdown();
      expect(timeDropdown.exists()).toBe(true);
      expect(timeDropdown.props('selected')).toBe('09:00');
    });

    describe('weekday dropdown', () => {
      it('renders weekday dropdown for weekly schedule', () => {
        createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        expect(weekdayDropdown.exists()).toBe(true);
        expect(weekdayDropdown.props('selected')).toEqual(['Monday']);
        expect(weekdayDropdown.props('multiple')).toBe(true);
      });

      describe('weekdayToggleText', () => {
        it('returns placeholder when the days property is not available', () => {
          createComponent({ schedule: { type: 'weekly' } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Select a day');
        });

        it('returns placeholder when no days are selected', () => {
          createComponent({ schedule: { type: 'weekly', days: [] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Select a day');
        });

        it('returns single day when one day is selected', () => {
          createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday');
        });

        it('returns two days when two days are selected', () => {
          createComponent({ schedule: { type: 'weekly', days: ['Monday', 'Friday'] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday, Friday');
        });

        it('returns truncated text when more than two days are selected', () => {
          createComponent({
            schedule: { type: 'weekly', days: ['Monday', 'Wednesday', 'Friday'] },
          });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday, Wednesday +1 more');
        });
      });
    });

    describe('monthly dropdown', () => {
      it('renders monthly days when schedule type is monthly', () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1, 15] } });
        const monthlyDropdown = findMonthlyDaysDropdown();
        expect(monthlyDropdown.exists()).toBe(true);
        expect(monthlyDropdown.props('selected')).toEqual([1, 15]);
        expect(monthlyDropdown.props('multiple')).toBe(true);
      });
    });

    describe('SnoozeForm', () => {
      it('passes snooze data to SnoozeForm component', () => {
        const snoozeData = {
          until: '2025-06-01T00:00:00Z',
          reason: 'Maintenance period',
        };
        createComponent({ schedule: { snooze: snoozeData } });
        expect(findSnoozeForm().props('data')).toEqual(snoozeData);
      });
    });
  });

  describe('event handling', () => {
    describe('branches input', () => {
      it('emits changed event with branches array when input changes', async () => {
        createComponent();
        await findBranchesInput().vm.$emit('input', 'main, develop, feature');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ branches: ['main', 'develop', 'feature'] })],
        ]);
      });

      it('limits branches to maximum allowed', async () => {
        createComponent();
        await findBranchesInput().vm.$emit('input', 'a, b, c, d, e, f, g');
        expect(wrapper.emitted('changed')[0][0].branches).toHaveLength(MAX_SCHEDULE_BRANCHES);
      });

      it('removes duplicate branches', async () => {
        createComponent();
        await findBranchesInput().vm.$emit('input', 'main, main, develop');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ branches: ['main', 'develop'] })],
        ]);
      });

      it('filters out wildcard branches', async () => {
        createComponent();
        await findBranchesInput().vm.$emit('input', 'main, *, develop');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ branches: ['main', 'develop'] })],
        ]);
      });
    });

    describe('cadence', () => {
      it('emits changed event with daily schedule when daily is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'daily');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'daily', time_window: { value: 60 } }],
        ]);
      });

      it('emits changed event with weekly schedule when weekly is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'weekly');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'weekly', days: ['Monday'], time_window: { value: 86400 } }],
        ]);
      });

      it('emits changed event with monthly schedule when monthly is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'monthly');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'monthly', days_of_month: [1], time_window: { value: 86400 } }],
        ]);
      });

      it('removes irrelevant properties when changing cadence type', async () => {
        createComponent({
          schedule: {
            type: 'daily',
            start_time: '12:00',
            days: ['Friday'],
            days_of_month: '15',
            time_window: { value: 3600 },
          },
        });

        await findListbox().vm.$emit('select', 'weekly');

        const emittedSchedule = wrapper.emitted('changed')[0][0];
        expect(emittedSchedule).toHaveProperty('days');
        expect(emittedSchedule).toHaveProperty('start_time');
        expect(emittedSchedule).not.toHaveProperty('days_of_month');
      });
    });

    describe('timezone', () => {
      it('handles timezone selection changes', async () => {
        createComponent();
        const timezoneData = { identifier: 'America/Los_Angeles' };
        await findTimezoneDropdown().vm.$emit('input', timezoneData);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ timezone: timezoneData.identifier })],
        ]);
      });
    });

    describe('time dropdown', () => {
      it('emits changed event when time is selected', async () => {
        createComponent();
        const timeDropdown = findTimeDropdown();
        await timeDropdown.vm.$emit('select', '10:00');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ start_time: '10:00' })],
        ]);
      });
    });

    describe('weekday dropdown', () => {
      it('emits changed event when days are selected', async () => {
        createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        await weekdayDropdown.vm.$emit('select', ['Monday', 'Wednesday']);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days: ['Monday', 'Wednesday'] })],
        ]);
      });

      it('emits changed event when days are reset', async () => {
        createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        await weekdayDropdown.vm.$emit('reset');
        expect(wrapper.emitted('changed')).toEqual([[expect.objectContaining({ days: [] })]]);
      });
    });

    describe('monthly dropdown', () => {
      it('emits changed event when days are selected', async () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1] } });
        await findMonthlyDaysDropdown().vm.$emit('select', [1, 15, 2]);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days_of_month: [1, 2, 15] })],
        ]);
      });

      it('emits changed event when days are reset', async () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1] } });
        await findMonthlyDaysDropdown().vm.$emit('reset');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days_of_month: [] })],
        ]);
      });
    });

    describe('duration selector', () => {
      it('renders', () => {
        createComponent();
        expect(findDurationSelector().props()).toMatchObject({
          timeWindow: { distribution: 'random', value: 3600 },
          timeWindowRequired: true,
        });
      });

      it('handles duration selection changes', async () => {
        createComponent();
        await findDurationSelector().vm.$emit('changed', { distribution: 'random', value: 7200 });
        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              time_window: { distribution: 'random', value: 7200 },
              type: 'daily',
            },
          ],
        ]);
      });
    });

    describe('snooze form', () => {
      it('handles update events', () => {
        createComponent();

        const snoozeData = {
          until: '2025-06-01T00:00:00Z',
          reason: 'Maintenance period',
        };

        findSnoozeForm().vm.$emit('update', snoozeData);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toEqual({
          ...defaultSchedule,
          snooze: snoozeData,
        });
      });
    });
  });

  describe('time_window error', () => {
    it('passes hasError false to DurationSelector when errorSources is empty', () => {
      createComponent({ errorSources: [] });
      expect(findDurationSelector().props('hasError')).toBe(false);
    });

    it('passes hasError true to DurationSelector when errorSources contains a time_window error', () => {
      createComponent({ errorSources: [['schedules', '0', 'time_window']] });
      expect(findDurationSelector().props('hasError')).toBe(true);
    });

    it('passes hasError false to DurationSelector when errorSources contains a different location', () => {
      createComponent({ errorSources: [['schedules', '0', 'type']] });
      expect(findDurationSelector().props('hasError')).toBe(false);
    });
  });
});
