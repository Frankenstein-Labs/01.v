import { nextTick } from 'vue';
import { GlDisclosureDropdown } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import FlowTriggerConditions from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_conditions.vue';
import FlowTriggerConditionForm from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_condition_form.vue';
import FlowTriggerConditionRow from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_condition_row.vue';

describe('FlowTriggerConditions', () => {
  let wrapper;

  const pipelineFilter = {
    pipeline_hooks: {
      rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
    },
  };

  const createWrapper = ({ props = {}, stubs = {}, attachTo } = {}) => {
    wrapper = shallowMountExtended(FlowTriggerConditions, {
      propsData: { itemTypeLabel: 'flow', ...props },
      provide: { glFeatures: {} },
      stubs: { CrudComponent, ...stubs },
      attachTo,
    });
  };

  const findRows = () => wrapper.findAllComponents(FlowTriggerConditionRow);
  const findForm = () => wrapper.findComponent(FlowTriggerConditionForm);
  const findAddDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findAddItems = () => findAddDropdown().props('items');
  // The dropdown renders items as data, so adding is driven through the item's action.
  const triggerAddEvent = () => {
    findAddItems()
      .find(({ text }) => text === 'On an event')
      .action();
    return nextTick();
  };
  const findEmpty = () => wrapper.findByTestId('crud-empty');
  const findError = () => wrapper.findByTestId('conditions-error');

  const lastEmitted = (event) => {
    const emissions = wrapper.emitted(event);
    return emissions[emissions.length - 1][0];
  };

  describe('when nothing is configured', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the empty state', () => {
      expect(findEmpty().text()).toBe('No conditions yet. Add a schedule or an event.');
    });

    it('reports the list as invalid', () => {
      expect(lastEmitted('update:filter-valid')).toBe(false);
    });

    it('does not show an error until errors are requested', () => {
      expect(findError().exists()).toBe(false);
    });
  });

  describe('when errors are shown and nothing is configured', () => {
    beforeEach(() => {
      createWrapper({ props: { showErrors: true } });
    });

    it('explains that a condition is required', () => {
      expect(findError().text()).toBe('Add a condition so this flow knows when to run.');
    });
  });

  describe('when conditions are configured', () => {
    beforeEach(() => {
      createWrapper({
        props: { eventTypes: ['mention', 'pipeline_hooks'], filter: pipelineFilter },
      });
    });

    it('renders a row per configured condition', () => {
      expect(findRows()).toHaveLength(2);
      expect(findRows().at(0).props('typeValue')).toBe('mention');
      expect(findRows().at(1).props('typeValue')).toBe('pipeline_hooks');
    });

    it('reports the list as valid', () => {
      expect(lastEmitted('update:filter-valid')).toBe(true);
    });
  });

  describe('when a configured event type is missing its configuration', () => {
    beforeEach(() => {
      createWrapper({ props: { eventTypes: ['pipeline_hooks'], showErrors: true } });
    });

    it('reports the list as invalid', () => {
      expect(lastEmitted('update:filter-valid')).toBe(false);
    });

    it('surfaces the error on the row', () => {
      expect(findRows().at(0).props('invalidFeedback')).toBe('Select at least one pipeline event.');
    });
  });

  describe('adding a condition', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('does not render the form until something is being added', () => {
      expect(findForm().exists()).toBe(false);
    });

    // The schedule event type is gated off until the backend lands, so only the event
    // choice is offered for now.
    it('offers a choice per catalyst', () => {
      expect(findAddItems().map(({ text }) => text)).toEqual(['On an event']);
    });

    it('opens an event form', async () => {
      await triggerAddEvent();

      expect(findForm().props()).toMatchObject({ mode: 'event', typeValue: null, isNew: true });
    });

    it('appends the saved condition', async () => {
      await triggerAddEvent();
      await findForm().vm.$emit('save', {
        typeValue: 'pipeline_hooks',
        filter: pipelineFilter,
      });

      expect(lastEmitted('update:event-types')).toEqual(['pipeline_hooks']);
      expect(lastEmitted('update:filter')).toEqual(pipelineFilter);
    });

    it('closes the form on cancel', async () => {
      await triggerAddEvent();
      await findForm().vm.$emit('cancel');

      expect(findForm().exists()).toBe(false);
    });
  });

  describe('while a condition form is open', () => {
    beforeEach(async () => {
      createWrapper({ props: { eventTypes: ['mention'], showErrors: true } });
      await triggerAddEvent();
    });

    it('reports the list as invalid, so the trigger cannot be saved mid-edit', () => {
      expect(lastEmitted('update:filter-valid')).toBe(false);
    });

    it('says what to do about it', () => {
      expect(findError().text()).toBe('Finish or cancel the open condition before saving.');
    });

    it('becomes valid again once the form is closed', async () => {
      await findForm().vm.$emit('cancel');

      expect(lastEmitted('update:filter-valid')).toBe(true);
      expect(findError().exists()).toBe(false);
    });
  });

  describe('event types already in the list', () => {
    beforeEach(async () => {
      createWrapper({ props: { eventTypes: ['mention'] } });
      await triggerAddEvent();
    });

    it('are not selectable again', () => {
      const values = findForm()
        .props('typeOptions')
        .map(({ value }) => value);

      expect(values).not.toContain('mention');
    });
  });

  describe('editing a condition', () => {
    beforeEach(async () => {
      createWrapper({
        props: { eventTypes: ['mention', 'pipeline_hooks'], filter: pipelineFilter },
      });
      await findRows().at(1).vm.$emit('edit');
    });

    it('opens the form with the existing configuration', () => {
      expect(findForm().props()).toMatchObject({
        mode: 'event',
        typeValue: 'pipeline_hooks',
        filter: pipelineFilter,
        isNew: false,
      });
    });

    it('marks only the edited row, so the list shows what the form is working on', () => {
      expect(findRows().at(0).props('isEditing')).toBe(false);
      expect(findRows().at(1).props('isEditing')).toBe(true);
    });

    it('unmarks the row once the form closes', async () => {
      await findForm().vm.$emit('cancel');

      expect(findRows().at(1).props('isEditing')).toBe(false);
    });

    it('keeps the edited event type selectable', () => {
      const values = findForm()
        .props('typeOptions')
        .map(({ value }) => value);

      expect(values).toContain('pipeline_hooks');
    });

    it('replaces the condition in place', async () => {
      await findForm().vm.$emit('save', { typeValue: 'work_item', filter: {} });

      expect(lastEmitted('update:event-types')).toEqual(['mention', 'work_item']);
    });

    it('drops the configuration of the event type it replaced', async () => {
      await findForm().vm.$emit('save', { typeValue: 'work_item', filter: {} });

      expect(lastEmitted('update:filter')).toEqual({});
    });
  });

  // The row that opened the form is disabled straight afterwards, so focus cannot be left
  // behind on it. Needs the real form, whose container carries the tabindex, attached to the
  // document so it can actually take focus.
  describe('focus handling', () => {
    const createAttachedWrapper = () =>
      createWrapper({
        props: { eventTypes: ['mention'] },
        stubs: { FlowTriggerConditionForm },
        attachTo: document.body,
      });

    it('moves focus into the form when a condition is opened for editing', async () => {
      createAttachedWrapper();

      await findRows().at(0).vm.$emit('edit');
      await nextTick();

      expect(findForm().element).toBe(document.activeElement);
    });

    it('moves focus into the form when a condition is added', async () => {
      createAttachedWrapper();

      await triggerAddEvent();
      await nextTick();

      expect(findForm().element).toBe(document.activeElement);
    });
  });

  describe('removing a condition', () => {
    beforeEach(async () => {
      createWrapper({
        props: { eventTypes: ['mention', 'pipeline_hooks'], filter: pipelineFilter },
      });
      await findRows().at(1).vm.$emit('remove');
    });

    it('drops the event type', () => {
      expect(lastEmitted('update:event-types')).toEqual(['mention']);
    });

    it('drops its configuration', () => {
      expect(lastEmitted('update:filter')).toEqual({});
    });
  });

  describe('when the condition being edited is removed', () => {
    beforeEach(async () => {
      createWrapper({ props: { eventTypes: ['mention'] } });
      await findRows().at(0).vm.$emit('edit');
      await findRows().at(0).vm.$emit('remove');
    });

    it('closes the form', () => {
      expect(findForm().exists()).toBe(false);
    });
  });
});
