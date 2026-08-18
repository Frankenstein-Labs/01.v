import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import SecurityPoliciesApp from 'ee/security_policies/components/app.vue';
import PoliciesList from 'ee/security_policies/components/list/policies_list.vue';
import CreatePolicyWizard from 'ee/security_policies/components/create/create_policy_wizard.vue';

describe('SecurityPoliciesApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(SecurityPoliciesApp);
  };

  const findPoliciesList = () => wrapper.findComponent(PoliciesList);
  const findCreateWizard = () => wrapper.findComponent(CreatePolicyWizard);

  it('renders the list view by default', () => {
    createComponent();

    expect(findPoliciesList().exists()).toBe(true);
    expect(findCreateWizard().exists()).toBe(false);
  });

  it('switches to the create view when the list emits create', async () => {
    createComponent();

    findPoliciesList().vm.$emit('create');
    await nextTick();

    expect(findPoliciesList().exists()).toBe(false);
    expect(findCreateWizard().exists()).toBe(true);
  });

  it('switches back to the list view when the wizard emits cancel', async () => {
    createComponent();
    findPoliciesList().vm.$emit('create');
    await nextTick();

    findCreateWizard().vm.$emit('cancel');
    await nextTick();

    expect(findPoliciesList().exists()).toBe(true);
    expect(findCreateWizard().exists()).toBe(false);
  });

  it('switches back to the list view when the wizard emits submit', async () => {
    createComponent();
    findPoliciesList().vm.$emit('create');
    await nextTick();

    findCreateWizard().vm.$emit('submit');
    await nextTick();

    expect(findPoliciesList().exists()).toBe(true);
    expect(findCreateWizard().exists()).toBe(false);
  });
});
