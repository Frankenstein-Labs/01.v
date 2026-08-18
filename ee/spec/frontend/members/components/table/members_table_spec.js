import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  upgradedMember as memberMock,
  directMember,
  members,
  bannedMember,
} from 'ee_jest/members/mock_data';
import MembersTable from '~/members/components/table/members_table.vue';
import { MEMBERS_TAB_TYPES, TAB_QUERY_PARAM_VALUES } from '~/members/constants';
import RoleBadges from 'ee/members/components/table/role_badges.vue';
import UserLimitReachedAlert from 'ee/members/components/table/user_limit_reached_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(Vuex);

describe('MemberList', () => {
  let wrapper;

  const createStore = (state = {}) => {
    return new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: {
          namespaced: true,
          state: {
            members: [],
            memberPath: 'member/path/:id',
            tableFields: [],
            tableAttrs: {
              tr: { 'data-testid': 'member-row' },
            },
            pagination: {},
            ...state,
          },
        },
      },
    });
  };

  const createComponent = (state, props = {}) => {
    wrapper = mountExtended(MembersTable, {
      store: createStore(state),
      propsData: {
        tabQueryParamValue: TAB_QUERY_PARAM_VALUES.group,
        ...props,
      },
      provide: {
        sourceId: 1,
        currentUserId: 1,
        namespace: MEMBERS_TAB_TYPES.user,
        canManageMembers: true,
        group: {},
        canApproveAccessRequests: true,
        namespaceUserLimit: true,
        glFeatures: { showRoleDetailsInDrawer: true },
      },
      stubs: {
        MemberAvatar: true,
        MemberSource: true,
        ExpiresAt: true,
        CreatedAt: true,
        MemberActionButtons: true,
        MaxRole: true,
        DisableTwoFactorModal: true,
        RemoveGroupLinkModal: true,
        RemoveMemberModal: true,
        ExpirationDatepicker: true,
        LdapOverrideConfirmationModal: true,
      },
    });
    // Need this to await components imported using import('ee_component/...').
    return waitForPromises();
  };

  const findTableCellByMemberId = (tableCellLabel, memberId) =>
    wrapper
      .findByTestId(`members-table-row-${memberId}`)
      .find(`[data-label="${tableCellLabel}"][role="cell"]`);

  describe('fields', () => {
    describe('Max role field', () => {
      it('shows role badges component', async () => {
        await createComponent({ members: [memberMock], tableFields: ['maxRole'] });

        expect(wrapper.findComponent(RoleBadges).exists()).toBe(true);
      });
    });

    describe('"Actions" field', () => {
      const memberCanOverride = {
        ...directMember,
        canOverride: true,
      };

      const memberCanUnban = {
        ...bannedMember,
        canUnban: true,
      };

      const memberCanDisableTwoFactor = {
        ...memberMock,
        canDisableTwoFactor: true,
      };

      const memberNoPermissions = {
        ...memberMock,
        id: 2,
      };

      describe.each([
        ['canOverride', memberCanOverride],
        ['canUnban', memberCanUnban],
        ['canDisableTwoFactor', memberCanDisableTwoFactor],
      ])('when one of the members has `%s` permissions', (_, memberWithPermission) => {
        it('renders the "Actions" field', () => {
          createComponent({
            members: [memberNoPermissions, memberWithPermission],
            tableFields: ['actions'],
          });

          expect(wrapper.findByTestId('col-actions').exists()).toBe(true);

          expect(
            findTableCellByMemberId('Actions', memberNoPermissions.id).classes(),
          ).toStrictEqual([
            'col-actions',
            '!gl-hidden',
            '@lg/panel:!gl-table-cell',
            '!gl-align-middle',
          ]);
          expect(
            findTableCellByMemberId('Actions', memberWithPermission.id).classes(),
          ).toStrictEqual(['col-actions', '!gl-align-middle']);
        });
      });

      describe.each([['canOverride'], ['canUnban'], ['canDisableTwoFactor']])(
        'when none of the members has `%s` permissions',
        () => {
          it('does not render the "Actions" field', () => {
            createComponent({ members, tableFields: ['actions'] });

            expect(wrapper.findByTestId('col-actions').exists()).toBe(false);
          });
        },
      );
    });
  });

  describe('User limit reached alert', () => {
    it.each`
      phrase             | tabQueryParamValue                      | isShown
      ${'shows'}         | ${TAB_QUERY_PARAM_VALUES.accessRequest} | ${true}
      ${'does not show'} | ${TAB_QUERY_PARAM_VALUES.group}         | ${false}
    `('$phrase alert when the tab is $tab', async ({ tabQueryParamValue, isShown }) => {
      await createComponent({}, { tabQueryParamValue });

      expect(wrapper.findComponent(UserLimitReachedAlert).exists()).toBe(isShown);
    });
  });
});
