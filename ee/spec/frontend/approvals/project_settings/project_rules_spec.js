import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RuleInput from 'ee/approvals/components/rules/rule_input.vue';
import ProjectRules from 'ee/approvals/project_settings/project_rules.vue';
import RuleName from 'ee/approvals/components/rules/rule_name.vue';
import Rules from 'ee/approvals/components/rules/rules.vue';
import UnconfiguredSecurityRules from 'ee/approvals/components/security_configuration/unconfigured_security_rules.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';
import UserAvatarList from '~/vue_shared/components/user_avatar/user_avatar_list.vue';
import { createProjectRules } from '../mocks';

const TEST_RULES = createProjectRules();

Vue.use(Vuex);

const findCell = (tr, dataTestIdSuffix) =>
  tr.find(`[data-testid="approvals-table-${dataTestIdSuffix}"]`);

const getRowData = (tr) => {
  const name = findCell(tr, 'name');
  const members = findCell(tr, 'members');
  const approvalsRequired = findCell(tr, 'approvals-required');
  return {
    name: name.text(),
    approvers: members.findComponent(UserAvatarList).props('items'),
    approvalsRequired: approvalsRequired.findComponent(RuleInput).props('rule').approvalsRequired,
  };
};

const findShowMoreButton = (wrapper) => wrapper.findByText('Show more');

describe('Approvals ProjectRules', () => {
  let wrapper;
  let store;
  let vuexStore;

  const factory = (props = {}, options = {}) => {
    vuexStore = new Vuex.Store(store);
    wrapper = mountExtended(ProjectRules, {
      propsData: props,
      store: vuexStore,
      ...options,
    });
  };

  beforeEach(() => {
    store = createStoreOptions({ approvals: projectSettingsModule() });
    store.modules.approvals.state.rules = TEST_RULES;
  });

  describe('isBranchRulesEdit', () => {
    const findBranches = () => wrapper.findByTestId('approvals-table-branches');

    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    describe('when `true`', () => {
      beforeEach(() => {
        factory({ isBranchRulesEdit: true });
      });

      it('should never have any_approver rule', () => {
        const hasAnyApproverRule = store.modules.approvals.state.rules.some(
          (rule) => rule.ruleType === 'any_approver',
        );

        expect(hasAnyApproverRule).toBe(false);
      });

      it('does not render unconfigured security rules', () => {
        expect(wrapper.findComponent(UnconfiguredSecurityRules).exists()).toBe(false);
      });

      it('should not have Show more pagination button', () => {
        expect(findShowMoreButton(wrapper).exists()).toBe(false);
      });

      it('does not render branches', () => {
        expect(findBranches().exists()).toBe(false);
      });

      it('does not render no rules text', () => {
        expect(wrapper.text()).not.toContain(
          'Define target branch approval rules for new merge requests.',
        );
      });

      describe('when there are no rules', () => {
        it('renders the "no rules text"', async () => {
          await vuexStore.commit('SET_RULES', []);

          expect(wrapper.text()).toContain(
            'Define target branch approval rules for new merge requests.',
          );
        });
      });
    });

    it('when `false` renders branches', () => {
      factory({ isBranchRulesEdit: false });

      expect(findBranches().exists()).toBe(true);
    });
  });

  describe('when allow multiple rules', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    it('renders row for each rule', () => {
      factory();

      const userAddedRules = wrapper
        .findComponent(Rules)
        .findAll('tbody tr')
        .filter((_, index) => index > 1);

      const userAddedRulesWrappers = userAddedRules.wrappers || userAddedRules;

      const userAddedRulesMappedItems = [...userAddedRulesWrappers.map(getRowData)];

      expect(userAddedRulesMappedItems).toEqual(
        TEST_RULES.filter((_, index) => index !== 0).map((rule) => ({
          name: rule.name,
          approvers: rule.eligibleApprovers,
          approvalsRequired: rule.approvalsRequired,
        })),
      );

      expect(wrapper.findComponent(Rules).findAllComponents(RuleName)).toHaveLength(
        TEST_RULES.length,
      );
    });

    it('should always have any_approver rule', () => {
      factory();
      const hasAnyApproverRule = store.modules.approvals.state.rules.some(
        (rule) => rule.ruleType === 'any_approver',
      );

      expect(hasAnyApproverRule).toBe(true);
    });
  });

  describe('when only allow single rule', () => {
    let rule;
    let row;

    beforeEach(() => {
      [rule] = TEST_RULES;
      store.modules.approvals.state.rules = [rule];

      factory();

      row = wrapper.findComponent(Rules).find('tbody tr');
    });

    it('does not render name', () => {
      expect(findCell(row, 'name').exists()).toBe(false);
    });

    it('should only display 1 rule', () => {
      expect(store.modules.approvals.state.rules).toHaveLength(1);
      expect(wrapper.findComponent(Rules).findAllComponents(RuleName)).toHaveLength(1);
    });
  });

  describe('approval suggestions', () => {
    beforeEach(() => {
      const rules = createProjectRules();
      rules[0].name = 'Coverage-Check';
      store.modules.approvals.state.rules = rules;
      store.state.settings.allowMultiRule = true;

      factory();
    });

    it(`should render the unconfigured-security-rules component`, () => {
      expect(wrapper.findComponent(UnconfiguredSecurityRules).exists()).toBe(true);
    });
  });

  describe('"Show More" button', () => {
    describe('when there are more than 20 rules to show', () => {
      const fetchRules = jest.fn();

      beforeEach(() => {
        const module = projectSettingsModule();

        store = createStoreOptions({
          approvals: {
            ...module,
            actions: {
              ...module.actions,
              fetchRules,
            },
            state: {
              ...module.state,
              rulesPagination: {
                nextPage: 2,
              },
            },
          },
        });
      });

      it('should be visible', () => {
        factory();

        expect(findShowMoreButton(wrapper).exists()).toBe(true);
      });

      it('on click should initiate loading the next page of the rules', async () => {
        factory();

        const button = findShowMoreButton(wrapper);
        await button.trigger('click');

        expect(fetchRules).toHaveBeenCalled();
      });
    });

    describe('when there are less than 20 rules to show', () => {
      it('should be hidden', () => {
        factory();

        expect(findShowMoreButton(wrapper).exists()).toBe(false);
      });
    });

    describe('when there are no more rules to show', () => {
      beforeEach(() => {
        const module = projectSettingsModule();

        store = createStoreOptions({
          approvals: {
            ...module,
            state: {
              ...module.state,
              rulesPagination: {
                nextPage: null,
              },
            },
          },
        });
      });

      it('should be hidden', () => {
        factory();
        expect(findShowMoreButton(wrapper).exists()).toBe(false);
      });
    });
  });
});
