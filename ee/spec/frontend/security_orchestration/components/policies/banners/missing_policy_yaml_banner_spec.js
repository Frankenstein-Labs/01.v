import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MissingPolicyYamlBanner from 'ee/security_orchestration/components/policies/banners/missing_policy_yaml_banner.vue';

describe('MissingPolicyYamlBanner', () => {
  let wrapper;

  const policyYamlPath = 'path/to/policy.yml';

  const createComponent = () => {
    wrapper = shallowMount(MissingPolicyYamlBanner, {
      provide: { assignedPolicyProject: { policyYamlPath } },
      stubs: { GlSprintf },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findGlLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders danger alert with message', () => {
    expect(findAlert().props('variant')).toBe('danger');
    expect(findAlert().props('title')).toBe('No policy.yml file found');
    expect(findAlert().text()).toBe(
      'The linked security policy project does not contain a policy.yml file. Merge the policy changes to create the file, or add it manually.',
    );
    expect(findGlLink().props('href')).toBe(policyYamlPath);
  });
});
