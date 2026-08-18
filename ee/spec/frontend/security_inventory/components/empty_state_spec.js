import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import EMPTY_SUBGROUP_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-projects-md.svg?url';
import EmptyState from 'ee/security_inventory/components/empty_state.vue';

describe('EmptyState', () => {
  let wrapper;
  const mockNewProjectPath = '/groups/my-group/-/projects/new';

  const createComponent = (options = {}) => {
    wrapper = shallowMount(EmptyState, {
      provide: {
        newProjectPath: mockNewProjectPath,
      },
      ...options,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the GlEmptyState component', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
    });

    it('passes the correct props to the GlEmptyState component', () => {
      const emptyState = wrapper.findComponent(GlEmptyState);

      expect(emptyState.props()).toMatchObject({
        title: 'No projects found',
        description: 'Add projects to this group to start tracking their security posture.',
        svgPath: EMPTY_SUBGROUP_SVG,
        svgHeight: 150,
        primaryButtonText: 'New Project',
        primaryButtonLink: mockNewProjectPath,
      });
    });
  });
});
