import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlDrawer, GlTabs, GlTab } from '@gitlab/ui';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import ScanExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/scan_execution/details_drawer.vue';
import ScanResultDrawer from 'ee/security_orchestration/components/policy_drawer/scan_result/details_drawer.vue';
import PipelineExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/details_drawer.vue';
import DependencyFirewallDrawer from 'ee/security_orchestration/components/policy_drawer/dependency_firewall/details_drawer.vue';
import TestRunsTab from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/test_runs_tab.vue';
import projectSecurityPolicyDetailsQuery from 'ee/security_orchestration/graphql/queries/project_security_policy_details.query.graphql';
import {
  POLICY_TYPE_COMPONENT_OPTIONS,
  APPROVAL_POLICY_TYPE,
  PIPELINE_EXECUTION_POLICY_TYPE,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import YamlEditor from 'ee/security_orchestration/components/yaml_editor.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockProjectScanExecutionPolicy,
  mockGroupScanExecutionPolicy,
  mockProjectScanExecutionPolicyWithWrapper,
} from '../../mocks/mock_scan_execution_policy_data';
import {
  mockProjectPipelineExecutionPolicy,
  mockProjectPipelineExecutionSchedulePolicy,
} from '../../mocks/mock_pipeline_execution_policy_data';
import { mockProjectScanResultPolicy } from '../../mocks/mock_scan_result_policy_data';
import { mockProjectVulnerabilityManagementPolicy } from '../../mocks/mock_vulnerability_management_policy_data';
import { mockEnforcedDfwPolicy } from '../../mocks/mock_dependency_firewall_policy_data';

