import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import EmptyState from 'ee/security_configuration/secret_detection/components/empty_state.vue';

describe('EmptyState', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(EmptyState, {
      stubs: {
        GlSprintf,
      },
    });
  };

  const findComponent = () => wrapper.findComponent(GlEmptyState);
  const findLink = () => wrapper.findComponent(GlLink);
  const findActionButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  it('mounts', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the correct title', () => {
    expect(findComponent().props('title')).toBe('No exclusions yet');
  });

  it('renders the documentation link in the description', () => {
    expect(findLink().exists()).toBe(true);
    expect(findLink().attributes('href')).toBe(
      '/help/user/application_security/secret_detection/_index',
    );
  });

  it('renders the primary action button', () => {
    expect(findActionButton().exists()).toBe(true);
    expect(findActionButton().text()).toBe('Add exclusion');
  });

  it('emits primary-action when the primary button is clicked', async () => {
    await findActionButton().vm.$emit('click');
    expect(wrapper.emitted('primary-action')).toHaveLength(1);
  });
});
