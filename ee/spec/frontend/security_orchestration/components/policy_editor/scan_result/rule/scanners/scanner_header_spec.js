import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import DefaultRuleBadge from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/default_rule_badge.vue';

describe('ScannerHeader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ScannerHeader, {
      propsData: {
        title: 'Test Scanner Rule',
        visible: true,
        ...props,
      },
    });
  };

  const findCollapseButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findRemoveButton = () => wrapper.findComponentByTestId('remove-scanner');
  const findTitle = () => wrapper.find('h5');
  const findDefaultRuleBadge = () => wrapper.findComponent(DefaultRuleBadge);

  describe('rendering', () => {
    it('renders the title', () => {
      createComponent();

      expect(findTitle().text()).toBe('Test Scanner Rule');
    });

    it('renders the collapse button', () => {
      createComponent();

      expect(findCollapseButton().exists()).toBe(true);
    });

    it('does not render remove button by default', () => {
      createComponent();

      expect(findRemoveButton().exists()).toBe(false);
    });

    it('renders remove button when showRemoveButton is true', () => {
      createComponent({ showRemoveButton: true });

      expect(findRemoveButton().exists()).toBe(true);
      expect(findRemoveButton().props('icon')).toBe('remove');
      expect(findRemoveButton().props('category')).toBe('tertiary');
    });
  });

  describe('collapse icon', () => {
    it('shows chevron-up icon when visible is true', () => {
      createComponent({ visible: true });

      expect(findCollapseButton().props('icon')).toBe('chevron-up');
    });

    it('shows chevron-down icon when visible is false', () => {
      createComponent({ visible: false });

      expect(findCollapseButton().props('icon')).toBe('chevron-down');
    });
  });

  describe('margin class', () => {
    it('adds bottom margin when visible is true', () => {
      createComponent({ visible: true });

      expect(wrapper.find('div').classes()).toContain('gl-mb-3');
    });

    it('does not add bottom margin when visible is false', () => {
      createComponent({ visible: false });

      expect(wrapper.find('div').classes()).not.toContain('gl-mb-3');
    });
  });

  describe('events', () => {
    it('emits toggle event when collapse button is clicked', () => {
      createComponent();

      findCollapseButton().vm.$emit('click');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
    });

    it('emits remove event when remove button is clicked', () => {
      createComponent({ showRemoveButton: true });

      findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });

  describe('default rule badge', () => {
    it('does not render when showDefaultRuleBadge is false', () => {
      createComponent();

      expect(findDefaultRuleBadge().exists()).toBe(false);
    });

    it('renders when showDefaultRuleBadge is true and isDefaultConfiguration is true', () => {
      createComponent({ showDefaultRuleBadge: true, isDefaultConfiguration: true });

      expect(findDefaultRuleBadge().exists()).toBe(true);
      expect(findDefaultRuleBadge().props('isDefaultConfiguration')).toBe(true);
    });

    it('renders when showDefaultRuleBadge is true and isDefaultConfiguration is false', () => {
      createComponent({ showDefaultRuleBadge: true, isDefaultConfiguration: false });

      expect(findDefaultRuleBadge().exists()).toBe(true);
      expect(findDefaultRuleBadge().props('isDefaultConfiguration')).toBe(false);
    });

    it('emits reset event when badge emits reset', () => {
      createComponent({ showDefaultRuleBadge: true, isDefaultConfiguration: false });

      findDefaultRuleBadge().vm.$emit('reset');

      expect(wrapper.emitted('reset')).toHaveLength(1);
    });
  });
});
