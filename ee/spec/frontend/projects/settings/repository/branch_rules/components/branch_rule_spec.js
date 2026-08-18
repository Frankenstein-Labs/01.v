import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchRule from 'ee/projects/settings/repository/branch_rules/components/branch_rule.vue';
import PolicyBadge from '~/projects/settings/repository/branch_rules/components/policy_badge.vue';
import DisabledByPolicyPopover from '~/projects/settings/branch_rules/components/disabled_by_policy_popover.vue';
import {
  accessLevelsMockResponse,
  accessLevelsWithDeployKeyMockResponse,
  accessLevelsWithMemberRoleMockResponse,
  branchRuleProvideMock,
  branchRulePropsMock,
} from '../mock_data';

describe('Branch rule', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(BranchRule, {
      provide: { ...branchRuleProvideMock, ...provide },
      propsData: { ...branchRulePropsMock, ...props },
    });
  };

  const findProtectionDetailsListItems = () => wrapper.findAllByRole('listitem');
  const findCodeOwners = () => wrapper.findByText('Requires CODEOWNERS approval');
  const findStatusChecks = () => wrapper.findByText('2 status checks');
  const findApprovalRules = () => wrapper.findByText('1 approval rule');
  const findPolicyBadge = () => wrapper.findComponent(PolicyBadge);
  const findDisabledByPolicyPopover = () => wrapper.findComponent(DisabledByPolicyPopover);
  const findAllDisabledByPolicyPopovers = () => wrapper.findAllComponents(DisabledByPolicyPopover);

  beforeEach(() => createComponent());

  it.each`
    showCodeOwners | showStatusChecks | showApprovers
    ${true}        | ${true}          | ${true}
    ${false}       | ${false}         | ${false}
  `(
    'conditionally renders code owners, status checks, and approval rules',
    ({ showCodeOwners, showStatusChecks, showApprovers }) => {
      createComponent({ provide: { showCodeOwners, showStatusChecks, showApprovers } });

      expect(findCodeOwners().exists()).toBe(showCodeOwners);
      expect(findStatusChecks().exists()).toBe(showStatusChecks);
      expect(findApprovalRules().exists()).toBe(showApprovers);
    },
  );

  it('renders the protection details list items', () => {
    expect(findProtectionDetailsListItems()).toHaveLength(wrapper.vm.approvalDetails.length);
    expect(findProtectionDetailsListItems().at(0).text()).toBe('Allowed to force push');
    expect(findProtectionDetailsListItems().at(1).text()).toBe(wrapper.vm.pushAccessLevelsText);
  });

  it('renders branches count for wildcards', () => {
    createComponent({ props: { name: 'test-*' } });
    expect(findProtectionDetailsListItems().at(0).text()).toBe('1 matching branch');
  });

  describe('policy protection', () => {
    it('does not render disabled by policy popover by default', () => {
      expect(findDisabledByPolicyPopover().exists()).toBe(false);
    });

    it.each`
      protectionProp                             | isProtectedByPolicy | findMethod
      ${'protectedFromPushBySecurityPolicy'}     | ${true}             | ${findPolicyBadge}
      ${'warnProtectedFromPushBySecurityPolicy'} | ${false}            | ${findPolicyBadge}
      ${'modificationBlockedByPolicy'}           | ${true}             | ${findPolicyBadge}
      ${'warnModificationBlockedByPolicy'}       | ${false}            | ${findPolicyBadge}
      ${'protectedFromPushBySecurityPolicy'}     | ${true}             | ${findDisabledByPolicyPopover}
      ${'warnProtectedFromPushBySecurityPolicy'} | ${false}            | ${findDisabledByPolicyPopover}
      ${'modificationBlockedByPolicy'}           | ${true}             | ${findDisabledByPolicyPopover}
      ${'warnModificationBlockedByPolicy'}       | ${false}            | ${findDisabledByPolicyPopover}
    `(
      'renders policy indicator when $protectionProp is true',
      async ({ protectionProp, isProtectedByPolicy, findMethod }) => {
        const branchRuleProps = {
          ...branchRulePropsMock,
          branchProtection: {
            ...branchRulePropsMock.branchProtection,
            [protectionProp]: true,
          },
        };

        await createComponent({ props: branchRuleProps });

        expect(findMethod().exists()).toBe(true);
        expect(findMethod().props('isProtectedByPolicy')).toBe(isProtectedByPolicy);
      },
    );

    it('shows enforced badge when both push and modification policies are active', async () => {
      const branchRuleProps = {
        ...branchRulePropsMock,
        branchProtection: {
          ...branchRulePropsMock.branchProtection,
          protectedFromPushBySecurityPolicy: true,
          modificationBlockedByPolicy: true,
        },
      };

      await createComponent({ props: branchRuleProps });

      expect(findPolicyBadge().exists()).toBe(true);
      expect(findPolicyBadge().props('isProtectedByPolicy')).toBe(true);
    });

    it('shows enforced badge when warn modification policy and enforced push policy are both active', async () => {
      const branchRuleProps = {
        ...branchRulePropsMock,
        branchProtection: {
          ...branchRulePropsMock.branchProtection,
          protectedFromPushBySecurityPolicy: true,
          warnModificationBlockedByPolicy: true,
        },
      };

      await createComponent({ props: branchRuleProps });

      expect(findPolicyBadge().exists()).toBe(true);
      expect(findPolicyBadge().props('isProtectedByPolicy')).toBe(true);
    });

    it.each`
      protectionProp
      ${'protectedFromPushBySecurityPolicy'}
      ${'modificationBlockedByPolicy'}
    `(
      'applies disabled text styling for push access levels when $protectionProp is true',
      async ({ protectionProp }) => {
        const branchRuleProps = {
          ...branchRulePropsMock,
          branchProtection: {
            ...branchRulePropsMock.branchProtection,
            [protectionProp]: true,
          },
        };

        await createComponent({ props: branchRuleProps });

        const pushAccessItem = findProtectionDetailsListItems().at(1);

        expect(pushAccessItem.find('.gl-text-disabled').exists()).toBe(true);
      },
    );

    describe('when modificationBlockedByPolicy is true with merge access levels', () => {
      const mergeAccessLevelEdges = [
        {
          __typename: 'MergeAccessLevelEdge',
          node: {
            __typename: 'MergeAccessLevel',
            accessLevel: 40,
            accessLevelDescription: 'Maintainers',
            group: null,
            user: null,
          },
        },
      ];

      const propsWithMergeAccess = {
        ...branchRulePropsMock,
        branchProtection: {
          ...branchRulePropsMock.branchProtection,
          modificationBlockedByPolicy: true,
          mergeAccessLevels: { edges: mergeAccessLevelEdges },
        },
      };

      it('applies disabled text styling for merge access levels', async () => {
        await createComponent({ props: propsWithMergeAccess });

        const mergeAccessItem = findProtectionDetailsListItems().wrappers.find((w) =>
          w.text().includes('Allowed to merge'),
        );

        expect(mergeAccessItem.find('.gl-text-disabled').exists()).toBe(true);
      });

      it('shows popover on both push and merge access items', async () => {
        await createComponent({ props: propsWithMergeAccess });

        expect(findAllDisabledByPolicyPopovers()).toHaveLength(2);
      });
    });

    it('does not show popovers on non-push/non-merge items like force push or code owners', async () => {
      const branchRuleProps = {
        ...branchRulePropsMock,
        branchProtection: {
          ...branchRulePropsMock.branchProtection,
          modificationBlockedByPolicy: true,
        },
      };

      await createComponent({
        props: branchRuleProps,
        provide: { showCodeOwners: true },
      });

      // Only push access levels text should have a popover (1 item),
      // not "Allowed to force push" or "Requires CODEOWNERS approval"
      expect(findAllDisabledByPolicyPopovers()).toHaveLength(1);
    });

    it('does not apply disabled text styling for merge access levels when only protectedFromPushBySecurityPolicy is true', async () => {
      const branchRuleProps = {
        ...branchRulePropsMock,
        branchProtection: {
          ...branchRulePropsMock.branchProtection,
          protectedFromPushBySecurityPolicy: true,
          mergeAccessLevels: { edges: accessLevelsMockResponse },
        },
      };

      await createComponent({ props: branchRuleProps });

      const mergeAccessItem = findProtectionDetailsListItems().wrappers.find((w) =>
        w.text().includes('Allowed to merge'),
      );

      expect(mergeAccessItem.find('.gl-text-disabled').exists()).toBe(false);
    });
  });

  describe('access levels rendering', () => {
    it('does not render access levels text when both are empty', async () => {
      await createComponent({
        props: {
          branchProtection: {
            mergeAccessLevels: { edges: [] },
            pushAccessLevels: { edges: [] },
          },
        },
      });

      const detailsItems = findProtectionDetailsListItems();
      const detailsText = detailsItems.wrappers.map((item) => item.text()).join(' ');

      expect(detailsText).not.toContain('Allowed to merge:');
      expect(detailsText).not.toContain('Allowed to push and merge:');
    });

    it('renders merge access levels text with roles, groups, users, and deploy keys', async () => {
      await createComponent({
        props: {
          branchProtection: {
            mergeAccessLevels: {
              edges: [
                { node: { accessLevel: 40 } },
                { node: { accessLevel: 40, group: { id: '1' } } },
                { node: { accessLevel: 40, group: { id: '2' } } },
                { node: { accessLevel: 40, user: { id: '3' } } },
                { node: { accessLevel: 40, deployKey: { id: '4', title: 'Key' } } },
              ],
            },
          },
        },
      });

      const detailsText = findProtectionDetailsListItems().wrappers.map((item) => item.text());

      expect(detailsText).toContain(
        'Allowed to merge: Maintainers, 2 groups, 1 user, 1 deploy key',
      );
    });

    it('renders push access levels with deploy key instead of Maintainers', async () => {
      await createComponent({
        props: {
          branchProtection: {
            ...branchRulePropsMock.branchProtection,
            pushAccessLevels: {
              edges: accessLevelsWithDeployKeyMockResponse,
            },
          },
        },
      });

      const detailsText = findProtectionDetailsListItems().wrappers.map((item) => item.text());

      expect(detailsText).toContain('Allowed to push and merge: No one, 1 deploy key');
    });

    it('renders push access levels text with roles, groups, users, and deploy keys', async () => {
      await createComponent({
        props: {
          branchProtection: {
            pushAccessLevels: {
              edges: [
                { node: { accessLevel: 40 } },
                { node: { accessLevel: 40, group: { id: '1' } } },
                { node: { accessLevel: 40, user: { id: '2' } } },
                { node: { accessLevel: 40, deployKey: { id: '3', title: 'Key 1' } } },
                { node: { accessLevel: 40, deployKey: { id: '4', title: 'Key 2' } } },
              ],
            },
          },
        },
      });

      const detailsText = findProtectionDetailsListItems().wrappers.map((item) => item.text());

      expect(detailsText).toContain(
        'Allowed to push and merge: Maintainers, 1 group, 1 user, 2 deploy keys',
      );
    });

    it.each`
      accessLevelsKey        | label
      ${'mergeAccessLevels'} | ${'Allowed to merge'}
      ${'pushAccessLevels'}  | ${'Allowed to push and merge'}
    `('renders custom roles by name in $accessLevelsKey', async ({ accessLevelsKey, label }) => {
      await createComponent({
        props: {
          branchProtection: {
            [accessLevelsKey]: { edges: accessLevelsWithMemberRoleMockResponse },
          },
        },
      });

      const detailsText = findProtectionDetailsListItems().wrappers.map((item) => item.text());

      expect(detailsText).toContain(`${label}: Custom Developer`);
      expect(detailsText).not.toContain(`${label}: Developers`);
    });
  });
});
