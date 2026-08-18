import { shallowMount } from '@vue/test-utils';
import { GlAnimatedChevronRightDownIcon, GlCollapse } from '@gitlab/ui';
import GroupedPart from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/grouped_part.vue';

describe('GroupedPart', () => {
  let wrapper;

  const createComponent = (slots = {}) => {
    wrapper = shallowMount(GroupedPart, {
      slots: {
        header: '<span>Header Content</span>',
        default: '<div>Body Content</div>',
        ...slots,
      },
    });
  };

  const findToggleButton = () => wrapper.find('[role="button"]');
  const findChevronIcon = () => wrapper.findComponent(GlAnimatedChevronRightDownIcon);
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  beforeEach(() => {
    createComponent();
  });
  describe('initial state', () => {
    it('renders the toggle button', () => {
      expect(findToggleButton().exists()).toBe(true);
    });

    it('renders the chevron icon', () => {
      expect(findChevronIcon().exists()).toBe(true);
    });

    it('renders the collapse component', () => {
      expect(findCollapse().exists()).toBe(true);
    });

    it('starts in open state', () => {
      expect(findCollapse().props('visible')).toBe(true);
    });

    it('renders header slot content', () => {
      expect(wrapper.text()).toContain('Header Content');
    });

    it('renders default slot content', () => {
      expect(wrapper.text()).toContain('Body Content');
    });
  });

  describe('toggle functionality', () => {
    it('toggles to closed state when clicked', async () => {
      await findToggleButton().trigger('click');
      expect(findCollapse().props('visible')).toBe(false);
    });

    it('toggles back to open state when clicked again', async () => {
      // First click to close
      await findToggleButton().trigger('click');
      expect(findCollapse().props('visible')).toBe(false);

      // Second click to open
      await findToggleButton().trigger('click');
      expect(findCollapse().props('visible')).toBe(true);
    });
  });

  describe('props propagation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('correctly passes visible prop to collapse component based on state', async () => {
      // Initially open
      expect(findCollapse().props('visible')).toBe(true);

      await findToggleButton().trigger('click');
      expect(findCollapse().props('visible')).toBe(false);
    });
  });
});
