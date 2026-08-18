import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CriteriaItem from 'ee/security_orchestration/components/policy_editor/shared/criteria_item.vue';

describe('CriteriaItem', () => {
  let wrapper;

  const createWrapper = (item) => {
    wrapper = shallowMountExtended(CriteriaItem, {
      propsData: { item },
    });
  };

  const findItemText = () => wrapper.findByTestId('list-item-text');
  const findItemContent = () => wrapper.findByTestId('list-item-content');

  describe('enabled item', () => {
    beforeEach(() => {
      createWrapper({ value: 'test', text: 'Test Item', disabled: false });
    });

    it('renders item text', () => {
      expect(findItemText().text()).toBe('Test Item');
    });

    it('does not apply pointer-events-auto class', () => {
      expect(findItemContent().classes()).not.toContain('!gl-pointer-events-auto');
    });

    it('does not apply subtle text class', () => {
      expect(findItemText().classes()).not.toContain('gl-text-subtle');
    });
  });

  describe('disabled item', () => {
    beforeEach(() => {
      createWrapper({ value: 'test', text: 'Test Item', disabled: true });
    });

    it('renders item text', () => {
      expect(findItemText().text()).toBe('Test Item');
    });

    it('does not render a badge', () => {
      expect(wrapper.find('gl-badge-stub').exists()).toBe(false);
    });

    it('applies pointer-events-auto to allow tooltip', () => {
      expect(findItemContent().classes()).toContain('!gl-pointer-events-auto');
    });

    it('applies subtle text class', () => {
      expect(findItemText().classes()).toContain('gl-text-subtle');
    });
  });
});
