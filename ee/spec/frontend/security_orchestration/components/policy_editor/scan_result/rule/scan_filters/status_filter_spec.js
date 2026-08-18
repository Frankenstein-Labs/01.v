import { GlCollapsibleListbox, GlPopover, GlSprintf } from '@gitlab/ui';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  APPROVAL_VULNERABILITY_STATES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('StatusFilter', () => {
  let wrapper;

  const testStateNew1 = 'new_needs_triage';
  const testStateNew2 = 'new_detected';
  const testStatePreviouslyDetected = 'detected';

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(StatusFilter, {
      propsData: {
        ...props,
      },
      stubs: {
        SectionLayout,
        GlCollapsibleListbox,
        RuleMultiSelect,
        GlSprintf,
      },
    });
  };

  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findPolicyRuleMultiSelect = () => wrapper.findComponent(RuleMultiSelect);
  const findAllSelectedItem = () => wrapper.findComponentByTestId('listbox-select-all-button');
  const findTooltipIcon = () => wrapper.findByTestId('previously-existing-tooltip');
  const findPopover = () => wrapper.findComponent(GlPopover);

  const expectPopoverExists = (exists) => {
    expect(findTooltipIcon().exists()).toBe(exists);
    expect(findPopover().exists()).toBe(exists);
  };

  it('renders both dropdowns', () => {
    createComponent();

    expect(findListBox().exists()).toBe(true);
    expect(findPolicyRuleMultiSelect().exists()).toBe(true);
  });

  describe('new filters', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders initial items for the provided filter', () => {
      expect(Object.keys(findPolicyRuleMultiSelect().props('items'))).toEqual(
        Object.keys(APPROVAL_VULNERABILITY_STATES[NEWLY_DETECTED]),
      );
    });

    it('should select states', () => {
      findPolicyRuleMultiSelect().vm.$emit('input', [testStateNew1]);
      findPolicyRuleMultiSelect().vm.$emit('input', [testStateNew2]);

      expect(wrapper.emitted('input')).toEqual([[[testStateNew1]], [[testStateNew2]]]);
    });

    it('should select different filter and emit input event', async () => {
      await findListBox().vm.$emit('select', PREVIOUSLY_EXISTING);

      expect(wrapper.emitted('change-group')).toEqual([[PREVIOUSLY_EXISTING]]);
    });

    it('should select all statuses', () => {
      findAllSelectedItem().vm.$emit('click');

      expect(wrapper.emitted('input')).toEqual([[['new_needs_triage', 'new_dismissed']]]);
    });

    it('disregard previously selected values when changing filter', async () => {
      await findPolicyRuleMultiSelect().vm.$emit('input', [testStateNew1]);
      await findListBox().vm.$emit('select', PREVIOUSLY_EXISTING);
      await findPolicyRuleMultiSelect().vm.$emit('input', [testStatePreviouslyDetected]);

      expect(wrapper.emitted('change-group')).toEqual([[PREVIOUSLY_EXISTING]]);
      expect(wrapper.emitted('input')).toEqual([
        [[testStateNew1]],
        [[testStatePreviouslyDetected]],
      ]);
    });
  });

  describe('when selected prop changes', () => {
    it('updates the vulnerability states dropdown', async () => {
      createComponent({ selected: [testStateNew1], filter: NEWLY_DETECTED });

      expect(findPolicyRuleMultiSelect().props('value')).toEqual([testStateNew1]);

      await wrapper.setProps({ selected: [testStateNew1, 'new_dismissed'] });

      expect(findPolicyRuleMultiSelect().props('value')).toEqual([testStateNew1, 'new_dismissed']);
    });

    it('syncs filters when selected prop is updated with new values', async () => {
      createComponent({ selected: [testStateNew1], filter: NEWLY_DETECTED });

      expect(findPolicyRuleMultiSelect().props('value')).toEqual([testStateNew1]);

      await wrapper.setProps({ selected: ['new_needs_triage', 'new_dismissed'] });

      expect(findPolicyRuleMultiSelect().props('value')).toEqual([
        'new_needs_triage',
        'new_dismissed',
      ]);
    });
  });

  describe('existing filters', () => {
    it('should transform "newly_detected" state to "new_dismissed" and "new_needs_triage"', () => {
      createComponent({ selected: [NEWLY_DETECTED] });

      expect(findListBox().props('selected')).toEqual(NEWLY_DETECTED);
      expect(findPolicyRuleMultiSelect().props('value')).toEqual([
        'new_needs_triage',
        'new_dismissed',
      ]);
    });

    it.each`
      filter                 | selected
      ${NEWLY_DETECTED}      | ${[testStateNew1]}
      ${PREVIOUSLY_EXISTING} | ${[testStatePreviouslyDetected]}
    `('should select existing values for filter $filter', ({ filter, selected }) => {
      createComponent({ selected, filter });

      expect(findListBox().props('selected')).toEqual(filter);
      expect(findPolicyRuleMultiSelect().props('value')).toEqual(selected);
    });
  });

  describe('remove', () => {
    it('should remove filter when only one is present', async () => {
      createComponent({ selected: [testStateNew1] });

      await findSectionLayout().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });

  describe('tooltip', () => {
    it('should not show tooltip icon when "newly detected" is selected', () => {
      createComponent({ filter: NEWLY_DETECTED });

      expectPopoverExists(false);
    });

    it('should show tooltip icon when "previously existing" is selected', () => {
      createComponent({ filter: PREVIOUSLY_EXISTING });

      expectPopoverExists(true);
    });

    it('should show tooltip when switching to "previously existing"', async () => {
      createComponent({ filter: NEWLY_DETECTED });

      expectPopoverExists(false);

      await findListBox().vm.$emit('select', PREVIOUSLY_EXISTING);

      expectPopoverExists(true);
    });

    it('should have correct tooltip text with bold warning', () => {
      createComponent({ filter: PREVIOUSLY_EXISTING });

      const popover = findPopover();
      expect(popover.exists()).toBe(true);
      expect(popover.text()).toContain('Warning:');
      expect(popover.text()).toContain(
        'Using this status in strictly enforced policies can block merge requests',
      );
    });
  });
});
