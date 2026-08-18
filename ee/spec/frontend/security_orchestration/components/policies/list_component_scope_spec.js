import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import PolicyScopeRenderer from 'ee/security_orchestration/components/scope/policy_scope_renderer.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('ListComponentScope', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ListComponentScope, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.GROUP, ...provide },
    });
  };

  const findPolicyScopeRenderer = () => wrapper.findComponent(PolicyScopeRenderer);
  const findDefaultText = () => wrapper.findByTestId('default-text');

  it('renders PolicyScopeRenderer with list variant at group level', () => {
    createComponent();
    expect(findPolicyScopeRenderer().exists()).toBe(true);
    expect(findPolicyScopeRenderer().props('variant')).toBe('list');
  });

  it('forwards policyScope and isInstanceLevel to renderer', () => {
    const policyScope = { complianceFrameworks: { nodes: [{ id: 1 }] } };
    createComponent({ propsData: { policyScope, isInstanceLevel: true } });
    expect(findPolicyScopeRenderer().props('policyScope')).toEqual(policyScope);
    expect(findPolicyScopeRenderer().props('isInstanceLevel')).toBe(true);
  });

  it('forwards linkedSppItems to renderer', () => {
    const linkedSppItems = [{ id: '1' }, { id: '2' }];
    createComponent({ propsData: { linkedSppItems } });
    expect(findPolicyScopeRenderer().props('linkedSppItems')).toEqual(linkedSppItems);
  });

  it('shows default text for project with single linked item', () => {
    createComponent({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
    expect(findDefaultText().exists()).toBe(true);
    expect(findPolicyScopeRenderer().exists()).toBe(false);
  });

  it('shows renderer for project with multiple linked items', () => {
    createComponent({
      propsData: { linkedSppItems: [{ id: '1' }, { id: '2' }] },
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
    });
    expect(findDefaultText().exists()).toBe(false);
    expect(findPolicyScopeRenderer().exists()).toBe(true);
  });
});
