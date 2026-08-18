import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlFormInput, GlModal } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import CreatePolicyWizard from 'ee/security_policies/components/create/create_policy_wizard.vue';
import BuildPolicyStep from 'ee/security_policies/components/create/steps/build_policy_step.vue';
import ScopeStep from 'ee/security_policies/components/create/steps/scope_step.vue';

Vue.use(VueApollo);

describe('CreatePolicyWizard', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(CreatePolicyWizard, {
      apolloProvider: createMockApollo([
        [getSecurityPolicyProjectSub, jest.fn().mockResolvedValue({})],
      ]),
      provide: {
        assignedPolicyProject: {},
        namespacePath: 'group/project',
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  it('renders BuildPolicyStep on step 1', () => {
    createComponent();

    expect(wrapper.findComponent(BuildPolicyStep).exists()).toBe(true);
    expect(wrapper.findComponent(ScopeStep).exists()).toBe(false);
  });

  it('does not show back button on step 1', () => {
    createComponent();

    expect(wrapper.vm.currentStep).toBe(1);
  });

  it('advances to step 2 when next is called', async () => {
    createComponent();

    wrapper.vm.next();
    await nextTick();

    expect(wrapper.findComponent(ScopeStep).exists()).toBe(true);
    expect(wrapper.findComponent(BuildPolicyStep).exists()).toBe(false);
  });

  it('shows "Select scope" label on step 1', () => {
    createComponent();

    expect(wrapper.vm.nextLabel).toContain('Select scope');
  });

  it('shows "Enable policy" label on step 2', async () => {
    createComponent();

    wrapper.vm.next();
    await nextTick();

    expect(wrapper.vm.nextLabel).toBe('Enable policy');
  });

  it('currentStep is 2 after next', async () => {
    createComponent();

    wrapper.vm.next();
    await nextTick();

    expect(wrapper.vm.currentStep).toBe(2);
  });

  it('goes back to step 1 when back is called on step 2', async () => {
    createComponent();

    wrapper.vm.next();
    await nextTick();
    wrapper.vm.back();
    await nextTick();

    expect(wrapper.findComponent(BuildPolicyStep).exists()).toBe(true);
    expect(wrapper.vm.currentStep).toBe(1);
  });

  it('emits cancel immediately when policy is clean', () => {
    createComponent();

    wrapper.vm.requestCancel();

    expect(wrapper.emitted('cancel')).toBeDefined();
  });

  it('shows unsaved modal when cancelling with dirty state', async () => {
    createComponent();

    wrapper.vm.policyName = 'My Policy';
    await nextTick();
    wrapper.vm.requestCancel();
    await nextTick();

    expect(findModal().exists()).toBe(true);
  });

  it('emits cancel when modal primary (Save as draft) is confirmed', async () => {
    createComponent();
    wrapper.vm.policyName = 'My Policy';
    await nextTick();
    wrapper.vm.requestCancel();
    await nextTick();

    findModal().vm.$emit('primary');

    expect(wrapper.emitted('cancel')).toBeDefined();
  });

  it('emits cancel when modal cancel (Discard) is confirmed', async () => {
    createComponent();
    wrapper.vm.policyName = 'My Policy';
    await nextTick();
    wrapper.vm.requestCancel();
    await nextTick();

    findModal().vm.$emit('cancel');

    expect(wrapper.emitted('cancel')).toBeDefined();
  });

  it('renders policy name input', () => {
    createComponent();

    expect(wrapper.findComponent(GlFormInput).exists()).toBe(true);
  });

  it('renders 2-step indicator', () => {
    createComponent();

    const stepNumbers = wrapper.findAll('span').wrappers.filter((w) => /^[12]$/.test(w.text()));
    expect(stepNumbers).toHaveLength(2);
  });

  it('isDirty is false when policy is untouched', () => {
    createComponent();

    expect(wrapper.vm.isDirty).toBe(false);
  });

  it('isDirty is true when policy name is set', async () => {
    createComponent();

    wrapper.vm.policyName = 'My Policy';
    await nextTick();

    expect(wrapper.vm.isDirty).toBe(true);
  });
});
