import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import axios from '~/lib/utils/axios_utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MREditApp from 'ee/approvals/mr_edit/app.vue';
import MRRules from 'ee/approvals/mr_edit/mr_rules.vue';
import MRRulesHiddenInputs from 'ee/approvals/mr_edit/mr_rules_hidden_inputs.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import MREditModule from 'ee/approvals/stores/modules/mr_edit';

Vue.use(Vuex);

describe('EE Approvals MREditApp', () => {
  let wrapper;
  let store;
  let axiosMock;

  const factory = (mrCollapsedApprovalRules = false) => {
    wrapper = mountExtended(MREditApp, {
      store: new Vuex.Store(store),
      provide: {
        glFeatures: {
          mrCollapsedApprovalRules,
        },
      },
    });
  };

  const findAllApprovalsTableNames = () =>
    wrapper.findComponent(MRRules).findAll('[data-testid="approvals-table-name"]');
  const findHiddenInputs = () =>
    wrapper.findByTestId('mr-approval-rules').findComponent(MRRulesHiddenInputs);
  const findSummaryText = () => wrapper.findByTestId('collapsedSummaryText');
  const findCodeownersTip = () => wrapper.findByTestId('codeowners-tip');

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    axiosMock.onGet('*');

    store = createStoreOptions({ approvals: MREditModule() });
    store.modules.approvals.state.hasLoaded = true;
  });

  afterEach(() => {
    axiosMock.restore();
  });

  it('renders CODEOWNERS tip', () => {
    store.state.settings.canUpdateApprovers = true;
    store.state.settings.showCodeOwnerTip = true;

    factory(true);

    expect(findCodeownersTip().exists()).toBe(true);
  });

  describe('with empty rules', () => {
    beforeEach(() => {
      store.modules.approvals.state.rules = [];
      factory();
    });

    it('does not render MR rules', () => {
      expect(findAllApprovalsTableNames()).toHaveLength(0);
    });

    it('renders hidden inputs', () => {
      expect(findHiddenInputs().exists()).toBe(true);
    });
  });

  describe('with rules', () => {
    beforeEach(() => {});

    it('renders MR rules', () => {
      store.modules.approvals.state.rules = [{ id: 7, approvers: [] }];

      factory();
      expect(findAllApprovalsTableNames()).toHaveLength(1);
    });

    it('renders hidden inputs', () => {
      store.modules.approvals.state.rules = [{ id: 7, approvers: [] }];

      factory();
      expect(findHiddenInputs().exists()).toBe(true);
    });

    describe('summary text', () => {
      it('optional approvals', () => {
        store.modules.approvals.state.rules = [];
        factory(true, true);

        expect(findSummaryText().text()).toEqual('Approvals are optional.');
      });

      it('multiple optional approval rules', () => {
        store.modules.approvals.state.rules = [
          { ruleType: 'any_approver', approvalsRequired: 0 },
          { ruleType: 'regular', approvalsRequired: 0, approvers: [] },
        ];
        factory(true, true);

        expect(findSummaryText().text()).toEqual('Approvals are optional.');
      });

      it('anyone can approve', () => {
        store.modules.approvals.state.rules = [
          {
            ruleType: 'any_approver',
            approvalsRequired: 1,
          },
        ];
        factory(true, true);

        expect(findSummaryText().text()).toEqual(
          '1 member must approve to merge. Anyone with role Developer or higher can approve.',
        );
      });

      it('2 required approval', () => {
        store.modules.approvals.state.rules = [
          {
            ruleType: 'any_approver',
            approvalsRequired: 1,
          },
          {
            ruleType: 'regular',
            approvalsRequired: 1,
            approvers: [],
          },
        ];
        factory(true, true);

        expect(findSummaryText().text()).toEqual(
          '2 approval rules require eligible members to approve before merging.',
        );
      });

      it('multiple required approval', () => {
        store.modules.approvals.state.rules = [
          {
            ruleType: 'any_approver',
            approvalsRequired: 1,
          },
          {
            ruleType: 'regular',
            approvalsRequired: 1,
            approvers: [],
          },
          {
            ruleType: 'regular',
            approvalsRequired: 2,
            approvers: [],
          },
        ];
        factory(true, true);

        expect(findSummaryText().text()).toEqual(
          '3 approval rules require eligible members to approve before merging.',
        );
      });
    });
  });
});
