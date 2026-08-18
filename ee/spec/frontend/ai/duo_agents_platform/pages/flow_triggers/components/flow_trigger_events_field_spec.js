import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FlowTriggerEventsField from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_events_field.vue';
import PipelineEventsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/pipeline_events_configuration.vue';
import EventActionsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/event_actions_configuration.vue';
import {
  FLOW_TRIGGER_TYPE_MENTION,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST,
  FLOW_TRIGGER_TYPE_SCHEDULE,
  FLOW_TRIGGER_TYPE_WORK_ITEM,
} from 'ee/ai/duo_agents_platform/constants';

// Every flow trigger type visible today; the schedule type is gated off
// (`isAvailable: () => false`) and so is intentionally excluded.
const availableTypeValues = [
  'mention',
  'assign',
  'assign_reviewer',
  'pipeline_hooks',
  'merge_request',
  'work_item',
];

describe('FlowTriggerEventsField', () => {
  let wrapper;

  const pipelineFilter = {
    [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value]: {
      rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
    },
  };

  const createWrapper = ({ props = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(FlowTriggerEventsField, {
      propsData: { itemTypeLabel: 'flow', ...props },
      provide: {
        glFeatures: {
          ...glFeatures,
        },
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findPipelineConfig = () => wrapper.findComponent(PipelineEventsConfiguration);
  const findActionsConfig = () => wrapper.findComponent(EventActionsConfiguration);

  describe('listbox options', () => {
    it('lists every available flow trigger type when feature flags are enabled', () => {
      createWrapper();

      const items = findListbox().props('items');
      expect(items.map((option) => option.value)).toEqual(availableTypeValues);
    });

    it('does not list the schedule type while it is gated off', () => {
      createWrapper();

      const values = findListbox()
        .props('items')
        .map((option) => option.value);
      expect(values).not.toContain(FLOW_TRIGGER_TYPE_SCHEDULE.value);
    });

    it('substitutes the itemTypeLabel prop into the option descriptions', () => {
      createWrapper({ props: { itemTypeLabel: 'agent or flow' } });

      const mentionOption = findListbox()
        .props('items')
        .find((option) => option.value === FLOW_TRIGGER_TYPE_MENTION.value);

      expect(mentionOption.description).toBe(
        'Trigger agent or flow when service account user is mentioned in an issue or merge request.',
      );
    });

    describe('merge request description with feature flag', () => {
      it('includes "merged" in the description when mergeRequestMergedFlowTrigger is enabled', () => {
        createWrapper({
          props: { itemTypeLabel: 'flow' },
          glFeatures: { mergeRequestMergedFlowTrigger: true },
        });

        const mrOption = findListbox()
          .props('items')
          .find((option) => option.value === FLOW_TRIGGER_TYPE_MERGE_REQUEST.value);

        expect(mrOption.description).toBe(
          'Trigger flow when a merge request is ready, approved, merged, or has conflicts.',
        );
      });

      it('omits "merged" from the description when mergeRequestMergedFlowTrigger is disabled', () => {
        createWrapper({
          props: { itemTypeLabel: 'flow' },
          glFeatures: { mergeRequestMergedFlowTrigger: false },
        });

        const mrOption = findListbox()
          .props('items')
          .find((option) => option.value === FLOW_TRIGGER_TYPE_MERGE_REQUEST.value);

        expect(mrOption.description).toBe(
          'Trigger flow when a merge request is ready, approved, or has conflicts.',
        );
      });
    });
  });

  describe('toggle text', () => {
    it('shows the placeholder when nothing is selected', () => {
      createWrapper();

      expect(findListbox().props('toggleText')).toBe('Select one or multiple event types');
    });

    it('joins selected option labels with commas', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_MENTION.value, FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value],
        },
      });

      expect(findListbox().props('toggleText')).toBe(
        `${FLOW_TRIGGER_TYPE_MENTION.text}, ${FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.text}`,
      );
    });
  });

  describe('selection changes', () => {
    it('emits update:event-types with the new selection', async () => {
      createWrapper();

      const newSelection = [FLOW_TRIGGER_TYPE_MENTION.value];
      await findListbox().vm.$emit('select', newSelection);

      expect(wrapper.emitted('update:event-types')).toEqual([[newSelection]]);
    });

    it('re-emits blur when the listbox blurs', async () => {
      createWrapper();

      await findListbox().vm.$emit('blur');

      expect(wrapper.emitted('blur')).toHaveLength(1);
    });

    it('prunes filter scopes for deselected configurable event types', async () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value],
          filter: pipelineFilter,
        },
      });

      await findListbox().vm.$emit('select', [FLOW_TRIGGER_TYPE_MENTION.value]);

      expect(wrapper.emitted('update:filter')).toEqual([[{}]]);
    });

    it('does not re-emit filter when no configurable scope was removed', async () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_MENTION.value],
          filter: {},
        },
      });

      await findListbox().vm.$emit('select', [
        FLOW_TRIGGER_TYPE_MENTION.value,
        FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value,
      ]);

      expect(wrapper.emitted('update:filter')).toBeUndefined();
    });
  });

  describe('pipeline events configuration', () => {
    it('does not render the configuration when pipeline_hooks is unselected', () => {
      createWrapper();

      expect(findPipelineConfig().exists()).toBe(false);
    });

    it('renders the configuration and forwards the filter when pipeline_hooks is selected', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value],
          filter: pipelineFilter,
        },
      });

      expect(findPipelineConfig().exists()).toBe(true);
      expect(findPipelineConfig().props('value')).toEqual(pipelineFilter);
    });

    it('emits update:filter when the configuration emits input', async () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value], filter: {} },
      });

      await findPipelineConfig().vm.$emit('input', pipelineFilter);

      expect(wrapper.emitted('update:filter')).toEqual([[pipelineFilter]]);
    });
  });

  describe('validity reporting', () => {
    it('emits update:filter-valid with true when no configurable event types are selected', () => {
      createWrapper({ props: { eventTypes: [FLOW_TRIGGER_TYPE_MENTION.value] } });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[true]]);
    });

    it('emits update:filter-valid with true when pipeline filter is valid', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value],
          filter: pipelineFilter,
        },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[true]]);
    });

    it('emits update:filter-valid with false when pipeline filter is empty', () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value], filter: {} },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[false]]);
    });

    it('re-emits update:filter-valid when filter transitions to valid', async () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value], filter: {} },
      });

      await wrapper.setProps({ filter: pipelineFilter });

      expect(wrapper.emitted('update:filter-valid').map(([v]) => v)).toEqual([false, true]);
    });
  });

  describe('invalid feedback display', () => {
    it('hides invalid feedback when showErrors is false', () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value], filter: {} },
      });

      expect(findPipelineConfig().props('invalidFeedback')).toBeNull();
    });

    it('shows invalid feedback when showErrors is true and pipeline filter is empty', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value],
          filter: {},
          showErrors: true,
        },
      });

      expect(findPipelineConfig().props('invalidFeedback')).toBe(
        'Select at least one pipeline event.',
      );
    });

    it('keeps feedback null when showErrors is true but the filter is valid', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value],
          filter: pipelineFilter,
          showErrors: true,
        },
      });

      expect(findPipelineConfig().props('invalidFeedback')).toBeNull();
    });
  });

  describe('merge request events configuration', () => {
    const mergeRequestFilter = {
      [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value]: {
        rules: [{ field: 'action', operator: 'in', value: ['approved'] }],
      },
    };

    it('does not render the configuration when merge_request is unselected', () => {
      createWrapper();

      expect(findActionsConfig().exists()).toBe(false);
    });

    it('renders the configuration scoped to merge_request and forwards the filter', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value],
          filter: mergeRequestFilter,
        },
      });

      expect(findActionsConfig().exists()).toBe(true);
      expect(findActionsConfig().props('scope')).toBe(FLOW_TRIGGER_TYPE_MERGE_REQUEST.value);
      expect(findActionsConfig().props('value')).toEqual(mergeRequestFilter);
    });

    it('emits update:filter when the configuration emits input', async () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value], filter: {} },
      });

      await findActionsConfig().vm.$emit('input', mergeRequestFilter);

      expect(wrapper.emitted('update:filter')).toEqual([[mergeRequestFilter]]);
    });

    it('emits update:filter-valid with false when the merge_request filter is empty', () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value], filter: {} },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[false]]);
    });

    it('emits update:filter-valid with true when the merge_request filter has an action', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value],
          filter: mergeRequestFilter,
        },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[true]]);
    });

    it('shows invalid feedback when showErrors is true and the filter is empty', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value],
          filter: {},
          showErrors: true,
        },
      });

      expect(findActionsConfig().props('invalidFeedback')).toBe(
        'Select at least one merge request action.',
      );
    });
  });

  describe('work item events configuration', () => {
    const workItemFilter = {
      [FLOW_TRIGGER_TYPE_WORK_ITEM.value]: {
        rules: [{ field: 'action', operator: 'in', value: ['created'] }],
      },
    };

    it('does not render the configuration when work_item is unselected', () => {
      createWrapper();

      expect(findActionsConfig().exists()).toBe(false);
    });

    it('renders the configuration scoped to work_item and forwards the filter', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_WORK_ITEM.value],
          filter: workItemFilter,
        },
      });

      expect(findActionsConfig().exists()).toBe(true);
      expect(findActionsConfig().props('scope')).toBe(FLOW_TRIGGER_TYPE_WORK_ITEM.value);
      expect(findActionsConfig().props('value')).toEqual(workItemFilter);
    });

    it('emits update:filter when the configuration emits input', async () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_WORK_ITEM.value], filter: {} },
      });

      await findActionsConfig().vm.$emit('input', workItemFilter);

      expect(wrapper.emitted('update:filter')).toEqual([[workItemFilter]]);
    });

    it('emits update:filter-valid with false when the work_item filter is empty', () => {
      createWrapper({
        props: { eventTypes: [FLOW_TRIGGER_TYPE_WORK_ITEM.value], filter: {} },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[false]]);
    });

    it('emits update:filter-valid with true when the work_item filter has an action', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_WORK_ITEM.value],
          filter: workItemFilter,
        },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[true]]);
    });

    it('emits update:filter-valid with true when the work_item filter has a status_changed action', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_WORK_ITEM.value],
          filter: {
            [FLOW_TRIGGER_TYPE_WORK_ITEM.value]: {
              rules: [{ field: 'action', operator: 'in', value: ['status_changed'] }],
            },
          },
        },
      });

      expect(wrapper.emitted('update:filter-valid')).toEqual([[true]]);
    });

    it('shows invalid feedback when showErrors is true and the filter is empty', () => {
      createWrapper({
        props: {
          eventTypes: [FLOW_TRIGGER_TYPE_WORK_ITEM.value],
          filter: {},
          showErrors: true,
        },
      });

      expect(findActionsConfig().props('invalidFeedback')).toBe(
        'Select at least one work item action.',
      );
    });
  });
});
