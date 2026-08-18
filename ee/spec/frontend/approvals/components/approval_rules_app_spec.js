import { GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import DrawerRuleCreate from 'ee/approvals/components/rule_drawer/create_rule.vue';
import ModalRuleRemove from 'ee/approvals/components/rule_modal/remove_rule.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import settingsModule from 'ee/approvals/stores/modules/project_settings';
import showToast from '~/vue_shared/plugins/global_toast';

jest.mock('~/vue_shared/plugins/global_toast');

Vue.use(Vuex);

const TEST_RULES_CLASS = 'js-fake-rules';
const APP_PREFIX = 'lorem-ipsum';

describe('EE Approvals App', () => {
  let store;
  let wrapper;
  let slots;

  const targetBranchName = 'development';
  const factory = (propsData = {}) => {
    wrapper = shallowMountExtended(ApprovalRulesApp, {
      slots,
      store: new Vuex.Store(store),
      propsData,
      stubs: {
        CrudComponent,
      },
    });
  };

  const findAddButton = () => wrapper.findComponentByTestId('add-approval-rule');
  const findResetButton = () => wrapper.findComponentByTestId('reset-to-defaults');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRules = () => wrapper.find(`.${TEST_RULES_CLASS}`);
  const findRulesCount = () => wrapper.findByTestId('crud-count');
  const findRulesCountIcon = () => wrapper.findComponentByTestId('crud-icon');
  const findRuleCreateDrawer = () => wrapper.findComponent(DrawerRuleCreate);

  beforeEach(() => {
    slots = {
      rules: `<div class="${TEST_RULES_CLASS}">These are the rules!</div>`,
    };

    store = createStoreOptions(
      { approvals: settingsModule() },
      {
        canEdit: true,
        prefix: APP_PREFIX,
      },
    );

    store.modules.approvals.actions = {
      fetchRules: jest.fn().mockResolvedValue(),
      openCreateDrawer: jest.fn().mockResolvedValue(),
      closeCreateDrawer: jest.fn().mockResolvedValue(),
    };

    store.modules.approvals.state.targetBranch = targetBranchName;

    jest.spyOn(store.modules.approvals.actions, 'fetchRules');
    jest.spyOn(store.modules.approvals.actions, 'openCreateDrawer');
    jest.spyOn(store.modules.approvals.actions, 'closeCreateDrawer');
  });

  describe('targetBranch', () => {
    it('passes the target branch name in fetchRules for MR create path', () => {
      store.state.settings.prefix = 'mr-edit';
      store.state.settings.mrSettingsPath = null;
      factory();

      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledWith(expect.anything(), {
        targetBranch: targetBranchName,
      });
    });

    it('passes the target branch name in fetchRules for MR edit path', () => {
      store.state.settings.prefix = 'mr-edit';
      store.state.settings.mrSettingsPath = 'some/path';
      factory();

      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledWith(expect.anything(), {
        targetBranch: targetBranchName,
      });
    });

    it('does not pass the target branch name in fetchRules for project settings path', () => {
      store.state.settings.prefix = 'project-settings';
      store.modules.approvals.state.targetBranch = null;
      factory();

      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledWith(expect.anything(), {
        targetBranch: null,
      });
    });
  });

  describe('when allow multi rule', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    it('dispatches fetchRules action on created', () => {
      expect(store.modules.approvals.actions.fetchRules).not.toHaveBeenCalled();

      factory();

      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledTimes(1);
    });

    it('renders create drawer', () => {
      factory();

      const drawer = findRuleCreateDrawer();

      expect(drawer.exists()).toBe(true);
    });

    it('renders delete modal', () => {
      factory();

      const modal = wrapper.findComponent(ModalRuleRemove);

      expect(modal.exists()).toBe(true);
      expect(modal.props('modalId')).toBe(`${APP_PREFIX}-approvals-remove-modal`);
    });

    describe('if not loaded', () => {
      beforeEach(() => {
        store.modules.approvals.state.hasLoaded = false;
      });

      it('shows loading icon', () => {
        store.modules.approvals.state.isLoading = false;
        factory();

        expect(findLoadingIcon().exists()).toBe(true);
      });
    });

    describe('if loaded and empty', () => {
      beforeEach(() => {
        store.modules.approvals.state = {
          hasLoaded: true,
          rules: [],
          isLoading: false,
          drawerOpen: false,
        };
      });

      it('shows the empty rules count', () => {
        factory();

        expect(findRulesCount().text()).toBe('0');
      });

      it('shows the correct rules count icon', () => {
        factory();

        expect(findRulesCountIcon().exists()).toBe(true);
        expect(findRulesCountIcon().props('name')).toBe('approval');
      });

      it('does show Rules', () => {
        factory();

        expect(findRules().exists()).toBe(true);
      });

      it('does not show loading icon if not loading', () => {
        store.modules.approvals.state.isLoading = false;
        factory();

        expect(findLoadingIcon().exists()).toBe(false);
      });
    });

    describe('if not empty', () => {
      beforeEach(() => {
        store.modules.approvals.state.hasLoaded = true;
        store.modules.approvals.state.rules = [{ id: 1 }];
      });

      describe('shows the correct rules count', () => {
        it('when renders on the merge request edit page', () => {
          factory();

          expect(findRulesCount().text()).toBe('1');
        });

        it('when renders on the `Branch rule` project settings page', () => {
          store.modules.approvals.state.rulesPagination.total = 25;

          factory({ isBranchRulesEdit: true });

          expect(findRulesCount().text()).toBe('1');
        });

        it('when renders on the `Merge requests` project settings page', () => {
          store.modules.approvals.state.rulesPagination.total = 25;

          factory({ isMrEdit: false });

          expect(findRulesCount().text()).toBe('25');
        });
      });

      it('shows rules', () => {
        factory();

        expect(findRules().exists()).toBe(true);
      });

      it('renders add button', () => {
        factory();

        const button = findAddButton();

        expect(button.exists()).toBe(true);
        expect(button.text()).toBe('Add approval rule');
      });

      it('opens create drawer when add button is clicked', () => {
        factory();

        findAddButton().vm.$emit('click');

        expect(store.modules.approvals.actions.openCreateDrawer).toHaveBeenCalled();
      });

      it('closes the drawer when a close event is emitted', () => {
        factory();

        findRuleCreateDrawer().vm.$emit('close');

        expect(store.modules.approvals.actions.closeCreateDrawer).toHaveBeenCalled();
      });
    });
  });

  describe('when allow only single rule', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = false;
    });

    it('does not render add button', () => {
      factory();

      expect(findAddButton().exists()).toBe(false);
    });
  });

  describe('when resetting to project defaults', () => {
    const targetBranch = 'development';

    beforeEach(() => {
      store.state.settings.targetBranch = targetBranch;
      store.state.settings.prefix = 'mr-edit';
      store.state.settings.allowMultiRule = true;
      store.modules.approvals.state.hasLoaded = true;
      store.modules.approvals.state.rules = [{ id: 1 }];
    });

    it('calls fetchRules to reset to defaults', async () => {
      factory();

      findResetButton().vm.$emit('click');

      await nextTick();
      expect(store.modules.approvals.actions.fetchRules).toHaveBeenLastCalledWith(
        expect.anything(),
        { targetBranch, resetToDefault: true },
      );
      await waitForPromises();
      expect(showToast).toHaveBeenCalledWith('Approval rules reset to project defaults', {
        action: {
          text: 'Undo',
          onClick: expect.anything(),
        },
      });
    });
  });

  describe('when isBranchRulesEdit is set to `true`', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    it('does not call fetchRules', async () => {
      factory({ isBranchRulesEdit: true });

      await nextTick();
      expect(store.modules.approvals.actions.fetchRules).not.toHaveBeenCalled();
    });

    it('renders add button', () => {
      factory({ isBranchRulesEdit: true });

      const button = findAddButton();

      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Add approval rule');
    });
  });

  describe('description slot', () => {
    it('renders description slot content when provided', () => {
      const descriptionText = 'Custom description text';
      slots.description = `<div class="custom-description">${descriptionText}</div>`;

      factory();

      expect(wrapper.find('.custom-description').text()).toBe(descriptionText);
    });
  });
});
