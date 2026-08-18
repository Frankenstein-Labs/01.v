import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FlowTriggerConditionForm from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_condition_form.vue';
import PipelineEventsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/pipeline_events_configuration.vue';
import ScheduleEventsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/schedule_events_configuration.vue';

describe('FlowTriggerConditionForm', () => {
  let wrapper;

  const typeOptions = [
    { value: 'mention', text: 'Mention', description: 'Trigger flow when mentioned.' },
    { value: 'pipeline_hooks', text: 'Pipeline events' },
  ];

  const pipelineFilter = {
    pipeline_hooks: {
      rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
    },
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(FlowTriggerConditionForm, {
      propsData: { mode: 'event', typeOptions, ...props },
    });
  };

  const findGroup = () => wrapper.findByTestId('condition-form');
  const findHeading = () => wrapper.find('h3');
  const findTypeListbox = () => wrapper.findComponentByTestId('event-type-listbox');
  const findScheduleConfiguration = () => wrapper.findComponent(ScheduleEventsConfiguration);
  const findPipelineConfiguration = () => wrapper.findComponent(PipelineEventsConfiguration);
  const findError = () => wrapper.findByTestId('condition-error');
  const findSaveButton = () => wrapper.findComponentByTestId('save-condition');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-condition');

  describe('event mode', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('offers the selectable event types', () => {
      expect(findTypeListbox().props('items')).toEqual(typeOptions);
    });

    it('does not render a configuration until an event type is selected', () => {
      expect(wrapper.findComponent(GlCollapsibleListbox).exists()).toBe(true);
      expect(findPipelineConfiguration().exists()).toBe(false);
    });

    it('renders the configuration for the selected event type', async () => {
      await findTypeListbox().vm.$emit('select', 'pipeline_hooks');

      expect(findPipelineConfiguration().exists()).toBe(true);
    });

    it('saves an event type that needs no configuration', async () => {
      await findTypeListbox().vm.$emit('select', 'mention');
      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')[0][0]).toEqual({ typeValue: 'mention', filter: {} });
    });

    it('saves the configuration collected for the selected event type', async () => {
      await findTypeListbox().vm.$emit('select', 'pipeline_hooks');
      await findPipelineConfiguration().vm.$emit('input', pipelineFilter);
      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')[0][0]).toEqual({
        typeValue: 'pipeline_hooks',
        filter: pipelineFilter,
      });
    });

    it('clears the configuration when the event type changes', async () => {
      await findTypeListbox().vm.$emit('select', 'pipeline_hooks');
      await findPipelineConfiguration().vm.$emit('input', pipelineFilter);
      await findTypeListbox().vm.$emit('select', 'mention');
      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')[0][0]).toEqual({ typeValue: 'mention', filter: {} });
    });

    it('emits cancel when the cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('when no event type is selected', () => {
    beforeEach(async () => {
      createWrapper();
      await findSaveButton().vm.$emit('click');
    });

    it('does not save', () => {
      expect(wrapper.emitted('save')).toBeUndefined();
    });

    it('shows an error', () => {
      expect(findError().text()).toBe('Select an event.');
    });
  });

  describe('when the selected event type is not configured', () => {
    beforeEach(async () => {
      createWrapper({ typeValue: 'pipeline_hooks' });
      await findSaveButton().vm.$emit('click');
    });

    it('does not save', () => {
      expect(wrapper.emitted('save')).toBeUndefined();
    });

    it('reports the error on the field that owns it, not as loose text', () => {
      expect(findPipelineConfiguration().props('invalidFeedback')).toBe(
        'Select at least one pipeline event.',
      );
      expect(findError().exists()).toBe(false);
    });
  });

  describe('schedule mode', () => {
    beforeEach(() => {
      createWrapper({ mode: 'schedule', typeValue: 'schedule' });
    });

    it('skips the event picker', () => {
      expect(findTypeListbox().exists()).toBe(false);
    });

    it('renders the schedule configuration', () => {
      expect(findScheduleConfiguration().exists()).toBe(true);
    });

    it('saves a complete schedule', async () => {
      const filter = {
        schedule: { frequency: 'DAILY', hour: 9, minute: 15, timezone: 'Etc/UTC' },
      };

      await findScheduleConfiguration().vm.$emit('input', filter);
      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')[0][0]).toEqual({ typeValue: 'schedule', filter });
    });

    it('does not save an incomplete schedule', async () => {
      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')).toBeUndefined();
      expect(findScheduleConfiguration().props('invalidFeedback')).toBe('Configure the schedule.');
    });
  });

  describe('heading', () => {
    it.each`
      mode          | isNew    | heading
      ${'event'}    | ${true}  | ${'New event'}
      ${'schedule'} | ${false} | ${'Edit schedule'}
    `('reads "$heading" for a $mode with isNew $isNew', ({ mode, isNew, heading }) => {
      createWrapper({ mode, isNew });

      expect(findHeading().text()).toBe(heading);
    });

    it('is in the document but not drawn, so it does not repeat the copy on screen', () => {
      createWrapper();

      expect(findHeading().classes()).toContain('gl-sr-only');
    });

    it('names the group', () => {
      createWrapper();

      expect(findGroup().attributes('aria-labelledby')).toBe(findHeading().attributes('id'));
    });
  });

  describe('submit button', () => {
    it.each`
      mode          | isNew    | label
      ${'event'}    | ${true}  | ${'Add event'}
      ${'schedule'} | ${true}  | ${'Add schedule'}
      ${'event'}    | ${false} | ${'Save'}
    `('is labelled "$label" for a $mode with isNew $isNew', ({ mode, isNew, label }) => {
      createWrapper({ mode, isNew });

      expect(findSaveButton().text()).toBe(label);
    });
  });
});
