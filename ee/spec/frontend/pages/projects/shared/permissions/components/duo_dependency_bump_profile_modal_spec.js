import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DuoDependencyBumpProfileModal from 'ee/pages/projects/shared/permissions/components/duo_dependency_bump_profile_modal.vue';

describe('DuoDependencyBumpProfileModal', () => {
  let wrapper;

  const createWrapper = (props = {}) =>
    shallowMount(DuoDependencyBumpProfileModal, {
      propsData: {
        visible: true,
        ...props,
      },
    });

  const findModal = () => wrapper.findComponent(GlModal);

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('renders the modal with the correct title', () => {
    expect(findModal().props('title')).toBe('Turn on dependency version bumps');
  });

  it('renders the modal body text', () => {
    expect(findModal().text()).toContain(
      'Dependency version bumping is not turned on for this project. This feature works together with Agentic Breaking Change Resolution',
    );
  });

  it('renders the primary action with correct text', () => {
    expect(findModal().props('actionPrimary').text).toBe('Turn on dependency version bumps');
  });

  it('renders the cancel action with correct text', () => {
    expect(findModal().props('actionCancel').text).toBe(
      'Turn on without enabling dependency version bumps',
    );
  });

  it('emits confirm when primary action is triggered', () => {
    findModal().vm.$emit('primary');

    expect(wrapper.emitted('confirm')).toHaveLength(1);
  });

  it('emits cancel when cancel action is triggered', () => {
    findModal().vm.$emit('cancel');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  it('emits hide when modal hide is triggered', () => {
    findModal().vm.$emit('hide');

    expect(wrapper.emitted('hide')).toHaveLength(1);
  });

  it('shows loading state on primary button when isLoading is true', () => {
    wrapper = createWrapper({ isLoading: true });

    expect(findModal().props('actionPrimary').attributes.loading).toBe(true);
  });

  it('disables cancel button when isLoading is true', () => {
    wrapper = createWrapper({ isLoading: true });

    expect(findModal().props('actionCancel').attributes.disabled).toBe(true);
  });
});