describe('DrawerWrapper component', () => {
  let wrapper;

  const factory = ({
    mountFn = shallowMountExtended,
    propsData,
    stubs = {},
    provide = {},
    apolloProvider = null,
  } = {}) => {
    wrapper = mountFn(DrawerWrapper, {
      propsData: {
        open: true,
        ...propsData,
      },
      provide: {
        namespaceType: NAMESPACE_TYPES.PROJECT,
        namespacePath: 'gitlab-org',
        ...provide,
      },
      stubs: { YamlEditor: true, ...stubs },
      ...(apolloProvider && { apolloProvider }),
    });
  };

  // Finders
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findDependencyFirewallDrawer = () => wrapper.findComponent(DependencyFirewallDrawer);
  const findPopover = () => wrapper.findByTestId('edit-button-popover');
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findTestRunsTab = () => wrapper.findByTestId('policy-test-runs-tab');
  const findScanExecutionDrawer = () => wrapper.findComponent(ScanExecutionDrawer);
  const findDefaultComponentPolicyEditor = () => wrapper.findComponent(YamlEditor);
  const findTabPolicyEditor = () => wrapper.findByTestId('policy-yaml-editor-tab-content');

  // Shared assertions
  const itRendersEditButton = () => {
    it('renders edit button', () => {
      const button = findEditButton();
      expect(button.exists()).toBe(true);
      expect(button.attributes().href).toBe(
        '/policies/policy-name/edit?type="scan_execution_policy"',
      );
    });
  };

  describe('without a policy', () => {
    beforeEach(() => {
      factory({ stubs: { GlDrawer } });
    });

    it('does not render edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('given a generic policy', () => {
    beforeEach(() => {
      factory({
        propsData: {
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value,
          policy: mockProjectScanExecutionPolicyWithWrapper,
        },
        stubs: {
          YamlEditor,
          GlDrawer,
        },
      });
    });

    it('renders policy editor with manifest', () => {
      expect(findDefaultComponentPolicyEditor().attributes('value')).toBe(
        mockProjectScanExecutionPolicyWithWrapper.yaml,
      );
    });

    itRendersEditButton();

    it('does not render the edit button popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('based on policy permission', () => {
    it.each`
      disableScanPolicyUpdate | expectedResult
      ${true}                 | ${false}
      ${false}                | ${true}
    `('renders edit button', ({ disableScanPolicyUpdate, expectedResult }) => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicy,
          disableScanPolicyUpdate,
        },
        stubs: {
          GlDrawer,
        },
      });

      expect(findEditButton().exists()).toBe(expectedResult);
    });
  });

  describe('given a scanExecution policy', () => {
    beforeEach(() => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicyWithWrapper,
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value,
        },
        stubs: {
          GlButton,
          GlDrawer,
          GlTabs,
        },
      });
    });

    it(`renders the scanExecution component`, () => {
      expect(findScanExecutionDrawer().exists()).toBe(true);
    });

    it('renders the tabs', () => {
      expect(findAllTabs()).toHaveLength(2);
    });

    it('renders the policy editor', () => {
      expect(findTabPolicyEditor().attributes('value')).toBe(
        mockProjectScanExecutionPolicyWithWrapper.yaml,
      );
    });

    itRendersEditButton();
  });

  describe('inherited policy', () => {
    beforeEach(() => {
      factory({
        propsData: {
          policy: mockGroupScanExecutionPolicy,
        },
        stubs: {
          GlDrawer,
        },
      });
    });

    it('renders a disabled edit button', () => {
      const button = findEditButton();
      expect(button.exists()).toBe(true);
      expect(button.props('disabled')).toBe(true);
    });

    it('renders the edit button popover', () => {
      expect(findPopover().exists()).toBe(true);
    });
  });

  describe('policy without source namespace', () => {
    it('should not render popover for policy without namespace', () => {
      factory({
        propsData: {
          policy: {
            ...mockGroupScanExecutionPolicy,
            source: {
              __typename: 'GroupSecurityPolicySource',
              inherited: true,
              namespace: undefined,
            },
          },
        },
      });

      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('given a pipelineExecutionSchedule policy', () => {
    const findTestRunsTabComponent = () => wrapper.findComponent(TestRunsTab);

    beforeEach(() => {
      factory({
        propsData: {
          policy: mockProjectPipelineExecutionSchedulePolicy,
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.value,
        },
        stubs: {
          GlDrawer,
          GlTabs,
        },
      });
    });

    it('renders the test runs tab', () => {
      expect(findTestRunsTab().exists()).toBe(true);
    });

    it('renders three tabs (Details, Test runs, YAML)', () => {
      expect(findAllTabs()).toHaveLength(3);
    });

    it('passes null activeTestRun to TestRunsTab when none is provided', () => {
      expect(findTestRunsTabComponent().props('activeTestRun')).toBeNull();
    });

    it('forwards activeTestRun to TestRunsTab', () => {
      const activeTestRun = {
        id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/42',
        state: 'RUNNING',
        completed: false,
      };
      factory({
        propsData: {
          policy: mockProjectPipelineExecutionSchedulePolicy,
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.value,
          activeTestRun,
        },
        stubs: { GlDrawer, GlTabs },
      });

      expect(findTestRunsTabComponent().props('activeTestRun')).toEqual(activeTestRun);
    });

    it('re-emits test-run-created from TestRunsTab', () => {
      const newTestRun = {
        id: 'gid://gitlab/Security::ScheduledPipelineExecutionPolicyTestRun/43',
        state: 'PENDING',
      };

      findTestRunsTabComponent().vm.$emit('test-run-created', newTestRun);

      expect(wrapper.emitted('test-run-created')).toEqual([[newTestRun]]);
    });
  });

  describe('policyTypeEnum', () => {
    it.each`
      type                                    | expected
      ${'scan_execution_policy'}              | ${'SCAN_EXECUTION_POLICY'}
      ${'approval_policy'}                    | ${'APPROVAL_POLICY'}
      ${'pipeline_execution_policy'}          | ${'PIPELINE_EXECUTION_POLICY'}
      ${'pipeline_execution_schedule_policy'} | ${'PIPELINE_EXECUTION_SCHEDULE_POLICY'}
      ${'vulnerability_management_policy'}    | ${'VULNERABILITY_MANAGEMENT_POLICY'}
      ${undefined}                            | ${null}
    `('returns $expected for type $type', ({ type, expected }) => {
      factory({
        propsData: { policy: { ...mockProjectScanExecutionPolicy, type } },
      });
      expect(wrapper.vm.policyTypeEnum).toBe(expected);
    });
  });

  describe('enrichedPolicy passed to policy component', () => {
    const mockPolicyScope = { complianceFrameworks: { nodes: [] } };

    const mountWithApollo = ({ policy, policyType, detailsNode }) => {
      Vue.use(VueApollo);
      const handler = jest.fn().mockResolvedValue({
        data: {
          namespace: {
            id: 'gid://gitlab/Project/1',
            securityPolicies: { nodes: [detailsNode] },
          },
        },
      });
      factory({
        propsData: { policy, policyType },
        apolloProvider: createMockApollo([[projectSecurityPolicyDetailsQuery, handler]]),
      });
    };

    it('passes the original policy when the query is skipped (scan execution)', () => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicy,
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value,
        },
      });

      expect(wrapper.findComponent(ScanExecutionDrawer).props('policy')).toEqual(
        mockProjectScanExecutionPolicy,
      );
    });

    it('passes actionApprovers for approval policies, not policyBlobFilePath', async () => {
      const actionApprovers = [{ roles: ['OWNER'], users: [], allGroups: [], customRoles: [] }];
      const policy = { ...mockProjectScanResultPolicy, type: APPROVAL_POLICY_TYPE };

      mountWithApollo({
        policy,
        policyType: POLICY_TYPE_COMPONENT_OPTIONS.approval.value,
        detailsNode: {
          id: mockProjectScanResultPolicy.id,
          name: mockProjectScanResultPolicy.name,
          policyScope: mockPolicyScope,
          policyAttributes: { __typename: 'ApprovalPolicyAttributesType', actionApprovers },
        },
      });

      await waitForPromises();

      const receivedPolicy = wrapper.findComponent(ScanResultDrawer).props('policy');
      expect(receivedPolicy.actionApprovers).toEqual(actionApprovers);
      expect(receivedPolicy).not.toHaveProperty('policyBlobFilePath');
    });

    it('passes policyBlobFilePath for pipeline execution policies, not actionApprovers', async () => {
      const policyBlobFilePath = '/new/path.yml';
      const policy = {
        ...mockProjectPipelineExecutionPolicy,
        type: PIPELINE_EXECUTION_POLICY_TYPE,
      };

      mountWithApollo({
        policy,
        policyType: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value,
        detailsNode: {
          id: mockProjectPipelineExecutionPolicy.id,
          name: mockProjectPipelineExecutionPolicy.name,
          policyScope: mockPolicyScope,
          policyAttributes: {
            __typename: 'PipelineExecutionPolicyAttributesType',
            policyBlobFilePath,
          },
        },
      });

      await waitForPromises();

      const receivedPolicy = wrapper.findComponent(PipelineExecutionDrawer).props('policy');
      expect(receivedPolicy.policyBlobFilePath).toBe(policyBlobFilePath);
      expect(receivedPolicy).not.toHaveProperty('actionApprovers');
    });

    it('passes policyBlobFilePath for pipeline execution schedule policies', async () => {
      const policyBlobFilePath = '/schedule/path.yml';
      const policy = {
        ...mockProjectPipelineExecutionPolicy,
        type: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
      };

      mountWithApollo({
        policy,
        policyType: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.value,
        detailsNode: {
          id: mockProjectPipelineExecutionPolicy.id,
          name: mockProjectPipelineExecutionPolicy.name,
          policyScope: mockPolicyScope,
          policyAttributes: {
            __typename: 'PipelineExecutionScheduledPolicyAttributesType',
            policyBlobFilePath,
          },
        },
      });

      await waitForPromises();

      expect(
        wrapper.findComponent(PipelineExecutionDrawer).props('policy').policyBlobFilePath,
      ).toBe(policyBlobFilePath);
    });

    describe('merging the list-query scope with the details-query scope', () => {
      // Attribute scopes are loaded by the list query but absent from the
      // PolicyScopeDrawer fragment, so they live only on the list-query policy.
      const includingBusinessImpactAttributes = { count: 1, nodes: [{ id: 'gid://gitlab/A/1' }] };

      // A complete PolicyScopeDrawer-shaped scope so Apollo can satisfy the
      // fragment's selection set and round-trip it back to the component.
      const drawerScope = {
        // __typename is required for Apollo to satisfy the `on PolicyScope`
        // fragment type condition and read the fields back.
        __typename: 'PolicyScope',
        complianceFrameworks: { nodes: [] },
        excludingPersonalProjects: true,
        excludingProjects: { nodes: [] },
        includingProjects: { nodes: [] },
        includingGroups: { nodes: [] },
      };

      const mountApprovalPolicyWithScope = (listScope) =>
        mountWithApollo({
          policy: {
            ...mockProjectScanResultPolicy,
            type: APPROVAL_POLICY_TYPE,
            policyScope: listScope,
          },
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.approval.value,
          detailsNode: {
            id: mockProjectScanResultPolicy.id,
            name: mockProjectScanResultPolicy.name,
            policyScope: drawerScope,
            policyAttributes: { __typename: 'ApprovalPolicyAttributesType', actionApprovers: [] },
          },
        });

      it('preserves attribute scopes that exist only on the list-query scope', async () => {
        mountApprovalPolicyWithScope({
          includingBusinessImpactAttributes,
          excludingPersonalProjects: false,
        });

        await waitForPromises();

        // Without the merge, the attribute-less details scope would clobber this
        // (the bug this fix addresses).
        expect(
          wrapper.findComponent(ScanResultDrawer).props('policy').policyScope
            .includingBusinessImpactAttributes,
        ).toEqual(includingBusinessImpactAttributes);
      });

      it('lets details-query scope fields win on conflict', async () => {
        mountApprovalPolicyWithScope({
          includingBusinessImpactAttributes,
          excludingPersonalProjects: false,
        });

        await waitForPromises();

        // List scope had excludingPersonalProjects: false; the richer drawer scope wins.
        expect(
          wrapper.findComponent(ScanResultDrawer).props('policy').policyScope
            .excludingPersonalProjects,
        ).toBe(true);
      });
    });
  });

  describe('given a dependencyFirewall policy', () => {
    it('renders DependencyFirewallDrawer', () => {
      factory({
        propsData: {
          policy: mockEnforcedDfwPolicy,
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.dependencyFirewall.value,
        },
        stubs: { GlDrawer, GlTabs },
      });

      expect(findDependencyFirewallDrawer().exists()).toBe(true);
    });
  });

  describe('given a non-pipelineExecutionSchedule policy', () => {
    it.each`
      policyType                                                     | policy
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}           | ${mockProjectScanExecutionPolicyWithWrapper}
      ${POLICY_TYPE_COMPONENT_OPTIONS.approval.value}                | ${mockProjectScanResultPolicy}
      ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value}       | ${mockProjectPipelineExecutionPolicy}
      ${POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value} | ${mockProjectVulnerabilityManagementPolicy}
    `('does not render the test runs tab for $policyType policy', ({ policyType, policy }) => {
      factory({
        propsData: {
          policy,
          policyType,
        },
        stubs: {
          GlDrawer,
          GlTabs,
        },
      });

      expect(findTestRunsTab().exists()).toBe(false);
    });
  });
});
