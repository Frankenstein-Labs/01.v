import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlockersPage from 'ee/merge_requests/reports/pages/blockers_page.vue';
import SecurityListItem from 'ee/merge_requests/reports/components/security_list_item.vue';
import PolicyDrawer from 'ee/merge_requests/reports/components/policy_drawer.vue';
import FindingDrawer from 'ee/merge_requests/reports/components/finding_drawer.vue';
import projectPoliciesQuery from 'ee/merge_requests/reports/queries/project_policies.query.graphql';
import policyViolationsQuery from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';

Vue.use(VueApollo);

const createMockApprovalPolicy = (data = {}) => {
  return {
    id: 'gid://gitlab/Security::ApprovalPolicy/1',
    enabled: true,
    name: 'policy name',
    description: '',
    yaml: '',
    actionApprovers: [
      {
        allGroups: [],
        roles: [],
        users: [],
      },
    ],
    source: {
      namespace: {
        name: 'Project',
        webUrl: '/namespace/project',
      },
    },
    ...data,
  };
};

const mockAnyMergeRequestPolicyViolation = {
  dismissed: false,
  enforcementType: 'ENFORCE',
  name: 'policy',
  reportType: 'ANY_MERGE_REQUEST',
  securityPolicyId: 1,
  status: 'failed',
};

describe('Merge request reports blockers page component', () => {
  let wrapper;

  const findSecurityListItems = () => wrapper.findAllComponents(SecurityListItem);
  const findPolicyDrawer = () => wrapper.findComponent(PolicyDrawer);
  const findFindingDrawer = () => wrapper.findComponent(FindingDrawer);

  const createComponent = ({ policyViolations = null, approvalPolicies = [] } = {}) => {
    const apolloProvider = createMockApollo(
      [
        [
          projectPoliciesQuery,
          jest.fn().mockResolvedValue({
            data: { project: { id: 1, approvalPolicies: { nodes: approvalPolicies } } },
          }),
        ],
        [
          policyViolationsQuery,
          jest.fn().mockResolvedValue({
            data: {
              project: {
                id: 1,
                mergeRequest: {
                  id: 1,
                  targetBranch: 'main',
                  sourceBranch: 'feature',
                  headPipeline: null,
                  policyViolations,
                  policyBypassStatuses: [
                    {
                      allowBypass: false,
                      bypassed: false,
                      id: '2',
                      name: 'Prevent Critical Vulnerabilities',
                    },
                  ],
                },
              },
            },
          }),
        ],
      ],
      {},
      { typePolicies: { Query: { fields: { project: { merge: false } } } } },
    );
    wrapper = shallowMountExtended(BlockersPage, {
      apolloProvider,
      provide: { projectPath: 'gitlab-org/gitlab', iid: '2' },
    });
  };

  it('shows loading icon', () => {
    createComponent();

    expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
  });

  describe('has policies', () => {
    describe('has no enabled policies', () => {
      it('does not render any security list items', async () => {
        createComponent({
          approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: false })],
        });

        await waitForPromises();

        expect(findSecurityListItems()).toHaveLength(0);
      });
    });

    describe('has policies', () => {
      it('renders security list items', async () => {
        createComponent({
          approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
        });

        await waitForPromises();

        expect(findSecurityListItems()).toHaveLength(1);
        expect(findSecurityListItems().at(0).props('status')).toBe('success');
      });

      it('renders security list items with failed findings for SCAN_FINDING report', async () => {
        createComponent({
          approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
          policyViolations: {
            anyMergeRequest: [],
            licenseScanning: [],
            comparisonPipelines: [],
            newScanFinding: [
              {
                location: 'location',
                name: 'name',
                path: 'path',
                reportType: 'reportType',
                severity: 'secerity',
              },
            ],
            policies: [{ ...mockAnyMergeRequestPolicyViolation, reportType: 'SCAN_FINDING' }],
            previousScanFinding: [],
          },
        });

        await waitForPromises();

        expect(findSecurityListItems().at(0).props('status')).toBe('failed');
        expect(findSecurityListItems().at(0).props('findings')).toEqual([
          {
            location: 'location',
            name: 'name',
            path: 'path',
            reportType: 'reportType',
            severity: 'secerity',
          },
        ]);
      });

      it('renders security list items with failed findings for ANY_MERGE_REQUEST report', async () => {
        createComponent({
          approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
          policyViolations: {
            anyMergeRequest: [{ commits: 'commits', name: 'name' }],
            licenseScanning: [],
            newScanFinding: [],
            policies: [mockAnyMergeRequestPolicyViolation],
            previousScanFinding: [],
            comparisonPipelines: [],
          },
        });

        await waitForPromises();

        expect(findSecurityListItems().at(0).props('findings')).toEqual([
          { commits: 'commits', name: 'name' },
        ]);
      });
    });
  });

  describe('policy drawer', () => {
    it('opens drawer with open-drawer event', async () => {
      createComponent({
        approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
        policyViolations: {
          anyMergeRequest: [{ commits: 'commits', name: 'name' }],
          licenseScanning: [],
          newScanFinding: [],
          policies: [mockAnyMergeRequestPolicyViolation],
          previousScanFinding: [],
          comparisonPipelines: [],
        },
      });

      await waitForPromises();

      findSecurityListItems().at(0).vm.$emit('open-drawer', 'policy');

      await waitForPromises();

      expect(findPolicyDrawer().props()).toMatchObject({
        open: true,
        policy: { name: 'policy', enabled: true },
        comparisonPipelines: null,
        targetBranch: 'main',
        sourceBranch: 'feature',
      });
    });
  });

  describe('when selecting a finding', () => {
    it('opens finding drawer', async () => {
      createComponent({
        approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
        policyViolations: {
          anyMergeRequest: [{ commits: 'commits', name: 'name' }],
          licenseScanning: [],
          newScanFinding: [],
          policies: [mockAnyMergeRequestPolicyViolation],
          previousScanFinding: [],
          comparisonPipelines: [],
        },
      });

      await waitForPromises();

      findSecurityListItems().at(0).vm.$emit('open-finding', { name: 'policy' });

      await waitForPromises();

      expect(findFindingDrawer().props()).toMatchObject({
        open: true,
      });
    });

    it('closes finding drawer from close event on drawer', async () => {
      createComponent({
        approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
        policyViolations: {
          anyMergeRequest: [{ commits: 'commits', name: 'name' }],
          licenseScanning: [],
          newScanFinding: [],
          policies: [mockAnyMergeRequestPolicyViolation],
          previousScanFinding: [],
          comparisonPipelines: [],
        },
      });

      await waitForPromises();

      findSecurityListItems().at(0).vm.$emit('open-finding', { name: 'policy' });

      findFindingDrawer().vm.$emit('close');

      await waitForPromises();

      expect(findFindingDrawer().props()).toMatchObject({
        open: false,
      });
    });

    it('sets selected finding on security list item', async () => {
      createComponent({
        approvalPolicies: [createMockApprovalPolicy({ name: 'policy', enabled: true })],
        policyViolations: {
          anyMergeRequest: [{ commits: 'commits', name: 'name' }],
          licenseScanning: [],
          newScanFinding: [],
          policies: [mockAnyMergeRequestPolicyViolation],
          previousScanFinding: [],
          comparisonPipelines: [],
        },
      });

      await waitForPromises();

      findSecurityListItems().at(0).vm.$emit('open-finding', { name: 'policy' });

      await waitForPromises();

      expect(findSecurityListItems().at(0).props('selectedFinding')).toMatchObject({
        name: 'policy',
      });
    });
  });
});
