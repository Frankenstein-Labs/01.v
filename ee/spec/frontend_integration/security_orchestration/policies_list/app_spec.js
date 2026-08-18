import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockLinkedSppItemsResponse,
  groupSecurityPolicies,
  projectSecurityPolicies,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockGroupPipelineExecutionPolicyList,
  mockGroupPipelineExecutionSchedulePolicyList,
  mockProjectPipelineExecutionPolicyList,
  mockProjectPipelineExecutionSchedulePolicyList,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import {
  mockGroupScanResultPolicyList,
  mockProjectScanResultPolicyList,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  mockGroupScanExecutionPolicyList,
  mockProjectScanExecutionPolicyList,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { mockProjectVulnerabilityManagementPolicyList } from 'ee_jest/security_orchestration/mocks/mock_vulnerability_management_policy_data';
import { DEFAULT_PROVIDE } from './mocks';

Vue.use(VueApollo);

const linkedSppItemsResponseSpy = mockLinkedSppItemsResponse();

const combinedGroupPolicyList = [
  mockProjectVulnerabilityManagementPolicyList,
  mockGroupPipelineExecutionPolicyList,
  mockGroupPipelineExecutionSchedulePolicyList,
  mockGroupScanResultPolicyList,
  mockGroupScanExecutionPolicyList,
];

const combinedProjectPolicyList = [
  mockProjectVulnerabilityManagementPolicyList,
  mockProjectPipelineExecutionPolicyList,
  mockProjectPipelineExecutionSchedulePolicyList,
  mockProjectScanResultPolicyList,
  mockProjectScanExecutionPolicyList,
];

const groupSecurityPoliciesSpy = groupSecurityPolicies(combinedGroupPolicyList);
const projectSecurityPoliciesSpy = projectSecurityPolicies(combinedProjectPolicyList);

const defaultRequestHandlers = {
  linkedSppItemsResponse: linkedSppItemsResponseSpy,
  groupSecurityPolicies: groupSecurityPoliciesSpy,
  projectSecurityPolicies: projectSecurityPoliciesSpy,
};

describe('Policies List', () => {
  let wrapper;
  let requestHandlers;

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  const createWrapper = ({ handlers = [], provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = mountExtended(App, {
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],
        [groupSecurityPoliciesQuery, requestHandlers.groupSecurityPolicies],
        [projectSecurityPoliciesQuery, requestHandlers.projectSecurityPolicies],
      ]),
    });
  };

  const findEmptyListState = () => wrapper.findByTestId('empty-list-state');

  describe('project level', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the page correctly', () => {
      expect(findPoliciesHeader().exists()).toBe(true);
      expect(findPoliciesList().exists()).toBe(true);
    });

    it('fetches correct policies', () => {
      expect(requestHandlers.groupSecurityPolicies).not.toHaveBeenCalled();

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalled();
    });
  });

  describe('group level', () => {
    beforeEach(() => {
      createWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });
    });

    it('fetches correct policies', () => {
      expect(requestHandlers.groupSecurityPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectSecurityPolicies).not.toHaveBeenCalled();
    });
  });

  describe('network errors', () => {
    it('shows the empty list state', async () => {
      const errorHandlers = Object.keys(defaultRequestHandlers).reduce((acc, curr) => {
        acc[curr] = jest.fn().mockRejectedValue();
        return acc;
      }, {});
      createWrapper({ handlers: errorHandlers });
      await waitForPromises();
      expect(findEmptyListState().exists()).toBe(true);
    });
  });
});
