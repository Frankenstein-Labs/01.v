import { GlEmptyState, GlPopover, GlSprintf } from '@gitlab/ui';
import { cloneDeep } from 'lodash-es';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import RuleView from 'ee/projects/settings/branch_rules/components/index.vue';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import ProjectRules from 'ee/approvals/project_settings/project_rules.vue';
import StatusChecks from 'ee/projects/settings/branch_rules/components/status_checks/status_checks.vue';
import branchRulesQuery from 'ee/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import squashOptionQuery from '~/projects/settings/branch_rules/queries/squash_option.query.graphql';
import * as urlUtility from '~/lib/utils/url_utility';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';
import ProtectionToggle from '~/projects/settings/branch_rules/components/protection_toggle.vue';
import Protection from '~/projects/settings/branch_rules/components/protection.vue';
import ProtectionRow from '~/projects/settings/branch_rules/components/protection_row.vue';
import AccessLevelsDrawer from 'ee_else_ce/projects/settings/branch_rules/components/access_levels_drawer.vue';
import AccessLevelsDrawerCe from '~/projects/settings/branch_rules/components/access_levels_drawer.vue';
import deleteBranchRuleMutation from '~/projects/settings/branch_rules/mutations/branch_rule_delete.mutation.graphql';
import editBranchRuleMutation from 'ee_else_ce/projects/settings/branch_rules/mutations/edit_branch_rule.mutation.graphql';
import getProtectableBranches from '~/projects/settings/graphql/queries/protectable_branches.query.graphql';
import editBranchRuleSquashOptionMutation from '~/projects/settings/branch_rules/mutations/edit_squash_option.mutation.graphql';
import deleteBranchRuleSquashOptionMutation from '~/projects/settings/branch_rules/mutations/delete_squash_option.mutation.graphql';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { createAlert } from '~/alert';
import {
  deleteBranchRuleMockResponse,
  branchProtectionsMockResponse,
  squashOptionMockResponse,
  protectionPropsMock,
  editBranchRuleMockResponse,
  predefinedBranchRulesMockResponse,
  editSquashOptionMockResponse,
  deleteSquashOptionMockResponse,
  protectableBranchesMockResponse,
} from './mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  getParameterByName: jest.fn().mockReturnValue('main'),
  mergeUrlParams: jest.fn().mockReturnValue('/branches?state=all&search=main'),
  joinPaths: jest.fn(),
  setUrlFragment: jest.fn(),
}));

jest.mock('~/alert');

Vue.use(VueApollo);
Vue.use(Vuex);

