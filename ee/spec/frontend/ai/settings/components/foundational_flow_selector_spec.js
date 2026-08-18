import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import FoundationalFlowSelector from 'ee/ai/settings/components/foundational_flow_selector.vue';

describe('FoundationalFlowSelector', () => {
  let wrapper;

  const mockFlows = [
    {
      reference: 'code_review/v1',
      name: 'Code Review Flow',
      description: 'Automated code review assistant',
    },
    {
      reference: 'bug_triage/v1',
      name: 'Bug Triage Flow',
      description: 'Automatically triages and categorizes bugs',
    },
    {
      reference: 'documentation/v1',
      name: 'Documentation Flow',
      description: 'Generates documentation from code',
    },
  ];

  const createWrapper = (props = {}, provide = {}) => {
    return shallowMount(FoundationalFlowSelector, {
      propsData: {
        value: [],
        ...props,
      },
      provide: {
        availableFoundationalFlows: mockFlows,
        ...provide,
      },
      stubs: {
        GlFormCheckbox,
      },
    });
  };

  const findAllCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findCheckboxAt = (index) => findAllCheckboxes().at(index);

  describe('component rendering', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders a checkbox for each available flow', () => {
      expect(findAllCheckboxes()).toHaveLength(3);
    });

    it('renders flow names correctly', () => {
      expect(findCheckboxAt(0).text()).toContain('Code Review Flow');
      expect(findCheckboxAt(1).text()).toContain('Bug Triage Flow');
      expect(findCheckboxAt(2).text()).toContain('Documentation Flow');
    });

    it('renders flow descriptions correctly', () => {
      expect(findCheckboxAt(0).text()).toContain('Automated code review assistant');
      expect(findCheckboxAt(1).text()).toContain('Automatically triages and categorizes bugs');
      expect(findCheckboxAt(2).text()).toContain('Generates documentation from code');
    });

    it('renders descriptionHtml when provided', () => {
      const flowsWithHtml = [
        {
          reference: 'code_review/v1',
          name: 'Code Review Flow',
          description: 'Automated code review assistant',
          descriptionHtml:
            '<p>Automated code review assistant. <a href="https://example.com">Learn more</a>.</p>',
        },
      ];

      wrapper = createWrapper({}, { availableFoundationalFlows: flowsWithHtml });

      expect(findCheckboxAt(0).html()).toContain('<a href="https://example.com">Learn more</a>');
    });

    it('applies correct CSS classes to the container', () => {
      expect(wrapper.classes()).toContain('gl-ml-6');
      expect(wrapper.classes()).toContain('gl-mt-3');
    });

    it('sets correct data-testid on checkboxes', () => {
      const checkboxes = wrapper.findAll('[data-testid="foundational-flow-checkbox"]');
      expect(checkboxes).toHaveLength(3);
    });
  });

  describe('when no flows are available', () => {
    beforeEach(() => {
      wrapper = createWrapper({}, { availableFoundationalFlows: [] });
    });

    it('renders no checkboxes', () => {
      expect(findAllCheckboxes()).toHaveLength(0);
    });
  });

  describe('checkbox selection state', () => {
    it('shows no checkboxes as checked when value is empty', () => {
      wrapper = createWrapper({ value: [] });

      findAllCheckboxes().wrappers.forEach((checkbox) => {
        expect(checkbox.props('checked')).toBe(false);
      });
    });

    it('shows selected flows as checked', () => {
      wrapper = createWrapper({ value: ['code_review/v1', 'documentation/v1'] });

      expect(findCheckboxAt(0).props('checked')).toBe(true);
      expect(findCheckboxAt(1).props('checked')).toBe(false);
      expect(findCheckboxAt(2).props('checked')).toBe(true);
    });

    it('shows all checkboxes as checked when all flows are selected', () => {
      wrapper = createWrapper({ value: ['code_review/v1', 'bug_triage/v1', 'documentation/v1'] });

      findAllCheckboxes().wrappers.forEach((checkbox) => {
        expect(checkbox.props('checked')).toBe(true);
      });
    });
  });

  describe('disabled state', () => {
    describe('when disabled is false', () => {
      beforeEach(() => {
        wrapper = createWrapper({ disabled: false });
      });

      it('enables all checkboxes', () => {
        findAllCheckboxes().wrappers.forEach((checkbox) => {
          expect(checkbox.props('disabled')).toBe(false);
        });
      });
    });

    describe('when disabled is true', () => {
      beforeEach(() => {
        wrapper = createWrapper({ disabled: true });
      });

      it('disables all checkboxes', () => {
        findAllCheckboxes().wrappers.forEach((checkbox) => {
          expect(checkbox.props('disabled')).toBe(true);
        });
      });
    });
  });

  describe('checkbox interactions', () => {
    beforeEach(() => {
      wrapper = createWrapper({ value: [] });
    });

    it('emits input event with added flow id when checkbox is checked', async () => {
      await findCheckboxAt(0).vm.$emit('input', true);

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1']]);
    });

    it('emits input event with multiple flow ids when multiple checkboxes are checked', async () => {
      await findCheckboxAt(0).vm.$emit('input', true);

      wrapper = createWrapper({ value: ['code_review/v1'] });

      await findCheckboxAt(2).vm.$emit('input', true);

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1', 'documentation/v1']]);
    });

    it('emits input event with removed flow id when checkbox is unchecked', async () => {
      wrapper = createWrapper({ value: ['code_review/v1', 'bug_triage/v1', 'documentation/v1'] });

      await findCheckboxAt(1).vm.$emit('input', false);

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1', 'documentation/v1']]);
    });

    it('preserves existing selections when adding new flow', async () => {
      wrapper = createWrapper({ value: ['code_review/v1'] });

      await findCheckboxAt(1).vm.$emit('input', true);

      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1', 'bug_triage/v1']]);
    });

    it('preserves existing selections when removing a flow', async () => {
      wrapper = createWrapper({ value: ['code_review/v1', 'bug_triage/v1', 'documentation/v1'] });

      await findCheckboxAt(1).vm.$emit('input', false);

      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1', 'documentation/v1']]);
    });
  });

  describe('isFlowSelected method', () => {
    it('returns true for selected flow ids', () => {
      wrapper = createWrapper({ value: ['code_review/v1', 'documentation/v1'] });

      expect(wrapper.vm.isFlowSelected('code_review/v1')).toBe(true);
      expect(wrapper.vm.isFlowSelected('documentation/v1')).toBe(true);
    });

    it('returns false for unselected flow ids', () => {
      wrapper = createWrapper({ value: ['code_review/v1', 'documentation/v1'] });

      expect(wrapper.vm.isFlowSelected('bug_triage/v1')).toBe(false);
    });

    it('returns false when value is empty', () => {
      wrapper = createWrapper({ value: [] });

      expect(wrapper.vm.isFlowSelected('code_review/v1')).toBe(false);
      expect(wrapper.vm.isFlowSelected('bug_triage/v1')).toBe(false);
    });
  });

  describe('toggleFlow method', () => {
    beforeEach(() => {
      wrapper = createWrapper({ value: ['code_review/v1'] });
    });

    it('adds flow id when checked is true', () => {
      wrapper.vm.toggleFlow('bug_triage/v1', true);

      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1', 'bug_triage/v1']]);
    });

    it('removes flow id when checked is false', () => {
      wrapper.vm.toggleFlow('code_review/v1', false);

      expect(wrapper.emitted('input')[0]).toEqual([[]]);
    });

    it('adds flow id even if already in the array', () => {
      wrapper.vm.toggleFlow('code_review/v1', true);

      // The component doesn't prevent duplicates
      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1', 'code_review/v1']]);
    });

    it('handles removing non-existent flow id gracefully', () => {
      wrapper.vm.toggleFlow('non_existent/v1', false);

      expect(wrapper.emitted('input')[0]).toEqual([['code_review/v1']]);
    });
  });

  describe('edge cases', () => {
    it('handles flow with missing description', () => {
      const flowsWithoutDescription = [
        {
          reference: 'flow_without_desc/v1',
          name: 'Flow Without Description',
          description: undefined,
        },
      ];

      wrapper = createWrapper({}, { availableFoundationalFlows: flowsWithoutDescription });

      expect(findCheckboxAt(0).text()).toContain('Flow Without Description');
    });

    it('handles flow with empty description', () => {
      const flowsWithEmptyDescription = [
        {
          reference: 'flow_with_empty_desc/v1',
          name: 'Flow With Empty Description',
          description: '',
        },
      ];

      wrapper = createWrapper({}, { availableFoundationalFlows: flowsWithEmptyDescription });

      expect(wrapper.exists()).toBe(true);
    });

    it('handles rapid checkbox toggling', async () => {
      wrapper = createWrapper({ value: [] });

      await findCheckboxAt(0).vm.$emit('input', true);
      await findCheckboxAt(0).vm.$emit('input', false);
      await findCheckboxAt(0).vm.$emit('input', true);

      expect(wrapper.emitted('input')).toHaveLength(3);
      expect(wrapper.emitted('input')[2]).toEqual([['code_review/v1']]);
    });
  });
});
