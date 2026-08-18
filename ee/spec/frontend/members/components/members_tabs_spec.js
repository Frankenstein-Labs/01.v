import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlButton } from '@gitlab/ui';
import { pagination } from 'ee_else_ce_jest/members/mock_data';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MembersApp from '~/members/components/app.vue';
import MembersTabs from '~/members/components/members_tabs.vue';
import { TABS } from 'ee_else_ce/members/tabs_metadata';
import { MEMBERS_TAB_TYPES, TAB_QUERY_PARAM_VALUES } from 'ee_else_ce/members/constants';
import setWindowLocation from 'helpers/set_window_location_helper';
import { groupDefaultProvide as promotionRequestsGroupDefaultProvide } from '../promotion_requests/mock_data';

describe('MembersTabs', () => {
  Vue.use(Vuex);

  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({ totalItems = 10 } = {}) => {
    const store = new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: {
          namespaced: true,
          state: {
            pagination: {
              ...pagination,
              totalItems,
            },
            filteredSearchBar: {
              searchParam: 'search',
            },
          },
        },
        [MEMBERS_TAB_TYPES.directMembers]: {
          namespaced: true,
          state: {
            pagination: {
              ...pagination,
              totalItems,
            },
          },
        },
        [MEMBERS_TAB_TYPES.promotionRequest]: {
          namespaced: true,
          state: {
            pagination: {
              ...pagination,
              totalItems,
            },
          },
        },
        [MEMBERS_TAB_TYPES.banned]: {
          namespaced: true,
          state: {
            pagination: {
              ...pagination,
              totalItems,
            },
          },
        },
      },
    });

    wrapper = mountExtended(MembersTabs, {
      store,
      stubs: ['members-app'],
      provide: {
        canManageMembers: true,
        canManageAccessRequests: true,
        canExportMembers: true,
        exportCsvPath: '',
        ...promotionRequestsGroupDefaultProvide,
      },
    });

    return nextTick();
  };

  const findTabs = () => wrapper.findAllByRole('tab').wrappers;
  const findTabByText = (text) => findTabs().find((tab) => tab.text().includes(text));
  const findActiveTab = () => wrapper.findByRole('tab', { selected: true });

  describe('when tabs have a count', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders tabs with count', () => {
      const tabs = findTabs();

      expect(tabs[0].text()).toBe('Members  10');
      expect(tabs[1].text()).toBe('Direct members  10');
      expect(tabs[2].text()).toBe('Role promotions  10');
      expect(tabs[3].text()).toBe('Banned  10');
      expect(findActiveTab().text()).toContain('Members');
    });

    it('renders `MembersApp` and passes `namespace` and `tabQueryParamValue` props', () => {
      const membersApps = wrapper.findAllComponents(MembersApp).wrappers;

      // `directMembers` is a lazy tab, so its `MembersApp` is not mounted until
      // the tab is activated.
      expect(membersApps[0].props('namespace')).toBe(MEMBERS_TAB_TYPES.user);
      expect(membersApps[1].props('namespace')).toBe(MEMBERS_TAB_TYPES.banned);
    });

    it('renders the custom component for Promotion Requests', async () => {
      const promotionsTabMeta = TABS.find(
        (tab) => tab.namespace === MEMBERS_TAB_TYPES.promotionRequest,
      );
      // the promotion-request-tab is lazy loaded, triggering the tab before checking the actual component
      await wrapper.findByTestId('promotion-request-tab').trigger('click');

      expect(wrapper.findComponent(promotionsTabMeta.component).exists()).toBe(true);
    });
  });

  describe('when tabs do not have a count', () => {
    it('only renders `Members` tab', async () => {
      await createComponent({ totalItems: 0 });

      expect(findTabByText('Members')).not.toBeUndefined();
      expect(findTabByText('Banned')).toBeUndefined();
    });
  });

  describe('hiding export button for pending promotion tab', () => {
    const findExportButton = () => wrapper.findComponent(GlButton);

    it('shows the export button when the active tab is not the pending promotion tab', async () => {
      await createComponent({ provide: { canExportMembers: true, exportCsvPath: 'foo' } });
      // ensuring the active tab is NOT the pending promotion tab
      expect(findActiveTab().text()).not.toContain('Role promotions');
      expect(findExportButton().exists()).toBe(true);
    });

    it('hides the export button when the active tab is the pending promotion tab', async () => {
      // activate the pending promotion tab
      setWindowLocation(`?tab=${TAB_QUERY_PARAM_VALUES.promotionRequest}`);
      await createComponent({ provide: { canExportMembers: true, exportCsvPath: 'foo' } });
      await nextTick();
      // ensure the current tab is the pending promotion tab
      expect(findActiveTab().text()).toContain('Role promotions');

      // ensure the export button is not shown
      expect(findExportButton().exists()).toBe(false);
    });
  });
});
