import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable, GlBadge, GlButton, GlSkeletonLoader } from '@gitlab/ui';

import PoliciesSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/policies_section.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import EditSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/edit_section.vue';

import complianceFrameworkPoliciesQuery from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/compliance_frameworks_policies.query.graphql';
import namespacePoliciesQuery from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/namespace_policies.query.graphql';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const pageInfo = (endCursor) => ({
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'MQ',
  endCursor,
  __typename: 'PageInfo',
});

const editPath = (name) => `http://fake-path/edit/${name}`;

const policyAttributesTypename = {
  approval_policy: 'ApprovalPolicyAttributesType',
  scan_execution_policy: 'ScanExecutionPolicyAttributesType',
  pipeline_execution_policy: 'PipelineExecutionPolicyAttributesType',
  pipeline_execution_schedule_policy: 'PipelineExecutionScheduledPolicyAttributesType',
  vulnerability_management_policy: 'VulnerabilityManagementPolicyAttributesType',
};

const makePolicy = ({ name, enabled, description, type }) => ({
  id: null,
  name,
  enabled,
  description,
  type,
  yaml: '',
  editPath: editPath(name),
  updatedAt: Date.now(),
  policyAttributes: {
    __typename: policyAttributesTypename[type],
    source: {
      inherited: false,
      namespace: {
        id: '1',
        fullPath: '',
        name,
      },
    },
  },
});

const makeCompliancePoliciesResponse = () => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/29',
      complianceFrameworks: {
        nodes: [
          {
            id: 'gid://gitlab/ComplianceManagement::Framework/7',
            name: 'ddd',
            securityPolicies: {
              nodes: [
                {
                  id: 'gid://gitlab/Security::ScanResultPolicy/1',
                  name: 'test',
                  type: 'approval_policy',
                  __typename: 'ComplianceFrameworkPolicySummary',
                },
                {
                  id: 'gid://gitlab/Security::ScanExecutionPolicy/1',
                  name: 'testE2',
                  type: 'scan_execution_policy',
                  __typename: 'ComplianceFrameworkPolicySummary',
                },
                {
                  id: 'gid://gitlab/Security::PipelineExecutionPolicy/1',
                  name: 'testPE',
                  type: 'pipeline_execution_policy',
                  __typename: 'ComplianceFrameworkPolicySummary',
                },
                {
                  id: 'gid://gitlab/Security::PipelineExecutionSchedulePolicy/1',
                  name: 'testPES',
                  type: 'pipeline_execution_schedule_policy',
                  __typename: 'ComplianceFrameworkPolicySummary',
                },
                {
                  id: 'gid://gitlab/Security::VulnerabilityManagementPolicy/1',
                  name: 'testVM',
                  type: 'vulnerability_management_policy',
                  __typename: 'ComplianceFrameworkPolicySummary',
                },
              ],
              pageInfo: pageInfo('SP1'),
              __typename: 'ComplianceFrameworkPolicySummaryConnection',
            },
            __typename: 'ComplianceFramework',
          },
        ],
        __typename: 'ComplianceFrameworkConnection',
      },
      __typename: 'Namespace',
    },
  },
});

const makeNamespacePoliciesResponse = () => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/29',
      securityPolicies: {
        nodes: [
          makePolicy({
            name: 'test',
            enabled: false,
            description: 'Test1',
            type: 'approval_policy',
          }),
          makePolicy({
            name: 'test2',
            enabled: true,
            description: 'Test2',
            type: 'approval_policy',
          }),
          makePolicy({
            name: 'testE',
            enabled: false,
            description: 'E1',
            type: 'scan_execution_policy',
          }),
          makePolicy({
            name: 'testE2',
            enabled: true,
            description: 'E2',
            type: 'scan_execution_policy',
          }),
          makePolicy({
            name: 'testPE',
            enabled: true,
            description: 'PE1',
            type: 'pipeline_execution_policy',
          }),
          makePolicy({
            name: 'testPE2',
            enabled: false,
            description: 'PE2',
            type: 'pipeline_execution_policy',
          }),
          makePolicy({
            name: 'testPES',
            enabled: true,
            description: 'PES1',
            type: 'pipeline_execution_schedule_policy',
          }),
          makePolicy({
            name: 'testPES2',
            enabled: false,
            description: 'PES2',
            type: 'pipeline_execution_schedule_policy',
          }),
          makePolicy({
            name: 'testVM',
            enabled: true,
            description: 'VM1',
            type: 'vulnerability_management_policy',
          }),
          makePolicy({
            name: 'testVM2',
            enabled: false,
            description: 'VM2',
            type: 'vulnerability_management_policy',
          }),
        ],
        pageInfo: pageInfo('SP1'),
        __typename: 'SecurityPolicyTypeConnection',
      },
      __typename: 'Namespace',
    },
  },
});

