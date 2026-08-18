import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import PolicyScopeRenderer from 'ee/security_orchestration/components/scope/policy_scope_renderer.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';

describe('ScopeInfoRow', () => {
  let wrapper;
  let requestHandler;

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;
    return createMockApollo([[getSppLinkedProjectsGroups, requestHandler]]);
  };

  const createComponent = ({
    propsData = {},
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(ScopeInfoRow, {
      apolloProvider: createMockApolloProvider(handler),
      propsData,
      provide: {
        namespaceType: NAMESPACE_TYPES.GROUP,
        namespacePath: 'gitlab-org',
        ...provide,
      },
    });
  };

  const findPolicyScopeRenderer = () => wrapper.findComponent(PolicyScopeRenderer);
  const findPolicyScopeSection = () => wrapper.findByTestId('policy-scope');
  const findDefaultProjectText = () => wrapper.findByTestId('default-project-text');

  it('renders the scope info row', () => {
    createComponent();
    expect(findPolicyScopeSection().exists()).toBe(true);
  });

  it('renders PolicyScopeRenderer with drawer variant at group level', () => {
    createComponent({ propsData: { policyScope: { complianceFrameworks: { nodes: [] } } } });
    expect(findPolicyScopeRenderer().exists()).toBe(true);
    expect(findPolicyScopeRenderer().props('variant')).toBe('drawer');
  });

  it('forwards policyScope and isInstanceLevel to renderer', () => {
    const policyScope = { complianceFrameworks: { nodes: [{ id: 1 }] } };
    createComponent({ propsData: { policyScope, isInstanceLevel: true } });
    expect(findPolicyScopeRenderer().props('policyScope')).toEqual(policyScope);
    expect(findPolicyScopeRenderer().props('isInstanceLevel')).toBe(true);
  });

  describe('project level', () => {
    it('shows renderer with loading prop while Apollo query is loading', () => {
      createComponent({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
      expect(findPolicyScopeRenderer().exists()).toBe(true);
      expect(findPolicyScopeRenderer().props('loading')).toBe(true);
      expect(findDefaultProjectText().exists()).toBe(false);
      expect(requestHandler).toHaveBeenCalledTimes(1);
    });

    it('shows default project text for project with single linked item', async () => {
      createComponent({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
      await waitForPromises();
      expect(findDefaultProjectText().text()).toBe('This policy is applied to current project.');
    });

    it('shows renderer with linkedSppItems for project with multiple linked items', async () => {
      const projects = [
        { id: '1', name: 'name1', fullPath: 'fullPath1' },
        { id: '2', name: 'name2', fullPath: 'fullPath2' },
      ];
      createComponent({
        handler: mockLinkedSppItemsResponse({ projects }),
        provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
      });
      await waitForPromises();
      expect(findPolicyScopeRenderer().exists()).toBe(true);
      expect(findPolicyScopeRenderer().props('linkedSppItems')).toEqual(projects);
      expect(findPolicyScopeRenderer().props('loading')).toBe(false);
    });
  });

  describe('group level', () => {
    it('does not query linked SPP items', async () => {
      createComponent();
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledTimes(0);
    });
  });
});
