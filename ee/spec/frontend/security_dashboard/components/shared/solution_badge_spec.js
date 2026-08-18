import { GlPopover, GlBadge } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import SolutionBadge from 'ee/security_dashboard/components/shared/solution_badge.vue';

describe('Solution badge component', () => {
  let wrapper;
  const createWrapper = (props = { hasRemediation: true }) => {
    return mount(SolutionBadge, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  const findPopover = () => wrapper.findComponent(GlPopover);

  it('should have an icon badge', () => {
    expect(wrapper.findComponent(GlBadge).props()).toMatchObject({
      icon: 'bulb',
      variant: 'neutral',
    });
  });

  describe('popover', () => {
    it('should have a wrapping div as target', () => {
      expect(findPopover().props('target')()).toBe(wrapper.element);
    });

    it('renders the title', () => {
      expect(findPopover().props('title')).toBe('A solution is available for this vulnerability');
    });

    it('renders the description', () => {
      expect(findPopover().props('content')).toBe(
        'Create a merge request to implement this solution, or download and apply the patch manually.',
      );
    });
  });
});
