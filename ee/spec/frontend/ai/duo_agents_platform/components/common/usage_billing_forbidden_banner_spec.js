import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import UsageBillingForbiddenBanner from 'ee/ai/duo_agents_platform/components/common/usage_billing_forbidden_banner.vue';

describe('UsageBillingForbiddenBanner', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(UsageBillingForbiddenBanner);
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    createWrapper();
  });

  it('renders the alert component', () => {
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('variant')).toBe('danger');
    expect(findAlert().props('dismissible')).toBe(false);
  });

  it('renders the billing forbidden message', () => {
    expect(findAlert().text()).toContain('Usage billing is not available for this account');
    expect(findAlert().text()).toContain('contact your administrator');
  });
});
