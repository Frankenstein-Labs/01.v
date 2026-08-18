import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PipelineEventsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/pipeline_events_configuration.vue';
import { buildPipelineHooksFilter } from 'ee_jest/ai/duo_agents_platform/mock_data';

describe('PipelineEventsConfiguration', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  const filterFor = (value) => buildPipelineHooksFilter({ value });

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(PipelineEventsConfiguration, {
      propsData: { value: {}, ...props },
    });
  };

  describe('rendering', () => {
    it('renders the multi-select listbox with the four pipeline statuses', () => {
      createWrapper();

      expect(findListbox().exists()).toBe(true);
      expect(findListbox().props('multiple')).toBe(true);
      expect(findListbox().props('items')).toEqual([
        { text: 'Running', value: 'running' },
        { text: 'Passed', value: 'success' },
        { text: 'Failed', value: 'failed' },
        { text: 'Canceled', value: 'canceled' },
      ]);
    });

    it('shows placeholder toggle text when no statuses are selected', () => {
      createWrapper();

      expect(findListbox().props('toggleText')).toBe('Select pipeline events');
    });

    it('shows joined status labels as toggle text when statuses are selected', () => {
      createWrapper({ value: filterFor(['failed', 'canceled']) });

      expect(findListbox().props('toggleText')).toBe('Failed, Canceled');
    });

    it('pre-selects existing statuses from the filter prop', () => {
      createWrapper({ value: filterFor(['running']) });

      expect(findListbox().props('selected')).toEqual(['running']);
    });
  });

  describe('selecting statuses', () => {
    it('emits an input event with a filter when statuses are selected', () => {
      createWrapper();

      findListbox().vm.$emit('select', ['failed', 'success']);

      expect(wrapper.emitted('input')).toEqual([[filterFor(['failed', 'success'])]]);
    });

    it('emits a filter without the pipeline_hooks scope when all statuses are deselected', () => {
      createWrapper({ value: filterFor(['failed']) });

      findListbox().vm.$emit('select', []);

      expect(wrapper.emitted('input')).toEqual([[{}]]);
    });

    it('preserves other scopes in the filter when updating pipeline_hooks', () => {
      const otherScope = { other_hooks: { rules: [] } };
      createWrapper({ value: { ...otherScope, ...filterFor(['failed']) } });

      findListbox().vm.$emit('select', ['success']);

      expect(wrapper.emitted('input')).toEqual([[{ ...otherScope, ...filterFor(['success']) }]]);
    });
  });

  describe('invalidFeedback prop', () => {
    it('keeps the form group valid and hides the message when invalidFeedback is null', () => {
      createWrapper();

      expect(findFormGroup().attributes('state')).toBe('true');
      expect(findFormGroup().attributes('invalid-feedback')).toBeUndefined();
      expect(findListbox().props('state')).toBe(true);
    });

    it('marks the form group invalid and shows the message when invalidFeedback is set', () => {
      const message = 'Select at least one pipeline event.';
      createWrapper({ invalidFeedback: message });

      expect(findFormGroup().attributes('state')).toBeUndefined();
      expect(findFormGroup().attributes('invalid-feedback')).toBe(message);
      expect(findListbox().props('state')).toBe(false);
    });
  });
});
