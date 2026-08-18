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
import { DEFAULT_PROVIDE } from '../mocks';
import { groups as includingGroups, openDrawer } from './utils';

const linkedSppItemsResponseSpy = mockLinkedSppItemsResponse();

const newProjectSecurityPoliciesSpy = projectSecurityPolicies([
  mockProjectPipelineExecutionPolicyList,
  mockProjectScanExecutionPolicyList,
  mockProjectScanResultPolicyList,
]);

const newGroupSecurityPoliciesSpy = groupSecurityPolicies([
  mockGroupPipelineExecutionPolicyList,
  mockGroupScanExecutionPolicyList,
  mockGroupScanResultPolicyList,
]);

const defaultRequestHandlers = {
  linkedSppItemsResponse: linkedSppItemsResponseSpy,
  projectSecurityPolicies: newProjectSecurityPoliciesSpy,
  groupSecurityPolicies: newGroupSecurityPoliciesSpy,
};

describe('Policy list all projects scope', () => {
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

  describe('project level', () => {
    describe('default mode policy scope for $policyType', () => {
      it.each`
        policyType              | policyScopeRowIndex | selectedRow
        ${'Pipeline execution'} | ${0}                | ${mockProjectPipelineExecutionPolicyList}
        ${'Scan execution'}     | ${1}                | ${mockProjectScanExecutionPolicyList}
        ${'Scan Result'}        | ${2}                | ${mockProjectScanResultPolicyList}
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
        policyType              | policyScopeRowIndex | selectedRow                               | expectedResult
        ${'Pipeline execution'} | ${0}                | ${mockProjectPipelineExecutionPolicyList} | ${'All projects linked to security policy project.'}
        ${'Scan execution'}     | ${1}                | ${mockProjectScanExecutionPolicyList}     | ${'All projects linked to security policy project.'}
        ${'Scan Result'}        | ${2}                | ${mockProjectScanResultPolicyList}        | ${'All projects linked to security policy project.'}
      `(
        'default mode when project is an SPP for $policyType',
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

          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toContain(
            expectedResult,
          );

          await openDrawer(findTable(), [selectedRow]);

          expect(findScopeInfoRow().text()).toContain(expectedResult);
        },
      );
    });
  });

  describe('group level', () => {
    it.each`
      policyType              | policyScopeRowIndex | selectedRow                               | expectedResult
      ${'Pipeline execution'} | ${0}                | ${mockProjectPipelineExecutionPolicyList} | ${'Default mode'}
      ${'Scan execution'}     | ${1}                | ${mockProjectScanExecutionPolicyList}     | ${'Default mode'}
      ${'Scan Result'}        | ${2}                | ${mockProjectScanResultPolicyList}        | ${'Default mode'}
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

        expect(findScopeInfoRow().text()).toContain(expectedResult);
      },
    );
  });
});
