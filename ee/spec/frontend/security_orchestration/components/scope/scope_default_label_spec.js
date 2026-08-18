import { shallowMount } from '@vue/test-utils';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope/scope_default_label.vue';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';

describe('ScopeDefaultLabel', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(ScopeDefaultLabel, {
      propsData,
    });
  };

  const findToggleList = () => wrapper.findComponent(ToggleList);

  it.each`
    policyScope                                                                                                    | isGroup  | expectedText
    ${null}                                                                                                        | ${false} | ${'All projects linked to security policy project.'}
    ${null}                                                                                                        | ${true}  | ${'Default mode'}
    ${undefined}                                                                                                   | ${false} | ${'All projects linked to security policy project.'}
    ${undefined}                                                                                                   | ${true}  | ${'Default mode'}
    ${{}}                                                                                                          | ${false} | ${'All projects linked to security policy project.'}
    ${{}}                                                                                                          | ${true}  | ${'Default mode'}
    ${{ includingProjects: { nodes: [] } }}                                                                        | ${false} | ${'All projects linked to security policy project.'}
    ${{ includingProjects: { nodes: [] } }}                                                                        | ${true}  | ${'Default mode'}
    ${{ includingProjects: { nodes: [] }, excludingProjects: { nodes: [] }, complianceFrameworks: { nodes: [] } }} | ${true}  | ${'Default mode'}
  `('renders correct scope source', ({ policyScope, isGroup, expectedText }) => {
    createComponent({
      propsData: {
        policyScope,
        isGroup,
      },
    });

    expect(wrapper.text()).toBe(expectedText);
  });

  it('renders list of items for spp projects', () => {
    const SPP_ITEMS = [
      { id: 'gid://gitlab/Project/19', name: 'test' },
      { id: 'gid://gitlab/Group/19', name: 'test group' },
    ];

    createComponent({
      propsData: {
        isGroup: false,
        policyScope: {
          includingProjects: { nodes: [] },
          excludingProjects: { nodes: [] },
          complianceFrameworks: { nodes: [] },
        },
        linkedItems: SPP_ITEMS,
      },
    });

    expect(wrapper.text()).toBe('All projects linked to security policy project.');
    expect(findToggleList().props('items')).toEqual(['test', 'test group - group']);
  });
});
