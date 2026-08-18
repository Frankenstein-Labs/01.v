import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PipelineSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/pipeline_source_selector.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import {
  PIPELINE_SOURCE_OPTIONS,
  TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

describe('PipelineSourceSelector', () => {
  let wrapper;

  const createComponent = ({ showAllSources = true, pipelineSources = {} } = {}) => {
    wrapper = shallowMountExtended(PipelineSourceSelector, {
      propsData: {
        showAllSources,
        pipelineSources,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(RuleMultiSelect);

  describe('rendering', () => {
    it('renders the dropdown with all sources by default', () => {
      createComponent();

      const listbox = findListbox();
      expect(listbox.props('items')).toEqual(PIPELINE_SOURCE_OPTIONS);
      expect(listbox.props('value')).toEqual([...Object.keys(PIPELINE_SOURCE_OPTIONS)]);
    });

    it('renders the dropdown with limited sources based on `showAllSources` prop', () => {
      createComponent({ showAllSources: false });

      const listbox = findListbox();
      expect(listbox.props('items')).toEqual(TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS);
      expect(listbox.props('value')).toEqual([
        ...Object.keys(TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS),
      ]);
    });

    it('renders when no sources are selected', () => {
      createComponent({ pipelineSources: { including: null } });
      expect(findListbox().props('value')).toEqual([]);
    });

    it('renders when some sources are selected', () => {
      const selectedSources = ['web', 'api'];
      createComponent({ pipelineSources: { including: selectedSources } });
      expect(findListbox().props('value')).toEqual(selectedSources);
    });
  });

  describe('user interactions', () => {
    it('emits update event with selected sources when user selects a source', () => {
      createComponent();

      const selectedSources = ['web'];
      findListbox().vm.$emit('input', selectedSources);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedSources },
      });
    });

    it('emits update event with multiple selected sources', () => {
      createComponent({ pipelineSources: { including: ['web'] } });

      const selectedSources = ['web', 'api'];
      findListbox().vm.$emit('input', selectedSources);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedSources },
      });
    });

    it('emits update event with empty array when all sources are deselected', () => {
      createComponent({ pipelineSources: { including: ['web', 'api'] } });

      findListbox().vm.$emit('input', []);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: null },
      });
    });

    it('emits remove event with all selected sources when user selects all sources', () => {
      createComponent();
      const allSources = Object.keys(PIPELINE_SOURCE_OPTIONS);

      findListbox().vm.$emit('input', allSources);

      expect(wrapper.emitted('select')).toBe(undefined);
      expect(wrapper.emitted('remove')).toHaveLength(1);
    });

    it('emits update event if all sources are selected for when not all sources are shown', () => {
      createComponent({ showAllSources: false, pipelineSources: { including: ['push'] } });
      const selectedOptions = ['push', 'merge_request_event'];

      findListbox().vm.$emit('input', selectedOptions);

      expect(wrapper.emitted('remove')).toBe(undefined);
      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedOptions },
      });
    });
  });
});
