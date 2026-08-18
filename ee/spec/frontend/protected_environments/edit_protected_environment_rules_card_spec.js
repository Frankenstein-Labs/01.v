import { GlButton } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { DEPLOYER_RULE_KEY } from 'ee/protected_environments/constants';
import EditProtectedEnvironmentRulesCard from 'ee/protected_environments/edit_protected_environment_rules_card.vue';
import { DEVELOPER_ACCESS_LEVEL } from './constants';

const DEFAULT_ENVIRONMENT = {
  deploy_access_levels: [{ access_level: DEVELOPER_ACCESS_LEVEL }, { group_id: 1 }, { user_id: 1 }],
};

describe('ee/protected_environments/edit_protected_environment_rules_card.vue', () => {
  let wrapper;

  const createComponent = ({
    ruleKey = DEPLOYER_RULE_KEY,
    loading = false,
    addButtonText = 'Add Deploy Rule',
    environment = DEFAULT_ENVIRONMENT,
    scopedSlots = {},
  } = {}) =>
    mountExtended(EditProtectedEnvironmentRulesCard, {
      propsData: {
        ruleKey,
        loading,
        addButtonText,
        environment,
      },
      scopedSlots,
    });

  describe('empty state slot', () => {
    it('exists when approval rules are empty', () => {
      wrapper = createComponent({
        environment: { deploy_access_levels: [] },
      });

      expect(wrapper.findByTestId('empty-state').exists()).toBe(true);
    });

    it('does not exist when approval rules are present', () => {
      wrapper = createComponent();

      expect(wrapper.findByTestId('empty-state').exists()).toBe(false);
    });
  });

  describe('table slot', () => {
    beforeEach(() => {
      wrapper = createComponent({
        scopedSlots: {
          table: '<span data-testid="table">table content</span>',
        },
      });
    });

    it('displays the slot', () => {
      expect(wrapper.findByTestId('table').text()).toBe('table content');
    });
  });

  describe('add button', () => {
    let text;
    let loading;
    let button;

    beforeEach(() => {
      text = 'Add Approval Rule';
      loading = true;
      wrapper = createComponent({ addButtonText: text, loading });
      button = wrapper.findComponent(GlButton);
    });

    it('passes the text to the button', () => {
      expect(button.text()).toBe(text);
    });

    it('passes the loading state to the button', () => {
      expect(button.props('loading')).toBe(loading);
    });

    it('emits the addRule event when clicked', () => {
      button.vm.$emit('click');

      expect(wrapper.emitted('add-rule')).toEqual([
        [{ environment: DEFAULT_ENVIRONMENT, ruleKey: DEPLOYER_RULE_KEY }],
      ]);
    });
  });
});
