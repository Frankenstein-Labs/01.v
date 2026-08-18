import { GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DefaultRuleBadge from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/default_rule_badge.vue';

describe('DefaultRuleBadge', () => {
  let wrapper;

  const createComponent = (isDefaultConfiguration = true) => {
    wrapper = shallowMountExtended(DefaultRuleBadge, {
      propsData: {
        isDefaultConfiguration,
      },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findResetButton = () => wrapper.findComponent(GlButton);

  describe('when using default configuration', () => {
    beforeEach(() => {
      createComponent(true);
    });

    it('renders success badge', () => {
      expect(findBadge().exists()).toBe(true);
      expect(findBadge().props('variant')).toBe('success');
    });

    it('displays recommended selection text', () => {
      expect(findBadge().text()).toContain('Recommended selection');
    });

    it('renders popover targeting the badge', () => {
      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('target')).toBe(findBadge().attributes('id'));
    });

    it('does not show reset button', () => {
      expect(findResetButton().exists()).toBe(false);
    });
  });

  describe('when configuration is modified', () => {
    beforeEach(() => {
      createComponent(false);
    });

    it('does not render badge', () => {
      expect(findBadge().exists()).toBe(false);
    });

    it('does not render popover', () => {
      expect(findPopover().exists()).toBe(false);
    });

    it('shows reset button', () => {
      expect(findResetButton().exists()).toBe(true);
      expect(findResetButton().text()).toBe('Apply recommended selections');
    });

    it('emits reset event when reset button is clicked', async () => {
      await findResetButton().vm.$emit('click');

      expect(wrapper.emitted('reset')).toHaveLength(1);
    });
  });
});
