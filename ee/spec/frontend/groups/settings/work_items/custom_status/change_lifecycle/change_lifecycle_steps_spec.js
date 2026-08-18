import { shallowMount } from '@vue/test-utils';
import ChangeLifecycleSteps from 'ee/groups/settings/work_items/custom_status/change_lifecycle/change_lifecycle_steps.vue';
import ChangeLifecycleStepper from 'ee/groups/settings/work_items/custom_status/change_lifecycle/change_lifecycle_stepper.vue';
import SelectLifecycle from 'ee/groups/settings/work_items/custom_status/change_lifecycle/select_lifecycle.vue';

describe('ChangeLifecycleSteps', () => {
  const defaultProps = {
    fullPath: 'group',
  };

  let wrapper;

  // Finder methods
  const findTitle = () => wrapper.find('h1');
  const findStepper = () => wrapper.findComponent(ChangeLifecycleStepper);
  const findSelectLifecycle = () => wrapper.findComponent(SelectLifecycle);

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(ChangeLifecycleSteps, {
      propsData: { ...defaultProps, ...props },
      mocks: {
        $route: {
          params: {
            workItemType: 'Issue',
          },
        },
      },
    });
  };

  it('renders the component with correct title', () => {
    createWrapper();

    expect(findTitle().text()).toContain('Change lifecycle: Issue');
  });

  it('renders Stepper component with correct props', () => {
    createWrapper();

    expect(findStepper().props('steps')).toHaveLength(2);
  });

  it('passes correct steps to Stepper', () => {
    createWrapper();

    const steps = findStepper().props('steps');

    expect(steps[0]).toEqual({
      label: 'Select lifecycle',
      description: 'Lifecycle selection',
    });
    expect(steps[1]).toEqual({
      label: 'Update work items',
      description: 'Update work items',
    });
  });

  it('renders SelectLifecycle component in step 0 with correct props', () => {
    createWrapper();

    expect(findSelectLifecycle().exists()).toBe(true);
    expect(findSelectLifecycle().props('workItemType')).toBe('Issue');
    expect(findSelectLifecycle().props('fullPath')).toBe('group');
  });

  it('handles custom work item types with display names', () => {
    wrapper = shallowMount(ChangeLifecycleSteps, {
      propsData: { ...defaultProps },
      mocks: {
        $route: {
          params: {
            workItemType: 'My Custom Type',
          },
        },
      },
    });

    expect(findTitle().text()).toContain('Change lifecycle: My Custom Type');
    expect(findSelectLifecycle().props('workItemType')).toBe('My Custom Type');
  });

  it('handles stepper events', () => {
    createWrapper();

    // Test that event handlers are bound (they should not throw)
    expect(() => findStepper().trigger('validate-step')).not.toThrow();
    expect(() => findStepper().trigger('finish')).not.toThrow();
    expect(() => findStepper().trigger('cancel')).not.toThrow();
  });
});
