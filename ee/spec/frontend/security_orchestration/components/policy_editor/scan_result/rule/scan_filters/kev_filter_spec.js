import { GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import KevFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/kev_filter.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';

describe('KevFilter', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(KevFilter, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findCheckBox = () => wrapper.findComponent(GlFormCheckbox);
  const findPolicyPopover = () => wrapper.findComponent(PolicyPopover);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders checkbox filter', () => {
      expect(findCheckBox().exists()).toBe(true);
      expect(findCheckBox().props('checked')).toBe(false);
      expect(wrapper.text()).toBe('Only show/block vulnerabilities that are being exploited.');
      expect(findPolicyPopover().exists()).toBe(true);
      expect(findSectionLayout().props('ruleLabel')).toBe('KEV status');
      expect(findSectionLayout().props('showRemoveButton')).toBe(false);
      expect(findPolicyPopover().props('content')).toBe(
        'Select this option if you want the policy to block the merge request (or warn the user if the policy is in warn mode) only if it includes vulnerabilities that are actively exploited according to their KEV status. %{linkStart}Learn more%{linkEnd}.',
      );
      expect(findPolicyPopover().props('title')).toBe('KEV status');
      expect(findPolicyPopover().props('href')).toBe(
        '/help/user/application_security/policies/_index.md',
      );
    });

    it('enables filter', () => {
      findCheckBox().vm.$emit('input', true);

      expect(wrapper.emitted('select')).toEqual([[true]]);
    });
  });

  describe('enabled filter', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selected: true,
        },
      });
    });

    it('renders selected filter', () => {
      expect(findCheckBox().props('checked')).toBe(true);
    });
  });
});
