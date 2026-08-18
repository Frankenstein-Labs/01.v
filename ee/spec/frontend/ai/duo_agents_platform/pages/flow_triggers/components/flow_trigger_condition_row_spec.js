import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FlowTriggerConditionRow from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_condition_row.vue';

describe('FlowTriggerConditionRow', () => {
  let wrapper;

  const pipelineFilter = {
    pipeline_hooks: {
      rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
    },
  };

  const scheduleFilter = {
    schedule: { frequency: 'DAILY', hour: 9, minute: 15, timezone: 'Etc/UTC' },
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(FlowTriggerConditionRow, {
      propsData: { typeValue: 'mention', ...props },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findError = () => wrapper.findByTestId('row-error');
  const findEditingIndicator = () => wrapper.findByTestId('editing-indicator');
  const findEditButton = () => wrapper.findComponentByTestId('edit-condition-button');
  const findRemoveButton = () => wrapper.findComponentByTestId('remove-condition-button');

  describe('when the condition is an event without configuration', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('summarizes the event by name, marked with the event icon', () => {
      expect(wrapper.text()).toContain('Mention');
      expect(findIcon().props('name')).toBe('trigger-source');
    });
  });

  describe('when the condition is a configured event', () => {
    beforeEach(() => {
      createWrapper({ typeValue: 'pipeline_hooks', filter: pipelineFilter });
    });

    it('appends the selected conditions to the summary', () => {
      expect(wrapper.text()).toContain('Pipeline events: Failed');
    });
  });

  describe('when the condition is a schedule', () => {
    beforeEach(() => {
      createWrapper({ typeValue: 'schedule', filter: scheduleFilter });
    });

    it('names the schedule, marked with the schedule icon', () => {
      expect(wrapper.text()).toContain('Schedule');
      expect(findIcon().props('name')).toBe('clock');
    });
  });

  describe('when the condition is not fully configured', () => {
    it('names an event type that exists but cannot be added here', () => {
      createWrapper({ typeValue: 'commit_to_default_branch' });

      expect(wrapper.text()).toContain('Commit to default branch');
    });

    it('falls back for an event type it does not recognize', () => {
      createWrapper({ typeValue: 'not_an_event' });

      expect(wrapper.text()).toContain('Unknown event');
    });
  });

  describe('invalid feedback', () => {
    it('is not rendered by default', () => {
      createWrapper();

      expect(findError().exists()).toBe(false);
    });

    it('is rendered when provided', () => {
      createWrapper({ invalidFeedback: 'Select at least one pipeline event.' });

      expect(findError().text()).toBe('Select at least one pipeline event.');
    });
  });

  describe('actions', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits edit when the edit button is clicked', () => {
      findEditButton().vm.$emit('click');

      expect(wrapper.emitted('edit')).toHaveLength(1);
    });

    // A disabled button never gets the mouseleave that dismisses its tooltip, so the button
    // is rebuilt instead. Destroying the old one unbinds the tooltip along with it.
    it('rebuilds the actions when they become disabled, so no tooltip outlives them', async () => {
      const editButton = findEditButton().element;
      const removeButton = findRemoveButton().element;

      await wrapper.setProps({ isEditing: true });

      expect(findEditButton().element).not.toBe(editButton);
      expect(findRemoveButton().element).not.toBe(removeButton);
    });

    it('emits remove when the remove button is clicked', () => {
      findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });

  describe('when the condition is not being edited', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('is not marked as editing', () => {
      expect(findEditingIndicator().exists()).toBe(false);
      expect(wrapper.find('li').classes()).not.toContain('gl-bg-subtle');
    });

    it('leaves the actions available', () => {
      expect(findEditButton().props('disabled')).toBe(false);
      expect(findRemoveButton().props('disabled')).toBe(false);
    });
  });

  describe('when the condition is being edited', () => {
    beforeEach(() => {
      createWrapper({ isEditing: true });
    });

    it('marks the row as editing', () => {
      expect(findEditingIndicator().text()).toBe('(editing)');
      expect(wrapper.find('li').classes()).toContain('gl-bg-subtle');
    });

    // The open form already owns this condition, so changing it from the list would either
    // fight the form or delete what the user is working on.
    it('disables the actions', () => {
      expect(findEditButton().props('disabled')).toBe(true);
      expect(findRemoveButton().props('disabled')).toBe(true);
    });
  });
});
