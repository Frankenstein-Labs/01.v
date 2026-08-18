import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionHeader from 'ee/pages/projects/get_started/components/section_header.vue';

describe('SectionHeader', () => {
  let wrapper;

  const defaultSection = {
    title: 'Test Section',
  };

  const createSection = (overrides = {}) => ({
    ...defaultSection,
    ...overrides,
  });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SectionHeader, {
      propsData: {
        section: createSection(),
        isExpanded: false,
        sectionIndex: 0,
        ...props,
      },
    });
  };

  const findTitle = () => wrapper.findByTestId('section-title');
  const findExpandButton = () => wrapper.findComponent(GlButton);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the section title', () => {
      expect(findTitle().text()).toBe('Test Section');
    });

    it('renders the expand button with correct icon and data-testid', () => {
      expect(findExpandButton().props('icon')).toBe('chevron-down');
      expect(findExpandButton().attributes('data-testid')).toBe('section-header-0');
    });
  });

  describe('expand/collapse behavior', () => {
    it('shows correct button label and icon when collapsed', () => {
      createComponent({ isExpanded: false });

      expect(findExpandButton().attributes('aria-label')).toBe('Expand');
      expect(findExpandButton().props('icon')).toBe('chevron-down');
    });

    it('shows correct button label and icon when expanded', () => {
      createComponent({ isExpanded: true });

      expect(findExpandButton().attributes('aria-label')).toBe('Collapse');
      expect(findExpandButton().props('icon')).toBe('chevron-up');
    });

    it('emits toggle-expand event when expand button is clicked', async () => {
      createComponent();
      await findExpandButton().vm.$emit('click');

      expect(wrapper.emitted('toggle-expand')).toHaveLength(1);
      expect(wrapper.emitted('toggle-expand')[0]).toEqual([]);
    });
  });
});
