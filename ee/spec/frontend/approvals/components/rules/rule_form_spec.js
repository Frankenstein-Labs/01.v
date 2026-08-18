import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import RuleForm, { READONLY_NAMES } from 'ee/approvals/components/rules/rule_form.vue';
import { TYPE_USER, TYPE_GROUP, TYPE_HIDDEN_GROUPS } from 'ee/approvals/constants';
import { createStoreOptions } from 'ee/approvals/stores';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';
import ProtectedBranchesSelector from 'ee/vue_shared/components/branches_selector/protected_branches_selector.vue';
import { stubComponent } from 'helpers/stub_component';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  ALL_BRANCHES,
  ALL_PROTECTED_BRANCHES,
} from 'ee/vue_shared/components/branches_selector/constants';
import {
  TEST_RULE,
  TEST_PROTECTED_BRANCHES,
  TEST_RULE_WITH_PROTECTED_BRANCHES,
  TEST_RULE_WITH_ALL_BRANCHES,
  TEST_RULE_WITH_ALL_PROTECTED_BRANCHES,
} from '../../mocks';

const TEST_PROJECT_ID = '7';
const TEST_APPROVERS = [{ id: 7, type: TYPE_USER }];
const TEST_APPROVALS_REQUIRED = 3;
const TEST_FALLBACK_RULE = {
  approvalsRequired: 1,
  isFallback: true,
};
const TEST_LOCKED_RULE_NAME = 'LOCKED_RULE';
const nameTakenError = {
  response: {
    data: {
      message: {
        name: ['has already been taken'],
      },
    },
  },
};

const nameTooLongError = {
  response: {
    data: {
      message: {
        name: ['is too long (maximum is 1024 characters)'],
      },
    },
  },
};

Vue.use(Vuex);

