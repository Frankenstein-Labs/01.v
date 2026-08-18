import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyScopeRenderer from 'ee/security_orchestration/components/scope/policy_scope_renderer.vue';
import ComplianceFrameworksToggleList from 'ee/security_orchestration/components/scope/compliance_frameworks_toggle_list.vue';
import ProjectsToggleList from 'ee/security_orchestration/components/scope/projects_toggle_list.vue';
import GroupsToggleList from 'ee/security_orchestration/components/scope/groups_toggle_list.vue';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope/scope_default_label.vue';
import LoaderWithMessage from 'ee/security_orchestration/components/loader_with_message.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('PolicyScopeRenderer', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyScopeRenderer, {
      propsData: { variant: 'drawer', ...propsData },
      provide: { namespaceType: NAMESPACE_TYPES.GROUP, ...provide },
    });
  };

  it('shows loader when loading=true and does not render scope component', () => {
    createComponent({ propsData: { variant: 'drawer', loading: true } });
    expect(wrapper.findComponent(LoaderWithMessage).exists()).toBe(true);
    expect(wrapper.findComponent(ScopeDefaultLabel).exists()).toBe(false);
    expect(wrapper.findComponent(ComplianceFrameworksToggleList).exists()).toBe(false);
    expect(wrapper.findComponent(ProjectsToggleList).exists()).toBe(false);
    expect(wrapper.findComponent(GroupsToggleList).exists()).toBe(false);
  });

  it('renders ComplianceFrameworksToggleList for compliance frameworks scope', () => {
    createComponent({
      propsData: {
        variant: 'drawer',
        policyScope: { complianceFrameworks: { nodes: [{ id: 1 }] } },
      },
    });
    expect(wrapper.findComponent(ComplianceFrameworksToggleList).exists()).toBe(true);
    expect(
      wrapper.findComponent(ComplianceFrameworksToggleList).props('complianceFrameworks'),
    ).toEqual([{ id: 1 }]);
  });

  it('renders GroupsToggleList for groups scope', () => {
    createComponent({
      propsData: {
        variant: 'drawer',
        policyScope: { includingGroups: { nodes: [{ id: 1 }] } },
      },
    });
    expect(wrapper.findComponent(GroupsToggleList).exists()).toBe(true);
    expect(wrapper.findComponent(GroupsToggleList).props('groups')).toEqual([{ id: 1 }]);
  });

  it('renders GroupsToggleList with projects for compound scope', () => {
    createComponent({
      propsData: {
        variant: 'drawer',
        policyScope: {
          includingGroups: { nodes: [{ id: 1 }] },
          excludingProjects: { nodes: [{ id: 2 }] },
        },
      },
    });
    const groupsList = wrapper.findComponent(GroupsToggleList);
    expect(groupsList.exists()).toBe(true);
    expect(groupsList.props('groups')).toEqual([{ id: 1 }]);
    expect(groupsList.props('projects')).toEqual([{ id: 2 }]);
  });

  it('renders ProjectsToggleList for projects scope', () => {
    createComponent({
      propsData: {
        variant: 'drawer',
        policyScope: { includingProjects: { nodes: [{ id: 1 }] } },
      },
    });
    expect(wrapper.findComponent(ProjectsToggleList).exists()).toBe(true);
  });

  it('renders ScopeDefaultLabel for empty scope', () => {
    createComponent({ propsData: { variant: 'drawer', policyScope: {} } });
    expect(wrapper.findComponent(ScopeDefaultLabel).exists()).toBe(true);
  });

  it('passes labelsToShow=2 to ComplianceFrameworksToggleList for list variant', () => {
    createComponent({
      propsData: {
        variant: 'list',
        policyScope: { complianceFrameworks: { nodes: [{ id: 1 }] } },
      },
    });
    expect(wrapper.findComponent(ComplianceFrameworksToggleList).props('labelsToShow')).toBe(2);
  });
});
