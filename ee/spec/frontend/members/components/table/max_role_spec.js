import { GlCollapsibleListbox, GlListboxItem, GlBadge } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import LdapDropdownFooter from 'ee/members/components/action_dropdowns/ldap_dropdown_footer.vue';
import ManageRolesDropdownFooter from 'ee/members/components/action_dropdowns/manage_roles_dropdown_footer.vue';
import { guestOverageConfirmAction } from 'ee/members/guest_overage_confirm_action';
import waitForPromises from 'helpers/wait_for_promises';
import MaxRole from '~/members/components/table/max_role.vue';
import { MEMBERS_TAB_TYPES } from '~/members/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { upgradedMember as member } from '../../mock_data';

Vue.use(Vuex);

jest.mock('ee/members/guest_overage_confirm_action');
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/logger');
guestOverageConfirmAction.mockResolvedValue(true);

describe('MaxRole', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let actions;

  const createStore = ({ updateMemberRoleReturn = () => Promise.resolve({ data: {} }) } = {}) => {
    actions = {
      updateMemberRole: jest.fn(() => updateMemberRoleReturn()),
    };

    return new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: { namespaced: true, actions },
      },
    });
  };

  const createComponent = (propsData = {}, store = createStore()) => {
    wrapper = mountExtended(MaxRole, {
      provide: {
        namespace: MEMBERS_TAB_TYPES.user,
        group: {
          name: 'groupname',
          path: '/grouppath/',
        },
      },
      propsData: {
        member,
        permissions: { canUpdate: true },
        ...propsData,
      },
      store,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });

    return waitForPromises();
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findListboxItems = () => wrapper.findAllComponents(GlListboxItem);
  const findListboxItemByText = (text) =>
    findListboxItems().wrappers.find((item) => item.text().includes(text));
  const findRoleText = () => wrapper.findByTestId('role-text');

  describe('when a member has custom permissions', () => {
    beforeEach(() => {
      createComponent({
        permissions: {
          canUpdate: false,
        },
      });
    });

    it('renders role text and a custom role badge', () => {
      expect(findRoleText().text()).toBe('custom role 1');

      expect(findBadge().exists()).toBe(true);
      expect(findBadge().text()).toBe('Custom role');
    });

    it('renders a tooltip', () => {
      const tooltip = getBinding(findRoleText().element, 'gl-tooltip');
      expect(tooltip).toBeDefined();
      expect(tooltip.value).toBe('custom role 1 description');
    });
  });

  describe('when member does not have custom permissions', () => {
    const myError = new Error('error');

    beforeEach(async () => {
      await createComponent(
        {
          member: {
            ...member,
            accessLevel: { integerValue: 50, stringValue: 'Owner', memberRoleId: null },
          },
        },
        createStore({ updateMemberRoleReturn: () => Promise.reject(myError) }),
      );
    });

    it('does not render a custom role badge', () => {
      expect(findBadge().exists()).toBe(false);
    });

    describe('after unsuccessful role assignment', () => {
      beforeEach(async () => {
        findListboxItemByText('custom role 2').trigger('click');
        await waitForPromises();
      });

      it('logs error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(myError);
      });

      it('resets selected dropdown item', () => {
        expect(
          findListbox().find('[aria-selected=true] [data-testid="access-level-link"]').text(),
        ).toBe('Owner');
      });

      it('resets custom role badge', () => {
        expect(findBadge().exists()).toBe(false);
      });
    });
  });

  describe('when member has `canOverride` permissions', () => {
    describe('when member is overridden', () => {
      it('renders LDAP dropdown footer', async () => {
        await createComponent({
          permissions: {
            canUpdate: true,
            canOverride: true,
          },
          member: { ...member, isOverridden: true },
        });

        expect(wrapper.findComponent(LdapDropdownFooter).exists()).toBe(true);
      });
    });

    describe('when member is not overridden', () => {
      it('disables dropdown', () => {
        createComponent({
          permissions: {
            canUpdate: true,
            canOverride: true,
          },
          member: { ...member, isOverridden: false },
        });

        expect(findListbox().props('disabled')).toBeDefined();
      });
    });
  });

  describe('when member does not have `canOverride` permissions', () => {
    it('does not render LDAP dropdown footer', async () => {
      await createComponent({
        permissions: {
          canOverride: false,
        },
      });

      expect(wrapper.findComponent(LdapDropdownFooter).exists()).toBe(false);
    });
  });

  it('renders the ManageRolesDropdownFooter component', () => {
    createComponent();

    expect(wrapper.findComponent(ManageRolesDropdownFooter).exists()).toBe(true);
  });

  describe('when member has custom roles', () => {
    it('renders static and custom roles', () => {
      createComponent();

      expect(findListbox().props('items')[0].text).toBe('Default roles');
      expect(findListbox().props('items')[0].options).toHaveLength(
        Object.keys(member.validRoles).length,
      );
      expect(findListbox().props('items')[1].text).toBe('Custom roles');
      expect(findListbox().props('items')[1].options).toHaveLength(member.customRoles.length);
    });

    it('calls `updateMemberRole` Vuex action', async () => {
      createComponent();
      findListboxItemByText('custom role 2').trigger('click');
      await waitForPromises();

      expect(actions.updateMemberRole).toHaveBeenCalledWith(expect.any(Object), {
        memberId: member.id,
        accessLevel: 20,
        memberRoleId: 102,
      });
    });
  });

  describe('guestOverageConfirmAction', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('when guestOverageConfirmAction returns true', () => {
      beforeEach(async () => {
        guestOverageConfirmAction.mockResolvedValueOnce(true);
        findListboxItemByText('Reporter').trigger('click');
        await waitForPromises();
      });

      it('calls updateMemberRole', () => {
        expect(actions.updateMemberRole).toHaveBeenCalledWith(expect.any(Object), {
          memberId: member.id,
          accessLevel: 20,
        });
      });
    });

    describe('when guestOverageConfirmAction returns false', () => {
      beforeEach(async () => {
        guestOverageConfirmAction.mockResolvedValueOnce(false);
        findListboxItemByText('custom role 2').trigger('click');
        await waitForPromises();
      });

      it('does not call updateMemberRole', () => {
        expect(guestOverageConfirmAction).toHaveBeenCalledWith({
          oldAccessLevel: 10,
          newRoleName: 'Reporter',
          newMemberRoleId: 102,
          group: { name: 'groupname', path: '/grouppath/' },
          memberId: 238,
          memberType: 'user',
        });
        expect(actions.updateMemberRole).not.toHaveBeenCalled();
      });

      it('re-enables dropdown', () => {
        expect(findListbox().props('loading')).toBe(false);
      });
    });

    describe('when guestOverageConfirmAction fails', () => {
      beforeEach(() => {
        guestOverageConfirmAction.mockRejectedValue('error');
      });

      it('logs error to Sentry', async () => {
        findListboxItemByText('Developer').trigger('click');
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith('error');
      });
    });
  });
});
