import { shallowMount } from '@vue/test-utils';
import NoBillingForbiddenEmptyState from 'ee/ai/duo_agentic_chat/components/no_billing_forbidden_empty_state.vue';

describe('NoBillingForbiddenEmptyState', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(NoBillingForbiddenEmptyState);
  };

  beforeEach(() => {
    createWrapper();
  });

  it('renders the component', () => {
    expect(wrapper.find('[data-testid="no-billing-forbidden-empty-state"]').exists()).toBe(true);
  });

  it('shows a headline about usage billing', () => {
    expect(wrapper.text()).toContain('Usage billing not available');
  });

  it('instructs the user to contact their administrator', () => {
    expect(wrapper.text()).toContain('contact your administrator');
  });

  it('does not render a purchase CTA', () => {
    expect(wrapper.find('gl-button-stub').exists()).toBe(false);
  });
});
