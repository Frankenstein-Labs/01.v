import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import InvalidPolicyYamlBanner from 'ee/security_orchestration/components/policies/banners/invalid_policy_yaml_banner.vue';

describe('InvalidPolicyYamlBanner', () => {
  let wrapper;

  const policyYamlPath = 'path/to/policy.yml';

  const createComponent = () => {
    wrapper = shallowMount(InvalidPolicyYamlBanner, {
      provide: { assignedPolicyProject: { policyYamlPath } },
      stubs: { GlSprintf },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findGlLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders alert info with message', () => {
    expect(findAlert().props('title')).toBe('policy.yml file has syntax errors');
    expect(findAlert().text()).toBe(
      "Security policies cannot be enforced due to invalid YAML syntax in the linked security policy project's policy.yml.",
    );
    expect(findGlLink().props('href')).toBe(policyYamlPath);
  });
});
