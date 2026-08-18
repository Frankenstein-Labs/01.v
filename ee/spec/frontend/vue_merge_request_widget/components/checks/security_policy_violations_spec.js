import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import SecurityPolicyViolations from 'ee/vue_merge_request_widget/components/checks/security_policy_violations.vue';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import SecurityPolicyBypassStatusesModal from 'ee/vue_merge_request_widget/components/checks/security_policy_bypass_statuses_modal.vue';
import SecurityPolicyViolationsSelector from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_selector.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import getPolicyViolations from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';
import { EXCEPTION_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';
import {
  mockEnforcedSecurityPolicyViolation,
  mockWarnSecurityPolicyViolation,
} from '../../mock_data';

Vue.use(VueApollo);

describe('SecurityPolicyViolations merge checks component', () => {
  let wrapper;
  const policiesPath = '/security-path';
  let resolver;

  const defaultPolicies = [
    mockEnforcedSecurityPolicyViolation,
    mockWarnSecurityPolicyViolation,
    mockWarnSecurityPolicyViolation,
  ];

  const getApolloProvider = (policies, allowBypass = false, bypassed = false) => {
    resolver = jest.fn().mockResolvedValue({
      data: {
        project: {
          id: 'gid://gitlab/Project/25',
          mergeRequest: {
            id: 'gid://gitlab/MergeRequest/598',
            targetBranch: 'main',
            sourceBranch: 'root-main-patch-82768',
            headPipeline: {
              id: 'gid://gitlab/Ci::Pipeline/101891',
              iid: '19776',
              updatedAt: '2025-08-20T22:13:19Z',
              path: '/gitlab-org/security-reports/-/pipelines/101891',
              __typename: 'Pipeline',
            },
            policyBypassStatuses: [
              {
                allowBypass,
                bypassed,
                id: '2',
                name: 'Prevent Critical Vulnerabilities',
              },
            ],
            policyViolations: {
              comparisonPipelines: [],
              anyMergeRequest: [],
              licenseScanning: [],
              newScanFinding: [],
              policies,
              previousScanFinding: [],
              __typename: 'PolicyViolationDetails',
            },
            __typename: 'MergeRequest',
          },
          __typename: 'Project',
        },
      },
    });

    return createMockApollo(
      [[getPolicyViolations, resolver]],
      {},
      { typePolicies: { Query: { fields: { project: { merge: false } } } } },
    );
  };

  function createComponent({
    allowBypass = false,
    bypassed = false,
    status = 'SUCCESS',
    securityPoliciesPath = null,
    policies = defaultPolicies,
  } = {}) {
    wrapper = mountExtended(SecurityPolicyViolations, {
      apolloProvider: getApolloProvider(policies, allowBypass, bypassed),
      propsData: {
        mr: {
          securityPoliciesPath,
          iid: 123,
          targetProjectFullPath: 'group/project',
        },
        check: {
          identifier: 'security_policy_violations',
          status,
        },
      },
      stubs: { ActionButtons },
    });
  }

  const findActionLink = () => wrapper.findByTestId('view-policies-button');
  const findBypassButton = () => wrapper.findComponentByTestId('bypass-button');
  const findIcon = () => wrapper.findByTestId('security-policy-help-icon');
  const findWarnModeModal = () => wrapper.findComponent(SecurityPolicyViolationsModal);
  const findBypassStatusesModal = () => wrapper.findComponent(SecurityPolicyBypassStatusesModal);
  const findSecurityPolicyViolationsSelector = () =>
    wrapper.findComponent(SecurityPolicyViolationsSelector);
  const findPopover = () => wrapper.findByTestId('security-policy-help-popover');
  const findViewPoliciesLink = () => wrapper.find('[href="/security-path"]');

  describe('action buttons', () => {
    it.each`
      status        | path            | exists   | rendersText
      ${'SUCCESS'}  | ${policiesPath} | ${true}  | ${'renders'}
      ${'SUCCESS'}  | ${''}           | ${false} | ${'does not render'}
      ${'SUCCESS'}  | ${null}         | ${false} | ${'does not render'}
      ${'FAILED'}   | ${policiesPath} | ${true}  | ${'renders'}
      ${'FAILED'}   | ${''}           | ${false} | ${'does not render'}
      ${'FAILED'}   | ${null}         | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${policiesPath} | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${''}           | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${null}         | ${false} | ${'does not render'}
    `(
      '$rendersText link to security policies when status is $status',
      ({ status, path, exists }) => {
        createComponent({ status, securityPoliciesPath: path });

        expect(findActionLink().exists()).toBe(exists);

        if (exists) {
          expect(findActionLink().attributes('href')).toBe(path);
        }
      },
    );

    it('renders View policies link when securityPoliciesPath is provided', () => {
      createComponent({ securityPoliciesPath: policiesPath });

      expect(findViewPoliciesLink().exists()).toBe(true);
      expect(findViewPoliciesLink().attributes('href')).toBe(policiesPath);
      expect(findViewPoliciesLink().text()).toBe('View policies');
    });
  });

  describe('bypass functionality', () => {
    it.each`
      title                                                             | securityPoliciesPath | policies
      ${'there is not a security path and there are no policies'}       | ${''}                | ${[]}
      ${'there is not a security path and there are enforced policies'} | ${''}                | ${[mockEnforcedSecurityPolicyViolation]}
      ${'there is not a security path and there are warn policies'}     | ${''}                | ${[mockWarnSecurityPolicyViolation]}
      ${'there is a security path and there are no policies'}           | ${policiesPath}      | ${[]}
      ${'there is a security path and there are enforced policies'}     | ${policiesPath}      | ${[mockEnforcedSecurityPolicyViolation]}
    `('does not show the bypass button when $title', async ({ securityPoliciesPath, policies }) => {
      createComponent({ securityPoliciesPath, policies });
      await waitForPromises();

      expect(findBypassButton().exists()).toBe(false);
    });

    it.each`
      policiesTitle                                             | policies
      ${'there are warn policies that have not been dismissed'} | ${[mockWarnSecurityPolicyViolation]}
      ${'there are warn policies that have been dismissed'}     | ${[{ ...mockWarnSecurityPolicyViolation, dismissed: true }]}
    `(
      'shows the bypass button when there is a security path and $policiesTitle',
      async ({ warnModeEnabled, policies }) => {
        createComponent({
          warnModeEnabled,
          securityPoliciesPath: policiesPath,
          policies,
        });
        await waitForPromises();

        expect(findBypassButton().exists()).toBe(true);
      },
    );

    it('does not disable the bypass button if all warn policies have been dismissed', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
        policies: [mockWarnSecurityPolicyViolation],
      });
      await waitForPromises();

      expect(findBypassButton().props('disabled')).toBe(false);
    });

    it('disables the bypass button if all warn policies have been dismissed', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
        policies: [{ ...mockWarnSecurityPolicyViolation, dismissed: true }],
      });
      await waitForPromises();

      expect(findBypassButton().props('disabled')).toBe(true);
    });

    it('shows info icon with popover', async () => {
      await createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
      });
      await waitForPromises();

      expect(findIcon().exists()).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });

    it('opens modal when bypass button is clicked', async () => {
      const securityPoliciesPath = policiesPath;
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath,
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');

      expect(findWarnModeModal().exists()).toBe(true);
      expect(findWarnModeModal().props('visible')).toBe(true);

      await findBypassButton().vm.$emit('click');

      expect(findWarnModeModal().exists()).toBe(true);
      expect(findWarnModeModal().props('visible')).toBe(true);

      expect(findWarnModeModal().props()).toEqual(
        expect.objectContaining({
          mr: {
            securityPoliciesPath,
            iid: 123,
            targetProjectFullPath: 'group/project',
          },
          policies: [mockWarnSecurityPolicyViolation],
          visible: true,
        }),
      );
    });

    it('closes modal when close event is emitted', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');
      expect(findWarnModeModal().exists()).toBe(true);
      expect(findWarnModeModal().props('visible')).toBe(true);

      await findWarnModeModal().vm.$emit('close');

      expect(findWarnModeModal().exists()).toBe(false);
    });

    it('does not show bypass button when a user cannot bypass a policy', async () => {
      createComponent({
        allowBypass: false,
        securityPoliciesPath: policiesPath,
        warnModeEnabled: true,
        policies: [mockEnforcedSecurityPolicyViolation],
      });
      await waitForPromises();

      expect(findBypassButton().exists()).toBe(false);
    });

    it('shows and enables the bypass button for bypass statuses', async () => {
      createComponent({
        allowBypass: true,
        securityPoliciesPath: policiesPath,
        warnModeEnabled: true,
        policies: [mockEnforcedSecurityPolicyViolation],
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');

      expect(findBypassStatusesModal().props('policies')).toEqual([
        {
          allowBypass: true,
          bypassed: false,
          id: '2',
          name: 'Prevent Critical Vulnerabilities',
        },
      ]);
      expect(findBypassButton().exists()).toBe(true);
      expect(findBypassButton().props('disabled')).toBe(false);
    });

    it('refetches the policies when policies are bypassed', async () => {
      createComponent({
        allowBypass: true,
        bypassed: true,
        securityPoliciesPath: policiesPath,
        warnModeEnabled: true,
      });
      await waitForPromises();

      expect(resolver).toHaveBeenCalledTimes(1);
      await findBypassButton().vm.$emit('click');
      expect(findWarnModeModal().props('policies')).toEqual([mockWarnSecurityPolicyViolation]);

      await findWarnModeModal().vm.$emit('saved');
      expect(resolver).toHaveBeenCalledTimes(2);
    });

    it('disables bypass button after policies bypassed by user', async () => {
      createComponent({
        securityPoliciesPath: policiesPath,
        allowBypass: true,
        policies: [],
        warnModeEnabled: true,
      });
      await waitForPromises();
      expect(resolver).toHaveBeenCalledTimes(1);
      await findBypassButton().vm.$emit('click');

      expect(findBypassButton().props('disabled')).toBe(false);

      findBypassStatusesModal().vm.$emit('saved');
      await waitForPromises();

      expect(resolver).toHaveBeenCalledTimes(2);
    });

    describe('selector modal', () => {
      it('shows the exception modal when selected from the selector modal', async () => {
        createComponent({
          warnModeEnabled: true,
          securityPoliciesPath: policiesPath,
          allowBypass: true,
        });
        await waitForPromises();

        await findBypassButton().vm.$emit('click');

        expect(findSecurityPolicyViolationsSelector().exists()).toBe(true);

        await findSecurityPolicyViolationsSelector().vm.$emit('select', EXCEPTION_MODE);

        expect(findSecurityPolicyViolationsSelector().exists()).toBe(false);
        expect(findBypassStatusesModal().exists()).toBe(true);
      });

      it.each`
        title                                                                                             | allowException | exceptionPolicyBypassed | policies                                                     | hasSelectorModal | hasExceptionModal | hasWarnModeModal
        ${'shows the selector modal when there are exception policies and warn mode policies'}            | ${true}        | ${false}                | ${defaultPolicies}                                           | ${true}          | ${false}          | ${false}
        ${'shows the exception modal when there are exception policies and no active warn mode policies'} | ${true}        | ${false}                | ${[{ ...mockWarnSecurityPolicyViolation, dismissed: true }]} | ${false}         | ${true}           | ${false}
        ${'shows the warn mode modal when there are no active exception policies and warn mode policies'} | ${true}        | ${true}                 | ${defaultPolicies}                                           | ${false}         | ${false}          | ${true}
      `(
        '$title',
        async ({
          allowException,
          exceptionPolicyBypassed,
          policies,
          hasSelectorModal,
          hasExceptionModal,
          hasWarnModeModal,
        }) => {
          createComponent({
            allowBypass: allowException,
            bypassed: exceptionPolicyBypassed,
            policies,
            securityPoliciesPath: policiesPath,
            warnModeEnabled: true,
          });
          await waitForPromises();
          await findBypassButton().vm.$emit('click');

          expect(findSecurityPolicyViolationsSelector().exists()).toBe(hasSelectorModal);
          expect(findBypassStatusesModal().exists()).toBe(hasExceptionModal);
          expect(findWarnModeModal().exists()).toBe(hasWarnModeModal);
        },
      );
    });
  });
});
