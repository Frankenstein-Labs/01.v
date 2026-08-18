import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlBadge, GlButton, GlFormCheckbox, GlIcon } from '@gitlab/ui';
import ScopeStep from 'ee/security_policies/components/create/steps/scope_step.vue';

const defaultPolicyData = { trigger: null, rules: [], actions: [], scope: 'all' };

describe('ScopeStep', () => {
  let wrapper;

  const createComponent = (policyData = defaultPolicyData) => {
    wrapper = shallowMount(ScopeStep, { propsData: { policyData } });
  };

  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  it('renders the title', () => {
    createComponent();

    expect(wrapper.text()).toContain('Where should this policy apply?');
  });

  it('renders All projects and Targeted scope cards', () => {
    createComponent();

    expect(wrapper.text()).toContain('All projects');
    expect(wrapper.text()).toContain('Targeted');
  });

  it('defaults to All projects scope', () => {
    createComponent();

    expect(wrapper.vm.scopeMode).toBe('all');
  });

  it('initialises from policyData.scope', () => {
    createComponent({ ...defaultPolicyData, scope: 'targeted' });

    expect(wrapper.vm.scopeMode).toBe('targeted');
  });

  it('renders phased rollout checkbox', () => {
    createComponent();

    expect(findCheckbox().exists()).toBe(true);
  });

  it('shows "247 projects affected" when scope is all', () => {
    createComponent();

    expect(wrapper.text()).toContain('247');
    expect(wrapper.text()).toContain('projects affected');
  });

  it('shows "0 projects affected" when targeted', async () => {
    createComponent();

    wrapper.vm.scopeMode = 'targeted';
    await nextTick();

    expect(wrapper.text()).toContain('0');
  });

  it('shows Target by sub-options when targeted mode selected', async () => {
    createComponent();

    wrapper.vm.scopeMode = 'targeted';
    await nextTick();

    expect(wrapper.text()).toContain('Target by');
    expect(wrapper.text()).toContain('Security Attributes');
    expect(wrapper.text()).toContain('Groups');
    expect(wrapper.text()).toContain('Compliance Frameworks');
    expect(wrapper.text()).toContain('Projects');
  });

  it('shows Recommended badge on Security Attributes option', async () => {
    createComponent();

    wrapper.vm.scopeMode = 'targeted';
    await nextTick();

    const badges = wrapper.findAllComponents(GlBadge).wrappers;
    const recommendedBadge = badges.find((b) => b.text() === 'Recommended');
    expect(recommendedBadge).toBeDefined();
  });

  it('emits update with scope when emitUpdate is called', () => {
    createComponent();

    wrapper.vm.emitUpdate();

    expect(wrapper.emitted('update')).toBeDefined();
    expect(wrapper.emitted('update')[0][0]).toHaveProperty('scope');
  });

  it('emits the current scopeMode in update payload', () => {
    createComponent({ ...defaultPolicyData, scope: 'targeted' });

    wrapper.vm.emitUpdate();

    expect(wrapper.emitted('update')[0][0].scope).toBe('targeted');
  });

  it('shows exclusions section', () => {
    createComponent();

    expect(wrapper.text()).toContain('Exclusions');
    expect(wrapper.text()).toContain('Temporary exceptions to scope');
  });

  it('renders Add exclusion button', () => {
    createComponent();

    const addBtn = wrapper
      .findAllComponents(GlButton)
      .wrappers.find((w) => w.text() === 'Add exclusion');
    expect(addBtn).toBeDefined();
  });

  it('renders phased rollout description', () => {
    createComponent();

    expect(wrapper.text()).toContain('Start with a phased rollout');
    expect(wrapper.text()).toContain('Pilot on a subset of projects');
  });

  it('renders filter placeholder icon in targeted mode', async () => {
    createComponent();

    wrapper.vm.scopeMode = 'targeted';
    await nextTick();

    expect(wrapper.findComponent(GlIcon).exists()).toBe(true);
  });
});