describe('EE Approvals RuleForm', () => {
  let wrapper;
  let store;
  let actions;

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      shallowMount(RuleForm, {
        propsData: props,
        store: new Vuex.Store(store),
        stubs: {
          GlFormGroup: stubComponent(GlFormGroup, {
            props: ['state', 'invalidFeedback'],
          }),
          GlFormInput: stubComponent(GlFormInput, {
            props: ['state', 'disabled', 'value'],
            template: `<input />`,
          }),
          BranchesSelect: stubComponent(ProtectedBranchesSelector),
        },
      }),
    );
  };

  const findForm = () => wrapper.find('form');
  const findNameInput = () => wrapper.findComponentByTestId('rule-name-field');
  const findNameValidation = () => wrapper.findComponentByTestId('name-group');
  const findApprovalsRequiredInput = () => wrapper.findComponentByTestId('approvals-required');
  const findApprovalsRequiredValidation = () =>
    wrapper.findComponentByTestId('approvals-required-group');
  const findUsersSelector = () => wrapper.findComponentByTestId('users-selector');
  const findGroupsSelector = () => wrapper.findComponentByTestId('groups-selector');
  const findApproversValidation = () => wrapper.findComponentByTestId('approvers-group');
  const findProtectedBranchesSelector = () => wrapper.findComponent(ProtectedBranchesSelector);
  const findBranchesValidation = () => wrapper.findComponentByTestId('branches-group');

  const inputsAreValid = (inputs) => inputs.every((x) => x.props('state'));

  const findValidations = () => [
    findNameValidation(),
    findApprovalsRequiredValidation(),
    findApproversValidation(),
  ];

  const findValidationsWithBranch = () => [
    findNameValidation(),
    findApprovalsRequiredValidation(),
    findApproversValidation(),
    findBranchesValidation(),
  ];

  const selectApprovers = () => {
    const selectedUser1 = { id: 1, type: TYPE_USER };
    const selectedUser2 = { id: 2, type: TYPE_USER };
    const selectedGroup1 = { id: 2, type: TYPE_GROUP };
    const selectedGroup2 = { id: 3, type: TYPE_GROUP };

    findUsersSelector().vm.$emit('select', selectedUser1);
    findUsersSelector().vm.$emit('select', selectedUser2);
    findGroupsSelector().vm.$emit('select', selectedGroup1);
    findGroupsSelector().vm.$emit('select', selectedGroup2);
  };

  beforeEach(() => {
    store = createStoreOptions(
      { approvals: projectSettingsModule() },
      { projectId: TEST_PROJECT_ID },
    );

    ['postRule', 'putRule', 'deleteRule', 'putFallbackRule'].forEach((actionName) => {
      jest.spyOn(store.modules.approvals.actions, actionName).mockImplementation(() => {});
    });

    ({ actions } = store.modules.approvals);
  });

  describe('when allow multiple rules', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    it('renders Item Selector with groups scoped to the project and with namespace dropdown', () => {
      createComponent({ isBranchRulesEdit: true, isMrEdit: false });

      expect(findGroupsSelector().props('disableNamespaceDropdown')).toBe(false);
      expect(findGroupsSelector().props('isProjectScoped')).toBe(true);
    });

    describe('isBranchRulesEdit set to `true`', () => {
      it('hides the branch selector', () => {
        createComponent({ isBranchRulesEdit: true, isMrEdit: false });

        expect(findBranchesValidation().isVisible()).toBe(false);
      });
    });

    describe('when has protected branch feature', () => {
      describe('with initial rule', () => {
        it('on load, it populates initial protected branch ids', () => {
          createComponent({
            isMrEdit: false,
            initRule: TEST_RULE_WITH_PROTECTED_BRANCHES,
          });

          expect(findProtectedBranchesSelector().props('selectedBranches')).toStrictEqual(
            TEST_PROTECTED_BRANCHES,
          );
        });
      });

      describe('with initial all branches rule', () => {
        it('on load, it populates initial protected branch ids', () => {
          createComponent({
            isMrEdit: false,
            initRule: TEST_RULE_WITH_ALL_BRANCHES,
          });

          expect(findProtectedBranchesSelector().props('selectedBranches')).toStrictEqual([
            ALL_BRANCHES,
          ]);
        });
      });

      describe('with initial all protected branches rule', () => {
        beforeEach(() => {
          store.state.settings.allowAllProtectedBranchesOption = true;
        });

        it('on load, it populates initial protected branch ids', () => {
          createComponent({
            isMrEdit: false,
            initRule: TEST_RULE_WITH_ALL_PROTECTED_BRANCHES,
          });

          expect(findProtectedBranchesSelector().props('allowAllProtectedBranchesOption')).toBe(
            true,
          );
          expect(findProtectedBranchesSelector().props('selectedBranches')).toStrictEqual([
            ALL_PROTECTED_BRANCHES,
          ]);
        });
      });

      describe('without initRule', () => {
        const users = [1, 2];
        const groups = [2, 3];
        const userRecords = users.map((id) => ({ id, type: TYPE_USER }));
        const groupRecords = groups.map((id) => ({ id, type: TYPE_GROUP }));
        const ruleData = (attributes = {}) => ({
          id: null,
          name: 'Lorem',
          approvalsRequired: 2,
          users,
          groups,
          userRecords,
          groupRecords,
          removeHiddenGroups: false,
          protectedBranchIds: [],
          appliesToAllProtectedBranches: false,
          ...attributes,
        });

        beforeEach(() => {
          store.state.settings.protectedBranches = TEST_PROTECTED_BRANCHES;
        });

        it('at first, shows no validation', () => {
          createComponent({
            isMrEdit: false,
          });

          expect(inputsAreValid(findValidationsWithBranch())).toBe(true);
        });

        it('on submit, shows branches validation', async () => {
          createComponent({
            isMrEdit: false,
          });

          await findProtectedBranchesSelector().vm.$emit('input', '3');
          await findForm().trigger('submit');
          await nextTick();

          const branchesGroup = findBranchesValidation();
          expect(branchesGroup.props('state')).toBe(false);
          expect(branchesGroup.props('invalidFeedback')).toBe(
            'Please select a valid target branch',
          );
        });

        it('on submit with data, posts rule', async () => {
          createComponent({
            isMrEdit: false,
          });

          const branches = [TEST_PROTECTED_BRANCHES[0]];
          const expected = ruleData({
            protectedBranchIds: branches.map((x) => x.id),
          });

          selectApprovers();
          await findNameInput().vm.$emit('input', expected.name);
          await findApprovalsRequiredInput().vm.$emit('input', expected.approvalsRequired);
          await findProtectedBranchesSelector().vm.$emit('input', branches[0]);
          await findForm().trigger('submit');

          expect(actions.postRule).toHaveBeenCalledWith(expect.anything(), expected);
        });

        it('on submit with all branches, posts rule', async () => {
          createComponent({
            isMrEdit: false,
          });
          const expected = ruleData();

          selectApprovers();
          await findNameInput().vm.$emit('input', expected.name);
          await findApprovalsRequiredInput().vm.$emit('input', expected.approvalsRequired);
          await findProtectedBranchesSelector().vm.$emit('input', ALL_BRANCHES);
          await findForm().trigger('submit');

          expect(actions.postRule).toHaveBeenCalledWith(expect.anything(), expected);
        });

        describe('with all protected branches allowed', () => {
          beforeEach(() => {
            store.state.settings.allowAllProtectedBranchesOption = true;
          });

          it('on submit with all protected branches, posts rule', async () => {
            createComponent({
              isMrEdit: false,
            });

            const expected = ruleData({ appliesToAllProtectedBranches: true });

            selectApprovers();
            await findNameInput().vm.$emit('input', expected.name);
            await findApprovalsRequiredInput().vm.$emit('input', expected.approvalsRequired);
            await findProtectedBranchesSelector().vm.$emit('input', ALL_PROTECTED_BRANCHES);
            await findForm().trigger('submit');

            expect(actions.postRule).toHaveBeenCalledWith(expect.anything(), expected);
          });
        });
      });
    });

    describe('without initRule', () => {
      beforeEach(() => {
        createComponent({ isMrEdit: false });
      });

      it('displays the correct label for required approvals', () => {
        expect(findApprovalsRequiredValidation().attributes('label')).toBe(
          'Required number of approvals',
        );
      });

      it('at first, shows no validation', () => {
        expect(inputsAreValid(findValidationsWithBranch())).toBe(true);
      });

      it('on submit, does not dispatch action', async () => {
        await findForm().trigger('submit');

        expect(actions.postRule).not.toHaveBeenCalled();
      });

      it('on submit, shows name validation', async () => {
        wrapper.findByTestId('rule-name-field').setValue('');

        await findForm().trigger('submit');
        await nextTick();

        const nameGroup = findNameValidation();
        expect(nameGroup.props('state')).toBe(false);
        expect(nameGroup.props('invalidFeedback')).toBe('Please provide a name');
      });

      it('on submit, shows approvalsRequired validation', async () => {
        await findApprovalsRequiredInput().vm.$emit('input', -1);
        await findForm().trigger('submit');
        await nextTick();

        const approvalsRequiredGroup = findApprovalsRequiredValidation();
        expect(approvalsRequiredGroup.props('state')).toBe(false);
        expect(approvalsRequiredGroup.props('invalidFeedback')).toBe(
          'Please enter a non-negative number',
        );
      });

      it('on submit, shows approvers validation', async () => {
        await findForm().trigger('submit');
        await nextTick();

        const approversGroup = findApproversValidation();
        expect(approversGroup.props('state')).toBe(false);
        expect(approversGroup.props('invalidFeedback')).toBe('Please select and add a member');
      });

      describe('with valid data', () => {
        const users = [1, 2];
        const groups = [2, 3];
        const userRecords = users.map((id) => ({ id, type: TYPE_USER }));
        const groupRecords = groups.map((id) => ({ id, type: TYPE_GROUP }));
        const branches = [TEST_PROTECTED_BRANCHES[0]];
        const expected = {
          id: null,
          name: 'Lorem',
          approvalsRequired: 2,
          users,
          groups,
          userRecords,
          groupRecords,
          removeHiddenGroups: false,
          protectedBranchIds: branches.map((x) => x.id),
          appliesToAllProtectedBranches: false,
        };

        beforeEach(async () => {
          await findNameInput().vm.$emit('input', expected.name);
          await findApprovalsRequiredInput().vm.$emit('input', expected.approvalsRequired);
          selectApprovers();
          await findProtectedBranchesSelector().vm.$emit('input', branches[0]);
        });

        it('on submit, posts rule', async () => {
          await findForm().trigger('submit');

          expect(actions.postRule).toHaveBeenCalledWith(expect.anything(), expected);
        });

        it('when submitted with a duplicate name, shows the "taken name" validation', async () => {
          store.state.settings.prefix = 'project-settings';
          actions.postRule.mockRejectedValueOnce(nameTakenError);

          await findForm().trigger('submit');
          await nextTick();
          // We have to wait for two ticks because the promise needs to resolve
          // AND the result has to update into the UI
          await nextTick();

          const nameGroup = findNameValidation();
          expect(nameGroup.props('state')).toBe(false);
          expect(nameGroup.props('invalidFeedback')).toBe('Rule name is already taken.');
        });

        it('when submitted with a name too long, shows the "ruleNameTooLong" validation', async () => {
          actions.postRule.mockRejectedValueOnce(nameTooLongError);

          await findForm().trigger('submit');
          await waitForPromises();

          const nameGroup = findNameValidation();
          expect(nameGroup.props('state')).toBe(false);
          expect(nameGroup.props('invalidFeedback')).toBe(
            'Please enter a name with less than 1024 characters.',
          );
        });
      });

      it('adds selected approvers on selection', async () => {
        const selectedUser1 = { id: 1, type: TYPE_USER };
        const selectedUser2 = { id: 2, type: TYPE_USER };
        const selectedGroup1 = { id: 1, type: TYPE_GROUP };
        const selectedGroup2 = { id: 1, type: TYPE_GROUP };

        await findUsersSelector().vm.$emit('select', selectedUser1);
        await findUsersSelector().vm.$emit('select', selectedUser2);

        await findGroupsSelector().vm.$emit('select', selectedGroup1);
        await findGroupsSelector().vm.$emit('select', selectedGroup2);

        expect(findUsersSelector().props('selectedItems')).toEqual([selectedUser1, selectedUser2]);
        expect(findGroupsSelector().props('selectedItems')).toEqual([
          selectedGroup1,
          selectedGroup2,
        ]);
      });
    });

    describe('with initRule', () => {
      beforeEach(() => {
        createComponent({
          initRule: TEST_RULE,
          isMrEdit: false,
        });
      });

      it('does not disable the name text field', () => {
        expect(findNameInput().attributes('disabled')).toBe(undefined);
      });

      it('shows approvers', () => {
        expect(findGroupsSelector().props('selectedItems')).toEqual([
          { id: 1, type: TYPE_GROUP },
          { id: 2, type: TYPE_GROUP },
        ]);
      });

      describe('with valid data', () => {
        const userRecords = TEST_RULE.users.map((x) => ({ ...x, type: TYPE_USER }));
        const groupRecords = TEST_RULE.groups.map((x) => ({ ...x, type: TYPE_GROUP }));
        const users = userRecords.map((x) => x.id);
        const groups = groupRecords.map((x) => x.id);

        const expected = {
          ...TEST_RULE,
          users,
          groups,
          userRecords,
          groupRecords,
          removeHiddenGroups: false,
          protectedBranchIds: [],
          appliesToAllProtectedBranches: false,
        };

        it('on submit, puts rule', async () => {
          await findForm().trigger('submit');

          expect(actions.putRule).toHaveBeenCalledWith(expect.anything(), expected);
        });

        it('when submitted with a duplicate name, shows the "taken name" validation', async () => {
          store.state.settings.prefix = 'project-settings';
          actions.putRule.mockRejectedValueOnce(nameTakenError);

          await findForm().trigger('submit');
          await waitForPromises();

          const nameGroup = findNameValidation();
          expect(nameGroup.props('state')).toBe(false);
          expect(nameGroup.props('invalidFeedback')).toBe('Rule name is already taken.');
        });
      });
    });

    describe('with init fallback rule', () => {
      beforeEach(() => {
        createComponent({
          initRule: TEST_FALLBACK_RULE,
        });

        findNameInput().vm.$emit('input', '');
        findApprovalsRequiredInput().vm.$emit('input', TEST_APPROVALS_REQUIRED);
      });

      describe('with empty name and empty approvers', () => {
        beforeEach(() => {
          findForm().trigger('submit');
        });

        it('does not post rule', () => {
          expect(actions.postRule).not.toHaveBeenCalled();
        });

        it('puts fallback rule', () => {
          expect(actions.putFallbackRule).toHaveBeenCalledWith(expect.anything(), {
            approvalsRequired: TEST_APPROVALS_REQUIRED,
          });
        });

        it('does not show any validation errors', () => {
          expect(inputsAreValid(findValidations())).toBe(true);
        });
      });

      describe('with name and empty approvers', () => {
        beforeEach(() => {
          findNameInput().vm.$emit('input', 'Lorem');
          findForm().trigger('submit');
        });

        it('does not put fallback rule', () => {
          expect(actions.putFallbackRule).not.toHaveBeenCalled();
        });

        it('shows approvers validation error', () => {
          expect(findApproversValidation().props('state')).toBe(false);
        });
      });

      describe('with empty name and approvers', () => {
        beforeEach(() => {
          selectApprovers();
          findForm().trigger('submit');
        });

        it('does not put fallback rule', () => {
          expect(actions.putFallbackRule).not.toHaveBeenCalled();
        });

        it('shows name validation error', () => {
          expect(findNameValidation().props('state')).toBe(false);
        });
      });

      describe('with name and approvers', () => {
        beforeEach(() => {
          selectApprovers();
          findNameInput().vm.$emit('input', 'Lorem');
          findForm().trigger('submit');
        });

        it('does not put fallback rule', () => {
          expect(actions.putFallbackRule).not.toHaveBeenCalled();
        });

        it('posts new rule', () => {
          expect(actions.postRule).toHaveBeenCalled();
        });
      });
    });

    describe('with hidden groups rule', () => {
      beforeEach(() => {
        createComponent({
          initRule: {
            ...TEST_RULE,
            containsHiddenGroups: true,
          },
        });
      });

      it('shows approvers and hidden group', () => {
        const list = findGroupsSelector();

        expect(list.props('selectedItems')).toEqual([
          { id: 1, type: 'group' },
          { id: 2, type: 'group' },
        ]);
      });

      it('on submit, does not remove hidden groups', async () => {
        await findForm().trigger('submit');

        expect(actions.putRule).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            removeHiddenGroups: false,
          }),
        );
      });

      describe('and hidden groups removed', () => {
        beforeEach(() => {
          findGroupsSelector().vm.$emit('delete', { id: 2, type: TYPE_HIDDEN_GROUPS });
        });

        it('on submit, removes hidden groups', async () => {
          await findForm().trigger('submit');

          expect(actions.putRule).toHaveBeenCalledWith(
            expect.anything(),
            expect.objectContaining({
              removeHiddenGroups: true,
            }),
          );
        });
      });
    });

    describe('with removed hidden groups rule', () => {
      beforeEach(() => {
        createComponent({
          initRule: {
            ...TEST_RULE,
            containsHiddenGroups: true,
            removeHiddenGroups: true,
          },
        });
      });

      it('does not add hidden groups in approvers', () => {
        expect(
          findGroupsSelector()
            .props('selectedItems')
            .every((x) => x.type !== TYPE_HIDDEN_GROUPS),
        ).toBe(true);
      });
    });

    describe('with approval suggestions', () => {
      describe.each`
        defaultRuleName     | expectedDisabledAttribute
        ${'Coverage-Check'} | ${true}
        ${'Foo Bar Baz'}    | ${false}
      `(
        'with defaultRuleName set to $defaultRuleName',
        ({ defaultRuleName, expectedDisabledAttribute }) => {
          beforeEach(() => {
            createComponent({
              initRule: null,
              isMrEdit: false,
              defaultRuleName,
            });
          });

          it(`it ${
            expectedDisabledAttribute ? 'disables' : 'does not disable'
          } the name text field`, () => {
            expect(findNameInput().props('disabled')).toBe(expectedDisabledAttribute);
          });
        },
      );
    });

    describe('with read-only rule name', () => {
      describe.each(READONLY_NAMES)('with new %s rule', (ruleName) => {
        beforeEach(() => {
          createComponent({
            initRule: { ...TEST_RULE, id: null, name: ruleName },
          });
        });

        it('does not disable the name text field', () => {
          expect(findNameInput().props('disabled')).toBe(false);
        });
      });

      describe.each(READONLY_NAMES)('with editing the %s rule', (ruleName) => {
        beforeEach(() => {
          createComponent({
            initRule: { ...TEST_RULE, name: ruleName },
          });
        });

        it('disables the name text field', () => {
          expect(findNameInput().props('disabled')).toBe(true);
        });
      });
    });
  });

  describe('when allow only single rule', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = false;
    });

    describe('with locked rule name', () => {
      beforeEach(() => {
        store.state.settings.lockedApprovalsRuleName = TEST_LOCKED_RULE_NAME;
        createComponent();
      });

      it('does not render the approval-rule name input', () => {
        expect(findNameInput().exists()).toBe(false);
      });
    });

    describe.each`
      lockedRuleName           | expectedNameSubmitted
      ${TEST_LOCKED_RULE_NAME} | ${TEST_LOCKED_RULE_NAME}
      ${null}                  | ${'Default'}
    `('with no init rule', ({ lockedRuleName, expectedNameSubmitted }) => {
      beforeEach(() => {
        store.state.settings.lockedApprovalsRuleName = lockedRuleName;
        createComponent();
        findApprovalsRequiredInput().vm.$emit('input', TEST_APPROVALS_REQUIRED);
      });

      describe('with approvers selected', () => {
        beforeEach(() => {
          selectApprovers();
          findForm().trigger('submit');
        });

        it('posts new rule', () => {
          expect(actions.postRule).toHaveBeenCalledWith(
            expect.anything(),
            expect.objectContaining({
              name: expectedNameSubmitted,
              approvalsRequired: TEST_APPROVALS_REQUIRED,
            }),
          );
        });
      });

      describe('without approvers', () => {
        beforeEach(() => {
          findForm().trigger('submit');
        });

        it('puts fallback rule', () => {
          expect(actions.putFallbackRule).toHaveBeenCalledWith(expect.anything(), {
            approvalsRequired: TEST_APPROVALS_REQUIRED,
          });
        });
      });
    });

    describe.each`
      lockedRuleName           | inputName | expectedNameSubmitted
      ${TEST_LOCKED_RULE_NAME} | ${'Foo'}  | ${TEST_LOCKED_RULE_NAME}
      ${null}                  | ${'Foo'}  | ${'Foo'}
    `('with init rule', ({ lockedRuleName, inputName, expectedNameSubmitted }) => {
      beforeEach(() => {
        store.state.settings.lockedApprovalsRuleName = lockedRuleName;
      });

      describe('with empty name and empty approvers', () => {
        beforeEach(() => {
          createComponent({
            initRule: { ...TEST_RULE, name: '' },
          });
          findApprovalsRequiredInput().vm.$emit('input', TEST_APPROVALS_REQUIRED);

          // Simulate the user removing all approvers
          findGroupsSelector().vm.$emit('delete', 1);
          findGroupsSelector().vm.$emit('delete', 2);
          findUsersSelector().vm.$emit('delete', 1);
          findUsersSelector().vm.$emit('delete', 2);
          findUsersSelector().vm.$emit('delete', 3);

          findForm().trigger('submit');
        });

        it('deletes rule', () => {
          expect(actions.deleteRule).toHaveBeenCalledWith(expect.anything(), TEST_RULE.id);
        });

        it('puts fallback rule', () => {
          expect(actions.putFallbackRule).toHaveBeenCalledWith(expect.anything(), {
            approvalsRequired: TEST_APPROVALS_REQUIRED,
          });
        });
      });

      describe('with name and approvers', () => {
        beforeEach(() => {
          createComponent({
            initRule: { ...TEST_RULE, name: inputName },
          });
          findApprovalsRequiredInput().vm.$emit('input', TEST_APPROVALS_REQUIRED);
          findUsersSelector().vm.$emit('select', TEST_APPROVERS[0]);

          findForm().trigger('submit');
        });

        it('puts rule', () => {
          expect(actions.putRule).toHaveBeenCalledWith(
            expect.anything(),
            expect.objectContaining({
              id: TEST_RULE.id,
              name: expectedNameSubmitted,
              approvalsRequired: TEST_APPROVALS_REQUIRED,
              users: [1, 2, 3, 7],
            }),
          );
        });
      });

      it('submits on keydown.enter', () => {
        createComponent({ initRule: { ...TEST_RULE, name: inputName } });
        findForm().trigger('keydown.enter');

        expect(actions.putRule).toHaveBeenCalled();
      });
    });
  });
});