describe('View branch rules in enterprise edition', () => {
  let wrapper;
  let fakeApollo;
  let store;
  let axiosMock;
  const projectPath = 'test/testing';
  const protectedBranchesPath = 'protected/branches';
  const securityPoliciesPath = 'path/to/-/security/policies';
  const groupSettingsRepositoryPath = '/groups/test/-/settings/repository';
  const branchProtectionsMockRequestHandler = (response = branchProtectionsMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const squashOptionMockRequestHandler = (response = squashOptionMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const deleteBranchRuleMockRequestHandler = (response = deleteBranchRuleMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const editBranchRuleSuccessHandler = jest.fn().mockResolvedValue(editBranchRuleMockResponse);
  const editSquashOptionSuccessHandler = jest.fn().mockResolvedValue(editSquashOptionMockResponse);
  const deleteSquashOptionSuccessHandler = jest
    .fn()
    .mockResolvedValue(deleteSquashOptionMockResponse);
  const protectableBranchesMockRequestHandler = jest
    .fn()
    .mockResolvedValue(protectableBranchesMockResponse);
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = async (
    {
      showApprovers,
      showStatusChecks,
      showCodeOwners,
      canAdminGroupProtectedBranches = false,
      canReadSquashOption = true,
      canUpdateSquashOption = true,
    } = {},
    mockResponse,
    mutationMockResponse,
  ) => {
    axiosMock = new MockAdapter(axios);
    store = createStoreOptions({ approvals: projectSettingsModule() });
    jest.spyOn(store.modules.approvals.actions, 'setRulesFilter');
    jest.spyOn(store.modules.approvals.actions, 'fetchRules');

    fakeApollo = createMockApollo([
      [branchRulesQuery, branchProtectionsMockRequestHandler(mockResponse)],
      [squashOptionQuery, squashOptionMockRequestHandler(mutationMockResponse)],
      [getProtectableBranches, protectableBranchesMockRequestHandler],
      [deleteBranchRuleMutation, deleteBranchRuleMockRequestHandler(mutationMockResponse)],
      [editBranchRuleMutation, editBranchRuleSuccessHandler],
      [editBranchRuleSquashOptionMutation, editSquashOptionSuccessHandler],
      [deleteBranchRuleSquashOptionMutation, deleteSquashOptionSuccessHandler],
    ]);

    wrapper = mountExtended(RuleView, {
      store: new Vuex.Store(store),
      apolloProvider: fakeApollo,
      provide: {
        canAdminGroupProtectedBranches,
        canAdminProtectedBranches: true,
        canReadSquashOption,
        canUpdateSquashOption,
        groupSettingsRepositoryPath,
        squashOptionsFeatureAvailable: true,
        projectPath,
        protectedBranchesPath,
        securityPoliciesPath,
        showApprovers,
        showStatusChecks,
        showCodeOwners,
      },
      stubs: {
        // Only stub complex/external components to keep tests fast
        GlSprintf,
        StatusChecks,
        ApprovalRulesApp: stubComponent(ApprovalRulesApp, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
        ProjectRules,
        Protection,
        ProtectionToggle,
      },
    });

    await waitForPromises();
  };

  beforeEach(() => createComponent());

  afterEach(() => axiosMock.restore());

  const findDeleteRuleButton = () => wrapper.findComponentByTestId('delete-rule-button');
  const findGroupLevelEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findDeleteRuleButtonPopover = () => wrapper.findComponent(GlPopover);
  const findAllowedToMerge = () => wrapper.findComponentByTestId('allowed-to-merge-content');
  const findAllowedToPush = () => wrapper.findComponentByTestId('allowed-to-push-content');
  const findApprovalsApp = () => wrapper.findComponent(ApprovalRulesApp);
  const findProjectRules = () => wrapper.findComponent(ProjectRules);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findStatusChecksCrud = () => wrapper.findByTestId('status-checks');
  const findStatusChecksTitle = () => wrapper.findByTestId('crud-title');
  const findAllowForcePushToggle = () => wrapper.findComponentByTestId('force-push-content');
  const findAccessLevelsDrawer = () => wrapper.findComponent(AccessLevelsDrawer);
  const findCodeOwnersToggle = () => wrapper.findComponentByTestId('code-owners-content');
  const findStatusChecksDrawer = () => wrapper.findByTestId('status-checks-drawer');
  const findSquashSettingContent = () => wrapper.findComponentByTestId('squash-setting-content');
  const findCustomRoleRows = (root = wrapper) =>
    root.findAllComponents(ProtectionRow).filter((row) => row.props('memberRoles').length > 0);

  describe('Squash settings', () => {
    it('renders squash option and help text when available', () => {
      const content = findSquashSettingContent();
      expect(content.text()).toContain('Encourage');
      expect(content.text()).toContain('Checkbox is visible and selected by default.');
    });

    it('does not render squash settings section when canReadSquashOption is false', async () => {
      await createComponent({ canReadSquashOption: false });
      expect(findSquashSettingContent().exists()).toBe(false);
    });

    it('does not show edit for squash settings when canUpdateSquashOption is false', async () => {
      await createComponent({ canUpdateSquashOption: false });
      expect(findSquashSettingContent().props('isEditAvailable')).toBe(false);
    });
  });

  it('renders a branch protection component for push rules', () => {
    expect(findAllowedToPush().props()).toMatchObject({
      roles: protectionPropsMock.roles,
      header: 'Allowed to push and merge',
      count: 3,
    });
  });

  it('renders a branch protection component for merge rules', () => {
    expect(findAllowedToMerge().props()).toMatchObject({
      roles: protectionPropsMock.roles,
      header: 'Allowed to merge',
      count: 3,
    });
  });

  describe('Code owner approvals', () => {
    it('does not render a code owner approval section by default', () => {
      expect(findCodeOwnersToggle().exists()).toBe(false);
    });

    it.each`
      codeOwnerApprovalRequired | iconTitle                                       | description
      ${true}                   | ${'Requires code owner approval'}               | ${'Changed files listed in %{linkStart}CODEOWNERS%{linkEnd} require an approval for merge requests and will be rejected for code pushes.'}
      ${false}                  | ${'Does not require approval from code owners'} | ${'Changed files listed in %{linkStart}CODEOWNERS%{linkEnd} require an approval for merge requests and will be rejected for code pushes.'}
    `(
      'renders code owners approval section with the correct iconTitle and description',
      async ({ codeOwnerApprovalRequired, iconTitle, description }) => {
        const mockResponse = cloneDeep(branchProtectionsMockResponse);
        mockResponse.data.project.branchRules.nodes[0].branchProtection.codeOwnerApprovalRequired =
          codeOwnerApprovalRequired;
        await createComponent({ showCodeOwners: true }, mockResponse);

        expect(findCodeOwnersToggle().props('iconTitle')).toEqual(iconTitle);
        expect(findCodeOwnersToggle().props('description')).toEqual(description);
      },
    );

    it('emits a tracking event, when Code Owner Approval toggle is switched', async () => {
      await createComponent({ showCodeOwners: true });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findCodeOwnersToggle().vm.$emit('toggle', false);
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith('change_require_codeowner_approval', {
        label: 'branch_rule_details',
      });
    });

    it('does not include access levels when toggling code owner approval', async () => {
      await createComponent({ showCodeOwners: true });
      findCodeOwnersToggle().vm.$emit('toggle', false);
      await waitForPromises();

      expect(editBranchRuleSuccessHandler).toHaveBeenCalledTimes(1);

      const callArgs = editBranchRuleSuccessHandler.mock.calls[0][0];
      const { branchProtection } = callArgs.input;

      expect(branchProtection).toHaveProperty('codeOwnerApprovalRequired', false);
      expect(branchProtection).toHaveProperty('allowForcePush');
      expect(branchProtection).not.toHaveProperty('pushAccessLevels');
      expect(branchProtection).not.toHaveProperty('mergeAccessLevels');
    });
  });

  it('does not render approvals and status checks sections by default', () => {
    expect(findApprovalsApp().exists()).toBe(false);
    expect(findStatusChecksCrud().exists()).toBe(false);
  });

  describe('if "showApprovers" is true', () => {
    beforeEach(() => createComponent({ showApprovers: true }));

    it('sets an approval rules filter', () => {
      expect(store.modules.approvals.actions.setRulesFilter).toHaveBeenCalledWith(
        expect.anything(),
        ['test'],
      );
    });

    it('fetches the approval rules', () => {
      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledTimes(1);
    });

    it('re-fetches the approval rules when a rule is successfully added/edited', async () => {
      findApprovalsApp().vm.$emit('submitted');
      await waitForPromises();

      expect(store.modules.approvals.actions.setRulesFilter).toHaveBeenCalledTimes(2);
      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledTimes(2);
    });

    it('shows an alert when refetch throws an error on submitted event', () => {
      const errorMessage = 'Refetch failed';
      const ruleViewCe = wrapper.findComponent({ name: 'RuleView' });
      jest.spyOn(ruleViewCe.vm.$apollo.queries.project, 'refetch').mockImplementation(() => {
        throw new Error(errorMessage);
      });

      findApprovalsApp().vm.$emit('submitted');

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        captureError: true,
        error: expect.any(Error),
      });
    });

    it('renders the approval rules component with correct props', () => {
      expect(findApprovalsApp().props('isMrEdit')).toBe(false);
    });

    it('renders the project rules component', () => {
      expect(findProjectRules().exists()).toBe(true);
    });
  });

  describe('if "showStatusChecks" is true', () => {
    it('does not render status check section for all protected branches', () => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('All protected branches');
      createComponent({ showStatusChecks: true });
      expect(findStatusChecksTitle().exists()).toBe(false);
      expect(findStatusChecksDrawer().exists()).toBe(false);
    });

    it('renders status check section for all branches', async () => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('All branches');
      createComponent({ showStatusChecks: true }, predefinedBranchRulesMockResponse);
      await waitForPromises();
      expect(findCrudComponent().props('title')).toBe('Rule target');
      expect(findStatusChecksDrawer().exists()).toBe(true);
    });

    it('renders status check section for non-predefined branch', async () => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('main');
      createComponent({ showStatusChecks: true }, branchProtectionsMockResponse);
      await waitForPromises();
      expect(findCrudComponent().props('title')).toBe('Rule target');
      expect(findStatusChecksDrawer().exists()).toBe(true);
    });
  });

  describe('Security policies', () => {
    describe('deleting a branch rule', () => {
      describe('when it prevents deletion', () => {
        beforeEach(async () => {
          const mockResponse = cloneDeep(branchProtectionsMockResponse);
          mockResponse.data.project.branchRules.nodes[0].branchProtection.modificationBlockedByPolicy = true;
          await createComponent({}, mockResponse);
        });

        it('renders disabled delete rule button', () => {
          expect(findDeleteRuleButton().exists()).toBe(true);
          expect(findDeleteRuleButton().props('disabled')).toBe(true);
        });

        it('renders the delete button popover', () => {
          const popover = findDeleteRuleButtonPopover();
          expect(popover.exists()).toBe(true);
          expect(popover.text()).toBe(
            "You can't unprotect this branch because its protection is enforced by one or more security policies. Learn more.",
          );
          expect(findDeleteRuleButtonPopover().exists()).toBe(true);
        });
      });

      describe('when it warns about deletion (warn mode)', () => {
        beforeEach(async () => {
          const mockResponse = cloneDeep(branchProtectionsMockResponse);
          mockResponse.data.project.branchRules.nodes[0].branchProtection.warnModificationBlockedByPolicy = true;
          await createComponent({}, mockResponse);
        });

        it('renders enabled delete rule button', () => {
          expect(findDeleteRuleButton().exists()).toBe(true);
          expect(findDeleteRuleButton().props('disabled')).toBe(false);
        });

        it('renders the delete button popover with warn mode message', () => {
          const popover = findDeleteRuleButtonPopover();
          expect(popover.exists()).toBe(true);
          expect(popover.text()).toBe(
            "If one or more security policies become enforced, you can't unprotect this branch. Learn more.",
          );
        });
      });

      describe('when it does not prevent deletion', () => {
        beforeEach(async () => {
          await createComponent();
        });

        it('renders enabled delete rule button', () => {
          expect(findDeleteRuleButton().exists()).toBe(true);
          expect(findDeleteRuleButton().props('disabled')).toBe(false);
        });

        it('does not render the delete button popover', () => {
          expect(findDeleteRuleButtonPopover().exists()).toBe(false);
        });
      });
    });

    describe('preventing push/force push', () => {
      describe('when it prevents pushing/force pushing to a branch', () => {
        beforeEach(async () => {
          const mockResponse = cloneDeep(branchProtectionsMockResponse);
          mockResponse.data.project.branchRules.nodes[0].branchProtection.protectedFromPushBySecurityPolicy = true;
          await createComponent({}, mockResponse);
        });

        it('renders the allowed to push button with the correct props', () => {
          expect(findAllowedToPush().props('isProtectedByPolicy')).toBe(true);
        });

        it('renders the force push toggle with the correct props', () => {
          expect(findAllowForcePushToggle().props('isProtectedByPolicy')).toBe(true);
        });

        // Regression: issue #602530. Editing merge access must not echo the
        // synthetic "no one" push access level (returned when push is
        // policy-protected), which would be read as a push change and blocked.
        it('omits push access levels from the update when editing merge access', async () => {
          findAllowedToMerge().vm.$emit('edit');
          await waitForPromises();
          findAccessLevelsDrawer().vm.$emit('edit-rule', [{ accessLevel: 30 }]);
          await waitForPromises();

          const { branchProtection } = editBranchRuleSuccessHandler.mock.calls[0][0].input;
          expect(branchProtection).not.toHaveProperty('pushAccessLevels');
          expect(branchProtection).toHaveProperty('mergeAccessLevels');
        });

        // Same class of bug as pushAccessLevels: the model forces
        // allow_force_push to a synthetic value under the policy, so echoing it
        // back would persist that over the branch's real stored setting.
        it('omits allowForcePush from the update when editing merge access', async () => {
          findAllowedToMerge().vm.$emit('edit');
          await waitForPromises();
          findAccessLevelsDrawer().vm.$emit('edit-rule', [{ accessLevel: 30 }]);
          await waitForPromises();

          const { branchProtection } = editBranchRuleSuccessHandler.mock.calls[0][0].input;
          expect(branchProtection).not.toHaveProperty('allowForcePush');
        });
      });

      describe('when it warns about pushing/force pushing to a branch (warn mode)', () => {
        beforeEach(async () => {
          const mockResponse = cloneDeep(branchProtectionsMockResponse);
          mockResponse.data.project.branchRules.nodes[0].branchProtection.warnProtectedFromPushBySecurityPolicy = true;
          await createComponent({}, mockResponse);
        });

        it('renders the allowed to push button with warn mode props', () => {
          expect(findAllowedToPush().props('isProtectedByWarnPolicy')).toBe(true);
        });

        it('renders the force push toggle with warn mode props', () => {
          expect(findAllowForcePushToggle().props('isProtectedByWarnPolicy')).toBe(true);
        });
      });

      describe('when it does not prevent pushing/force pushing to a branch', () => {
        beforeEach(async () => {
          await createComponent();
        });

        it('renders the allowed to push button with the correct props', () => {
          expect(findAllowedToPush().props('isProtectedByPolicy')).toBe(false);
        });

        it('renders the force push toggle with the correct props', () => {
          expect(findAllowForcePushToggle().props('isProtectedByPolicy')).toBe(false);
        });
      });
    });
  });

  describe('when isGroupLevel is true', () => {
    // `nullProtection: true` mirrors the response a user without group permissions
    // receives: the rule resolves but `branchProtection` is unauthorized (null).
    const buildGroupLevelRulesMockResponse = ({ nullProtection = false } = {}) => {
      const base = cloneDeep(branchProtectionsMockResponse);
      base.data.project.branchRules.nodes = base.data.project.branchRules.nodes.map((node) => ({
        ...node,
        isGroupLevel: true,
        branchProtection: nullProtection ? null : { ...node.branchProtection, isGroupLevel: true },
      }));
      return base;
    };

    const groupLevelRulesMockResponse = buildGroupLevelRulesMockResponse();

    beforeEach(() => createComponent({ showCodeOwners: true }, groupLevelRulesMockResponse));

    it('filters out a group level rule from display', () => {
      expect(findDeleteRuleButton().exists()).toBe(false);
      expect(findAllowedToMerge().exists()).toBe(false);
      expect(findAllowedToPush().exists()).toBe(false);
      expect(findAllowForcePushToggle().exists()).toBe(false);
      expect(findCodeOwnersToggle().exists()).toBe(false);
    });

    it('renders a "Setting inherited" empty state without an action when the user cannot admin group protected branches', () => {
      const emptyState = findGroupLevelEmptyState();

      expect(emptyState.props('title')).toBe('Setting inherited');
      expect(emptyState.props('description')).toBe(
        'This branch rule is configured for the group. You do not have the required permissions.',
      );
      expect(emptyState.props('primaryButtonText')).toBe(null);
      expect(wrapper.text()).not.toContain('No data to display');
    });

    it('renders a "Setting inherited" empty state linking to group settings when the user can admin group protected branches', async () => {
      await createComponent({ canAdminGroupProtectedBranches: true }, groupLevelRulesMockResponse);

      const emptyState = findGroupLevelEmptyState();

      expect(emptyState.props('title')).toBe('Setting inherited');
      expect(emptyState.props('description')).toBe(
        'This branch rule is configured for the group. To make changes, go to group repository settings.',
      );
      expect(emptyState.props('primaryButtonText')).toBe('View group repository settings');
      expect(emptyState.props('primaryButtonLink')).toBe(groupSettingsRepositoryPath);
    });

    it('renders the empty state when the user cannot read the group branch protection (null branchProtection)', async () => {
      await createComponent({}, buildGroupLevelRulesMockResponse({ nullProtection: true }));

      const emptyState = findGroupLevelEmptyState();

      expect(emptyState.props('title')).toBe('Setting inherited');
      expect(emptyState.props('description')).toBe(
        'This branch rule is configured for the group. You do not have the required permissions.',
      );
      expect(findDeleteRuleButton().exists()).toBe(false);
      expect(findAllowedToMerge().exists()).toBe(false);
    });
  });

  describe('custom role access levels', () => {
    it('passes memberRoleId in GlobalID form through to the mutation when the drawer emits `edit-rule`', async () => {
      await createComponent();
      findAllowedToMerge().vm.$emit('edit');
      await waitForPromises();

      const customRolePayload = [{ memberRoleId: 'gid://gitlab/MemberRole/1' }];
      findAccessLevelsDrawer().vm.$emit('edit-rule', customRolePayload);
      await waitForPromises();

      expect(editBranchRuleSuccessHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            branchProtection: expect.objectContaining({
              mergeAccessLevels: customRolePayload,
            }),
          }),
        }),
      );
    });
  });

  describe('memberRole data', () => {
    it('passes memberRoles from the query response to the access levels drawer', async () => {
      await createComponent();

      findAllowedToMerge().vm.$emit('edit');
      await waitForPromises();

      expect(wrapper.findComponent(AccessLevelsDrawerCe).props('memberRoles')).toEqual([
        { id: 'gid://gitlab/MemberRole/1', name: 'Custom Developer' },
      ]);
    });

    it.each`
      protection            | findProtection
      ${'allowed to merge'} | ${findAllowedToMerge}
      ${'allowed to push'}  | ${findAllowedToPush}
    `('passes memberRoles to the $protection protection', async ({ findProtection }) => {
      await createComponent();

      const customRoleRows = findCustomRoleRows(findProtection());
      expect(customRoleRows).toHaveLength(1);
      expect(customRoleRows.at(0).props('memberRoles')).toEqual([
        { id: 'gid://gitlab/MemberRole/1', name: 'Custom Developer' },
      ]);
    });
  });
});