describe('PoliciesSection component', () => {
  let wrapper;
  const findPoliciesTable = () => wrapper.findComponent(GlTable);
  const findDrawer = () => wrapper.findComponent(DrawerWrapper);

  function createComponent({ requestHandlers = [], provide } = {}) {
    wrapper = mountExtended(PoliciesSection, {
      apolloProvider: createMockApollo(requestHandlers),
      provide: {
        disableScanPolicyUpdate: false,
        groupSecurityPoliciesPath: '/group-security-policies',
        ...provide,
      },
      stubs: {
        DrawerWrapper: true,
      },
      propsData: {
        fullPath: 'Commit451',
        graphqlId: 'gid://gitlab/ComplianceManagement::Framework/1',
        count: 5,
      },
    });
  }

  describe('when section is expanded', () => {
    it('shows loading state while fetching', async () => {
      const neverResolve = () =>
        jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
      createComponent({
        requestHandlers: [
          [namespacePoliciesQuery, neverResolve],
          [complianceFrameworkPoliciesQuery, neverResolve],
        ],
      });

      wrapper.findComponent(EditSection).vm.$emit('toggle', true);
      await nextTick();

      const table = findPoliciesTable();
      expect(table.exists()).toBe(true);
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('when multiple pages are present', () => {
    let namespaceLoadHandler;
    let complianceLoadHandler;

    beforeEach(async () => {
      const responseWithNextPages = makeNamespacePoliciesResponse();
      responseWithNextPages.data.namespace.securityPolicies.pageInfo.hasNextPage = true;

      namespaceLoadHandler = jest
        .fn()
        .mockResolvedValueOnce(responseWithNextPages)
        .mockResolvedValueOnce(makeNamespacePoliciesResponse());

      complianceLoadHandler = jest.fn().mockResolvedValueOnce(makeCompliancePoliciesResponse());

      createComponent({
        requestHandlers: [
          [namespacePoliciesQuery, namespaceLoadHandler],
          [complianceFrameworkPoliciesQuery, complianceLoadHandler],
        ],
      });
      await waitForPromises();
      await wrapper.findComponent(EditSection).vm.$emit('toggle', true);
      await waitForPromises();
    });

    it('loads next pages for namespace policies with appropriate cursor if has next pages', () => {
      expect(namespaceLoadHandler).toHaveBeenNthCalledWith(2, {
        after: 'SP1',
        fullPath: 'Commit451',
      });

      expect(complianceLoadHandler).toHaveBeenCalledWith({
        complianceFramework: 'gid://gitlab/ComplianceManagement::Framework/1',
        fullPath: 'Commit451',
        after: null,
      });
    });

    it('correctly stops loading next pages for namespace policies after two calls', () => {
      expect(namespaceLoadHandler).toHaveBeenCalledTimes(2);
    });

    it('correctly loads compliance policies', () => {
      expect(complianceLoadHandler).toHaveBeenCalledWith({
        complianceFramework: 'gid://gitlab/ComplianceManagement::Framework/1',
        fullPath: 'Commit451',
        after: null,
      });
    });
  });

  describe('when loaded', () => {
    beforeEach(async () => {
      createComponent({
        requestHandlers: [
          [namespacePoliciesQuery, jest.fn().mockResolvedValue(makeNamespacePoliciesResponse())],
          [
            complianceFrameworkPoliciesQuery,
            jest.fn().mockResolvedValue(makeCompliancePoliciesResponse()),
          ],
        ],
      });

      wrapper.findComponent(EditSection).vm.$emit('toggle', true);
      await nextTick();
      await waitForPromises();
    });

    it('renders title', () => {
      const title = wrapper.findByText('Policies');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText('Create policies and attach them to this framework.');
      expect(description.exists()).toBe(true);
    });

    it('renders info text with link', () => {
      expect(wrapper.findByTestId('info-text').text()).toContain(
        'Go to the policy management page to scope policies for this framework.',
      );
      expect(wrapper.findByTestId('info-text').find('a').attributes('href')).toBe(
        '/group-security-policies',
      );
    });

    it('correctly calculates policies', () => {
      const policies = findPoliciesTable().props('items');
      expect(policies).toHaveLength(5);
      expect(policies.find((p) => p.name === 'test')).toBeDefined();
      expect(policies.find((p) => p.name === 'testE2')).toBeDefined();
      expect(policies.find((p) => p.name === 'testPE')).toBeDefined();
      expect(policies.find((p) => p.name === 'testPES')).toBeDefined();
      expect(policies.find((p) => p.name === 'testVM')).toBeDefined();
    });

    it('displays disabled badge for disabled policy', () => {
      const disabledBadges = wrapper
        .findAllComponents(GlBadge)
        .wrappers.filter((badge) => badge.text() === 'Disabled');
      expect(disabledBadges).toHaveLength(1);
      const disabledPolicyNames = disabledBadges.map((badgeWrapper) =>
        badgeWrapper.element.closest('tr').querySelector('td span').textContent.trim(),
      );
      expect(disabledPolicyNames).toEqual(['test']);
    });

    it('renders buttons to view policy details', async () => {
      const policies = findPoliciesTable().props('items');
      const policyButtons = findPoliciesTable().findAllComponents(GlButton);
      expect(policyButtons).toHaveLength(policies.length);
      await policyButtons.at(0).trigger('click');
      expect(findDrawer().props('policy')).toEqual(policies[0]);
    });

    describe('Drawer', () => {
      it('renders with selected policy', async () => {
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();
        expect(findDrawer().props('policyType')).toBe('approval');
        expect(findDrawer().props('policy').name).toBe('test');
      });

      it('deselects policy when drawer emits close event', async () => {
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();
        expect(findDrawer().props('policy').name).toBe('test');

        findDrawer().vm.$emit('close');
        await nextTick();
        expect(findDrawer().props('policy')).toBeNull();
      });
    });
  });

  describe('CSP framework behavior', () => {
    describe('when framework is inherited', () => {
      beforeEach(async () => {
        createComponent({
          requestHandlers: [
            [namespacePoliciesQuery, jest.fn().mockResolvedValue(makeNamespacePoliciesResponse())],
            [
              complianceFrameworkPoliciesQuery,
              jest.fn().mockResolvedValue(makeCompliancePoliciesResponse()),
            ],
          ],
        });

        await wrapper.setProps({ isInherited: true });
        wrapper.findComponent(EditSection).vm.$emit('toggle', true);
        await nextTick();
        await waitForPromises();
      });

      it('hides the view details buttons', () => {
        const policyButtons = findPoliciesTable().findAllComponents(GlButton);
        expect(policyButtons).toHaveLength(0);
      });

      it('hides the drawer', () => {
        expect(findDrawer().exists()).toBe(false);
      });

      it('does not open drawer when row is clicked', async () => {
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();

        expect(findDrawer().exists()).toBe(false);
      });
    });

    describe('when framework is not inherited', () => {
      beforeEach(async () => {
        createComponent({
          requestHandlers: [
            [namespacePoliciesQuery, jest.fn().mockResolvedValue(makeNamespacePoliciesResponse())],
            [
              complianceFrameworkPoliciesQuery,
              jest.fn().mockResolvedValue(makeCompliancePoliciesResponse()),
            ],
          ],
        });

        await wrapper.setProps({ isInherited: false });
        wrapper.findComponent(EditSection).vm.$emit('toggle', true);
        await nextTick();
        await waitForPromises();
      });

      it('shows the view details buttons', () => {
        const policyButtons = findPoliciesTable().findAllComponents(GlButton);
        expect(policyButtons.length).toBeGreaterThan(0);
      });

      it('shows the drawer', () => {
        expect(findDrawer().exists()).toBe(true);
      });

      it('opens drawer when row is clicked', async () => {
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();

        expect(findDrawer().props('policy')).not.toBeNull();
        expect(findDrawer().props('policy').name).toBe('test');
      });
    });
  });
});
