import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import InvalidPoliciesBanner from 'ee/security_orchestration/components/policies/banners/invalid_policies_banner.vue';

describe('InvalidPoliciesBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(InvalidPoliciesBanner);
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    createComponent();
  });

  it('renders alert info with message', () => {
    expect(findAlert().props('title')).toBe('Policies are invalid');
    expect(findAlert().text()).toBe(
      'No policies in the security policy project will be enforced until the invalid policies are fixed.',
    );
  });
});
