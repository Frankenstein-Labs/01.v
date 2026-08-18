import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RuleControls from 'ee/approvals/components/rules/rule_controls.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import MREditModule from 'ee/approvals/stores/modules/mr_edit';

Vue.use(Vuex);

const TEST_RULE = { id: 10, name: 'test rule' };

describe('EE Approvals RuleControls', () => {
  let wrapper;
  let store;
  let actions;

  const factory = () => {
    wrapper = shallowMountExtended(RuleControls, {
      propsData: {
        rule: TEST_RULE,
      },
      store: new Vuex.Store(store),
    });
  };

  const findEditButton = () => wrapper.findComponentByTestId('edit-rule-button');
  const findDeleteButton = () => wrapper.findComponentByTestId('delete-rule-button');

  beforeEach(() => {
    store = createStoreOptions({ approvals: MREditModule() });
    ({ actions } = store.modules.approvals);
    ['requestEditRule', 'requestDeleteRule'].forEach((actionName) =>
      jest.spyOn(actions, actionName),
    );

    window.gon.features = {}; // mocked because we check `gon.features`in the Vuex actions
  });

  afterEach(() => delete window.gon.features);

  describe('when allow multi rule', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    describe('edit button', () => {
      beforeEach(() => {
        factory();
      });

      it('exists', () => {
        expect(findEditButton().exists()).toBe(true);
      });

      it('references correct rule name in aria-label', () => {
        expect(findEditButton().attributes('aria-label')).toBe('Edit test rule');
      });

      it('when click, opens create modal', () => {
        expect(store.modules.approvals.actions.requestEditRule).not.toHaveBeenCalled();

        findEditButton().vm.$emit('click');

        expect(store.modules.approvals.actions.requestEditRule).toHaveBeenCalledWith(
          expect.anything(),
          TEST_RULE,
        );
      });
    });

    describe('delete button', () => {
      beforeEach(() => {
        factory();
      });

      it('exists', () => {
        expect(findDeleteButton().exists()).toBe(true);
      });

      it('references correct rule name in aria-label', () => {
        expect(findDeleteButton().attributes('aria-label')).toBe('Delete test rule');
      });

      it('when click, opens delete modal', () => {
        expect(store.modules.approvals.actions.requestDeleteRule).not.toHaveBeenCalled();

        findDeleteButton().vm.$emit('click');

        expect(store.modules.approvals.actions.requestDeleteRule).toHaveBeenCalledWith(
          expect.anything(),
          TEST_RULE,
        );
      });
    });
  });

  describe('when allow only single rule', () => {
    beforeEach(() => {
      factory();
    });

    it('renders edit button', () => {
      expect(findEditButton().exists()).toBe(true);
    });

    it('does delete button', () => {
      expect(findDeleteButton().exists()).toBe(true);
    });
  });
});
