import { GlAccordionItem, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SnoozeForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/snooze_form.vue';
import { toISOStringWithoutMilliseconds, newDate } from '~/lib/utils/datetime_utility';

describe('SnoozeForm', () => {
  let wrapper;

  const selectedDate = new Date('2023-01-01T00:00:00Z');

  const createComponent = (data = {}) => {
    wrapper = shallowMountExtended(SnoozeForm, {
      propsData: {
        data,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findDatepicker = () => wrapper.findComponentByTestId('until-input');
  const findReasonInput = () => wrapper.findComponentByTestId('reason-input');

  describe('rendering', () => {
    it('renders the accordion item with correct title', () => {
      createComponent();
      expect(findAccordionItem().props('title')).toBe('Snooze policy');
    });

    it('shows accordion item when until date exists', () => {
      createComponent({ until: selectedDate });
      expect(findAccordionItem().props('visible')).toBe(true);
    });

    it('hides accordion item when until date does not exist', () => {
      createComponent({});
      expect(findAccordionItem().props('visible')).toBe(false);
    });

    it('provides appropriate placeholders for form fields', () => {
      createComponent({ until: selectedDate });
      expect(findDatepicker().props('placeholder')).toBe('Select date');
      expect(findReasonInput().props('placeholder')).toBe('Reason for snoozing policy (optional)');
    });

    it('displays the provided reason in the input field when until date exists', () => {
      const reason = 'Test reason';
      // We need to include the until date to make the accordion visible
      createComponent({ reason, until: selectedDate });
      expect(findReasonInput().props('value')).toBe(reason);
    });

    it('displays the provided date in the datepicker when until date exists', () => {
      createComponent({ until: selectedDate });
      // The component converts the string to a Date object
      expect(findDatepicker().props('value')).toBeInstanceOf(Date);
    });
  });

  describe('events', () => {
    it('emits update event when user enters a reason', () => {
      const initialData = { until: selectedDate };
      createComponent(initialData);

      const newReason = 'New reason';
      findReasonInput().vm.$emit('update', newReason);

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...initialData,
        reason: newReason,
      });
    });

    it('emits update event when user selects a date', () => {
      const initialData = { reason: 'Test reason', until: selectedDate };
      createComponent(initialData);

      const newSelectedDate = new Date('2023-02-01');
      findDatepicker().vm.$emit('input', newSelectedDate);

      const expectedDate = toISOStringWithoutMilliseconds(newDate(newSelectedDate), '00:00');

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...initialData,
        until: expectedDate,
      });
    });

    it('preserves existing data when updating only one field', () => {
      const initialData = { reason: 'Original reason', until: selectedDate };
      createComponent(initialData);

      // Update only the reason
      const newReason = 'Updated reason';
      findReasonInput().vm.$emit('update', newReason);

      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...initialData,
        reason: newReason,
      });
    });
  });
});
