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
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import App from 'ee/security_orchestration/components/policies/app.vue';

import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import {
  mockGroupPipelineExecutionPolicyList,
  mockProjectPipelineExecutionPolicyList,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import {
  mockGroupScanResultPolicyList,
  mockProjectScanResultPolicyList,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  mockGroupScanExecutionPolicyList,
  mockProjectScanExecutionPolicyList,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import GroupsToggleList from 'ee/security_orchestration/components/scope/groups_toggle_list.vue';
import { DEFAULT_PROVIDE } from '../mocks';
import {
  groups as includingGroups,
  projects as excludingProjects,
  generateMockResponse,
  openDrawer,
} from './utils';

Vue.use(VueApollo);

const policyGroupScope = {
  includingGroups: {
    nodes: includingGroups,
    pageInfo: {},
  },
  excludingProjects: {
    nodes: excludingProjects,
    pageInfo: {},
  },
};

const mockPipelineExecutionPoliciesProjectResponse = generateMockResponse(
  mockProjectPipelineExecutionPolicyList,
  policyGroupScope,
);
const mockPipelineExecutionPoliciesGroupResponse = generateMockResponse(
  mockGroupPipelineExecutionPolicyList,
  policyGroupScope,
);

const mockScanExecutionPoliciesProjectResponse = generateMockResponse(
  mockProjectScanExecutionPolicyList,
  policyGroupScope,
);
const mockScanExecutionPoliciesGroupResponse = generateMockResponse(
  mockGroupScanExecutionPolicyList,
  policyGroupScope,
);

const mockScanResultPoliciesProjectResponse = generateMockResponse(
  mockProjectScanResultPolicyList,
  policyGroupScope,
);
const mockScanResultPoliciesGroupResponse = generateMockResponse(
  mockGroupScanResultPolicyList,
  policyGroupScope,
);

/**
 * New mocks for policy scope including linked groups on project level
 * @type {jest.Mock<any, any, any>}
 */
const newProjectSecurityPoliciesSpy = projectSecurityPolicies([
  mockPipelineExecutionPoliciesProjectResponse,
  mockScanExecutionPoliciesProjectResponse,
  mockScanResultPoliciesProjectResponse,
]);

const newGroupSecurityPoliciesSpy = groupSecurityPolicies([
  mockPipelineExecutionPoliciesGroupResponse,
  mockScanExecutionPoliciesGroupResponse,
  mockScanResultPoliciesGroupResponse,
]);

const defaultRequestHandlers = {
  linkedSppItemsResponse: mockLinkedSppItemsResponse(),
  projectSecurityPolicies: newProjectSecurityPoliciesSpy,
  groupSecurityPolicies: newGroupSecurityPoliciesSpy,
};

describe('Policies List policy scope', () => {
  let wrapper;
  let requestHandlers;

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

  const findTable = () => wrapper.findComponentByTestId('policies-list');
  const findScopeInfoRow = () => wrapper.findComponent(ScopeInfoRow);
  const findAllListComponentScope = () => wrapper.findAllComponents(ListComponentScope);
  const findGroupsToggleList = () => wrapper.findComponent(GroupsToggleList);

  const expectDrawerScopeInfoRow = () => {
    expect(findGroupsToggleList().exists()).toBe(true);
    expect(findGroupsToggleList().props('groups')).toEqual(includingGroups);
    expect(findGroupsToggleList().props('projects')).toEqual(excludingProjects);
  };

  describe('project level', () => {
    describe('group policy scope for $policyType', () => {
      it.each`
        policyType              | policyScopeRowIndex | selectedRow
        ${'Pipeline execution'} | ${0}                | ${mockPipelineExecutionPoliciesProjectResponse}
        ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}
        ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}
      `(
        'scoped to itself when project is not SPP for $policyType',
        async ({ policyScopeRowIndex, selectedRow }) => {
          createWrapper();

          await waitForPromises();
          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe('This project');

          await openDrawer(findTable(), [selectedRow]);

          expect(findScopeInfoRow().text()).toContain('This policy is applied to current project.');
        },
      );

      it.each`
        policyType              | policyScopeRowIndex | selectedRow                                     | expectedResult
        ${'Pipeline execution'} | ${0}                | ${mockPipelineExecutionPoliciesProjectResponse} | ${'All projects in linked groups (2 groups)'}
        ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}     | ${'All projects in linked groups (2 groups)'}
        ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}        | ${'All projects in linked groups (2 groups)'}
      `(
        'scoped to linked groups when project is an SPP for $policyType',
        async ({ policyScopeRowIndex, selectedRow, expectedResult }) => {
          createWrapper({
            handlers: {
              linkedSppItemsResponse: mockLinkedSppItemsResponse({
                groups: includingGroups,
                namespaces: includingGroups,
              }),
            },
          });

          await waitForPromises();

          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe(expectedResult);

          await openDrawer(findTable(), [selectedRow]);

          expectDrawerScopeInfoRow();
        },
      );
    });
  });

  describe('group level', () => {
    it.each`
      policyType              | policyScopeRowIndex | selectedRow                                     | expectedResult
      ${'Pipeline execution'} | ${0}                | ${mockPipelineExecutionPoliciesProjectResponse} | ${'All projects in linked groups (2 groups)'}
      ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}     | ${'All projects in linked groups (2 groups)'}
      ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}        | ${'All projects in linked groups (2 groups)'}
    `(
      'scoped to linked groups on a group level for $policyType',
      async ({ policyScopeRowIndex, selectedRow, expectedResult }) => {
        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
          },
        });

        await waitForPromises();

        expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe(expectedResult);

        await openDrawer(findTable(), [selectedRow]);

        expectDrawerScopeInfoRow();
      },
    );
  });
});
