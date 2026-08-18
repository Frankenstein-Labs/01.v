import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlBadge } from '@gitlab/ui';
import ReviewImpactStep from 'ee/security_policies/components/create/steps/review_impact_step.vue';

const defaultPolicyData = { trigger: null, rules: [], actions: [], scope: 'all' };

describe('ReviewImpactStep', () => {
  let wrapper;

  const createComponent = ({
    policyData = defaultPolicyData,
    policyName = '',
    enforcementMode = 'enforce',
  } = {}) => {
    wrapper = shallowMount(ReviewImpactStep, {
      propsData: { policyData, policyName, enforcementMode },
    });
  };

  it('renders the title', () => {
    createComponent();

    expect(wrapper.text()).toContain('Impact estimate');
  });

  it('renders policy configuration section', () => {
    createComponent();

    expect(wrapper.text()).toContain('Policy configuration');
    expect(wrapper.text()).toContain('Review your settings before enabling');
  });

  it('shows dash when policy name is empty', () => {
    createComponent();

    expect(wrapper.vm.displayName).toBe('—');
  });

  it('shows policy name when provided', () => {
    createComponent({ policyName: 'My Policy' });

    expect(wrapper.text()).toContain('My Policy');
  });

  it('shows Enforce mode label for enforce enforcement mode', () => {
    createComponent({ enforcementMode: 'enforce' });

    expect(wrapper.vm.modeLabel).toBe('Enforce');
  });

  it('shows Warn mode label for warn enforcement mode', () => {
    createComponent({ enforcementMode: 'warn' });

    expect(wrapper.vm.modeLabel).toBe('Warn');
  });

  it('shows danger alert for enforce mode', () => {
    createComponent({ enforcementMode: 'enforce' });

    expect(wrapper.findComponent(GlAlert).props('variant')).toBe('danger');
  });

  it('shows warning alert for warn mode', () => {
    createComponent({ enforcementMode: 'warn' });

    expect(wrapper.findComponent(GlAlert).props('variant')).toBe('warning');
  });

  it('shows info alert for audit mode', () => {
    createComponent({ enforcementMode: 'audit' });

    expect(wrapper.findComponent(GlAlert).props('variant')).toBe('info');
  });

  it('renders the Last 30 days badge', () => {
    createComponent();

    expect(wrapper.text()).toContain('Last 30 days');
  });

  it('renders 4 impact tiles', () => {
    createComponent();

    expect(wrapper.text()).toContain('Projects in initial rollout');
    expect(wrapper.text()).toContain('MRs that would trigger');
    expect(wrapper.text()).toContain('Estimated violations');
    expect(wrapper.text()).toContain('Rules needing attention');
  });

  it('renders recent events section', () => {
    createComponent();

    expect(wrapper.text()).toContain('Recent events that would have been caught');
  });

  it('renders outcome badges for each event', () => {
    createComponent();

    const badges = wrapper.findAllComponents(GlBadge).wrappers;
    expect(badges.length).toBeGreaterThan(0);
  });

  it('renders 247 in projects in initial rollout tile', () => {
    createComponent();

    expect(wrapper.text()).toContain('247');
  });

  it('renders blocked/warned badges with correct variants', () => {
    createComponent();

    const badges = wrapper.findAllComponents(GlBadge).wrappers;
    const variants = badges.map((b) => b.props('variant'));
    expect(variants).toContain('danger');
    expect(variants).toContain('warning');
  });

  it('renders MR references in recent events', () => {
    createComponent();

    expect(wrapper.text()).toContain('MR !234');
    expect(wrapper.text()).toContain('MR !228');
  });
});
