import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import RuleInput from 'ee/approvals/components/rules/rule_input.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import MREditModule from 'ee/approvals/stores/modules/mr_edit';

Vue.use(Vuex);

describe('Rule Input', () => {
  let wrapper;
  let store;

  const createComponent = (props = {}) => {
    wrapper = mount(RuleInput, {
      propsData: {
        rule: {
          approvalsRequired: 9,
          id: 5,
        },
        ...props,
      },
      store: new Vuex.Store(store),
    });
  };

  const findInput = () => wrapper.find('input');

  beforeEach(() => {
    store = createStoreOptions({ approvals: MREditModule() });
    store.state.settings.canEdit = true;

    store.modules.approvals.actions = {
      putRule: jest.fn(),
    };
  });

  afterEach(() => {
    store = null;
  });

  it('has value equal to the approvalsRequired', () => {
    createComponent();
    expect(Number(findInput().element.value)).toBe(9);
  });

  it('is disabled when settings cannot edit', () => {
    store.state.settings.canEdit = false;
    createComponent();

    expect(findInput().attributes().disabled).toBeDefined();
  });

  it('is not disabled when settings can edit', () => {
    createComponent();

    expect(findInput().attributes().disabled).not.toBeDefined();
  });

  it('has min equal to the minApprovalsRequired', () => {
    createComponent({
      rule: {
        minApprovalsRequired: 4,
      },
    });

    expect(Number(findInput().attributes().min)).toBe(4);
  });

  it('defaults min approvals required input to 0', () => {
    createComponent();
    delete wrapper.props().rule.approvalsRequired;
    expect(Number(findInput().attributes('min'))).toEqual(0);
  });

  it('dispatches putRule on change', async () => {
    const action = store.modules.approvals.actions.putRule;
    createComponent();
    findInput().setValue(wrapper.props().rule.approvalsRequired + 1);

    jest.runAllTimers();

    await nextTick();
    expect(action).toHaveBeenCalledWith(expect.anything(), { approvalsRequired: 10, id: 5 });
  });

  describe('on Branch rule details page', () => {
    it('is disabled when can edit settings is false', () => {
      store.state.settings.canEdit = false;
      createComponent({ isBranchRulesEdit: true });

      expect(findInput().attributes().disabled).toBeDefined();
    });

    it('is not disabled when can edit settings is true', () => {
      createComponent({ isBranchRulesEdit: true });

      expect(findInput().attributes().disabled).not.toBeDefined();
    });
  });
});
