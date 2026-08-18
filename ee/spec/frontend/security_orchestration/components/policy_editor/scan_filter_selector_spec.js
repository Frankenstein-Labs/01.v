import { GlDisclosureDropdown } from '@gitlab/ui';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

const GOOD_FILTER = 'GOOD_FILTER';
const FILTERS = [{ text: 'Good filter', value: GOOD_FILTER, tooltip: 'This is a good filter' }];

describe('ScanFilterSelector', () => {
  let wrapper;

  const createComponent = (props = { filters: FILTERS }) => {
    wrapper = shallowMountExtended(ScanFilterSelector, {
      propsData: {
        ...props,
      },
      stubs: {
        SectionLayout,
        GlDisclosureDropdown,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findListItemContent = () => wrapper.findByTestId('list-item-content');

  describe('default', () => {
    it('renders options', () => {
      createComponent();
      expect(findDropdown().props('items')).toEqual([
        { ...FILTERS[0], extraAttrs: { disabled: false } },
      ]);
    });

    it('can have disabled state', () => {
      createComponent({ disabled: true });
      expect(findDropdown().props('disabled')).toBe(true);
    });

    it('can have custom tooltip text', () => {
      const tooltipTitle = 'Custom tooltip';
      createComponent({ tooltipTitle });
      expect(findDropdown().attributes('title')).toBe(tooltipTitle);
    });

    it('can render custom filter tooltip based on callback', () => {
      const customFilterTooltip = () => 'Custom';
      createComponent({ filters: FILTERS, selected: { [GOOD_FILTER]: [] }, customFilterTooltip });
      expect(wrapper.find('gl-badge-stub').exists()).toBe(false);
      expect(findListItemContent().classes()).toContain('!gl-pointer-events-auto');
    });

    it('can set filter disabled on callback', () => {
      const shouldDisableFilter = () => true;
      createComponent({ filters: FILTERS, shouldDisableFilter });
      expect(wrapper.find('gl-badge-stub').exists()).toBe(false);
      expect(findListItemContent().classes()).toContain('!gl-pointer-events-auto');
    });
  });

  describe('when filter is unselected', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not apply disabled styling', () => {
      expect(findListItemContent().classes()).not.toContain('!gl-pointer-events-auto');
    });

    it('emits the "select" event when it has been selected', async () => {
      expect(wrapper.emitted('select')).toBeUndefined();
      await findDropdown().vm.$emit('action', FILTERS[0]);
      expect(wrapper.emitted('select')).toEqual([[GOOD_FILTER]]);
    });
  });

  describe('when filter is selected', () => {
    beforeEach(() => {
      createComponent({ filters: FILTERS, selected: { [GOOD_FILTER]: [] } });
    });

    it('disables the filter', () => {
      expect(wrapper.find('gl-badge-stub').exists()).toBe(false);
      expect(findListItemContent().classes()).toContain('!gl-pointer-events-auto');
      expect(findDropdown().props('items')).toEqual([
        { ...FILTERS[0], extraAttrs: { disabled: true } },
      ]);
    });
  });

  describe('custom button text', () => {
    it('should render default button text', () => {
      createComponent();

      expect(findDropdown().props('toggleText')).toBe('Add new criteria');
    });

    it('should render custom button text', () => {
      const buttonText = 'add custom variable';
      createComponent({ buttonText });

      expect(findDropdown().props('toggleText')).toBe(buttonText);
    });
  });

  describe('custom header text', () => {
    it('should render default header text', () => {
      createComponent();

      expect(findDropdown().text()).toContain('Choose criteria type');
    });

    it('should render custom header text', () => {
      const header = 'add custom variable';
      createComponent({ header });

      expect(findDropdown().text()).toContain(header);
    });
  });
});
