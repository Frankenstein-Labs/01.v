import MockAxiosAdapter from 'axios-mock-adapter';
import { cloneDeep } from 'lodash-es';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import axios from '~/lib/utils/axios_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleUpdater from 'ee/members/components/table/drawer/role_updater.vue';
import {
  callRoleUpdateApi,
  setMemberRole,
  ldapRole,
} from 'ee/members/components/table/drawer/utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import GuestOverageConfirmation from 'ee/members/components/table/drawer/guest_overage_confirmation.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { CONTEXT_TYPE, MEMBERS_TAB_TYPES } from 'ee_else_ce/members/constants';
import { updateableCustomRoleMember, ldapMember, ldapOverriddenMember } from '../../../mock_data';

Vue.use(Vuex);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('ee/members/components/table/drawer/utils');

describe('Role updater EE', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const mockAxios = new MockAxiosAdapter(axios);
  const newRole = { accessLevel: 10, memberRoleId: 101 };

  const invalidatePromotionRequestsData = jest.fn();

  const createWrapper = ({
    member = updateableCustomRoleMember,
    role = newRole,
    slotContent = '',
  } = {}) => {
    const store = new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.promotionRequest]: {
          namespaced: true,
          state: { pagination: { totalItems: 0 } },
          actions: {
            invalidatePromotionRequestsData,
          },
        },
      },
    });

    wrapper = shallowMountExtended(RoleUpdater, {
      propsData: { member, role },
      provide: { context: CONTEXT_TYPE.PROJECT, group: { path: 'group/path' }, project: {} },
      slots: { default: slotContent },
      store,
    });
  };

  const findGuestOverageConfirmation = () => wrapper.findComponent(GuestOverageConfirmation);

  const createWrapperAndConfirmOverage = (options) => {
    createWrapper(options);
    findGuestOverageConfirmation().vm.$emit('confirm');

    return waitForPromises();
  };

  afterEach(() => {
    mockAxios.reset();
  });

  it('renders slot content', () => {
    const slotContent = '<span>slot content</span>';
    createWrapper({ slotContent });

    expect(wrapper.html()).toContain(slotContent);
  });

  describe('when save is started', () => {
    beforeEach(() => {
      // Return a promise that doesn't resolve to keep the state as loading.
      callRoleUpdateApi.mockReturnValue(new Promise(() => {}));
      createWrapperAndConfirmOverage();
    });

    it('emits busy = true event', () => {
      expect(wrapper.emitted('busy')).toHaveLength(1);
      expect(wrapper.emitted('busy')[0][0]).toBe(true);
    });

    it('emits alert event to clear alert', () => {
      expect(wrapper.emitted('alert')).toHaveLength(1);
      expect(wrapper.emitted('alert')[0][0]).toBe(null);
    });
  });

  describe('when save is finished', () => {
    beforeEach(() => {
      callRoleUpdateApi.mockResolvedValue({ data: null });
      return createWrapperAndConfirmOverage();
    });

    it('emits busy = false event', () => {
      expect(wrapper.emitted('busy')).toHaveLength(2);
      expect(wrapper.emitted('busy')[1][0]).toBe(false);
    });

    it('dispatches a promotion requests invalidation action', async () => {
      await waitForPromises();
      expect(invalidatePromotionRequestsData).toHaveBeenCalledWith(expect.anything(), {
        context: CONTEXT_TYPE.PROJECT,
        group: { path: 'group/path' },
        project: {},
      });
    });
  });

  describe('when save has an error', () => {
    const error = new Error();

    beforeEach(() => {
      callRoleUpdateApi.mockRejectedValue(error);
      return createWrapperAndConfirmOverage();
    });

    it('emits error alert', () => {
      expect(wrapper.emitted('alert')).toHaveLength(2);
      expect(wrapper.emitted('alert')[1][0]).toEqual({
        message: 'Could not update role.',
        variant: 'danger',
        dismissible: false,
      });
    });

    it('captures sentry exception', () => {
      expect(captureException).toHaveBeenCalledTimes(1);
      expect(captureException).toHaveBeenCalledWith(error);
    });

    it('emits busy = false event', () => {
      expect(wrapper.emitted('busy')).toHaveLength(2);
      expect(wrapper.emitted('busy')[1][0]).toBe(false);
    });
  });

  describe('when save has an error with a message', () => {
    const error = new Error();
    const message =
      "The member's email address is not allowed for this group. Check with your administrator.";
    error.response = {
      data: { message },
    };

    beforeEach(() => {
      callRoleUpdateApi.mockRejectedValue(error);
      createWrapper();
      wrapper.vm.saveRole();
    });

    it('emits error alert with that message', () => {
      expect(wrapper.emitted('alert')).toHaveLength(2);
      expect(wrapper.emitted('alert')[1][0]).toEqual({
        message,
        variant: 'danger',
        dismissible: false,
      });
    });
  });

  describe('guest overage confirmation', () => {
    beforeEach(createWrapper);

    it('renders guest overage confirmation', () => {
      expect(findGuestOverageConfirmation().props()).toEqual({
        groupPath: 'group/path',
        member: updateableCustomRoleMember,
        role: newRole,
      });
    });

    it('saves role when overage check passes', () => {
      findGuestOverageConfirmation().vm.$emit('confirm');

      expect(callRoleUpdateApi).toHaveBeenCalledTimes(1);
      expect(callRoleUpdateApi).toHaveBeenCalledWith(updateableCustomRoleMember, newRole);
    });

    it.each([true, false])('emits busy = %s event when overage check emits busy event', (busy) => {
      findGuestOverageConfirmation().vm.$emit('busy', busy);

      expect(wrapper.emitted('busy')).toHaveLength(1);
      expect(wrapper.emitted('busy')[0][0]).toBe(busy);
    });

    it('emits reset event when overage check is canceled', () => {
      findGuestOverageConfirmation().vm.$emit('cancel');

      expect(wrapper.emitted('reset')).toHaveLength(1);
    });
  });

  describe('standard member', () => {
    describe('when new role is saved', () => {
      beforeEach(() => {
        callRoleUpdateApi.mockResolvedValue({});
        return createWrapperAndConfirmOverage();
      });

      it('updates member', () => {
        expect(setMemberRole).toHaveBeenCalledTimes(1);
        expect(setMemberRole).toHaveBeenCalledWith(updateableCustomRoleMember, newRole);
      });

      it('emits success alert', () => {
        expect(wrapper.emitted('alert')).toHaveLength(2);
        expect(wrapper.emitted('alert')[1][0]).toEqual({
          message: 'Role was successfully updated.',
          variant: 'success',
        });
      });
    });

    describe('when role change is sent to administrator for approval', () => {
      beforeEach(() => {
        callRoleUpdateApi.mockResolvedValue({ data: { enqueued: true } });
        return createWrapperAndConfirmOverage();
      });

      it('emits reset event', () => {
        expect(wrapper.emitted('reset')).toHaveLength(1);
      });

      it('emits info alert', () => {
        expect(wrapper.emitted('alert')).toHaveLength(2);
        expect(wrapper.emitted('alert')[1][0]).toEqual({
          message: 'Role change request was sent to the administrator.',
          variant: 'info',
        });
      });
    });

    describe('when response has license usage data', () => {
      it.each([true, false])('updates "using license" to %s for member', async (usingLicense) => {
        callRoleUpdateApi.mockResolvedValue({ data: { using_license: usingLicense } });
        createWrapperAndConfirmOverage();
        await waitForPromises();

        expect(updateableCustomRoleMember.usingLicense).toBe(usingLicense);
      });
    });
  });

  describe('ldap member', () => {
    describe('LDAP override warning', () => {
      it('shows warning when user is synced to the LDAP role and a non-LDAP role is selected', async () => {
        createWrapper({ member: ldapMember, role: {} });
        await wrapper.setProps({ role: newRole });

        expect(wrapper.emitted('alert')).toHaveLength(1);
        expect(wrapper.emitted('alert')[0][0]).toEqual({
          variant: 'warning',
          dismissible: false,
          message:
            'This member is an LDAP user. Changing their role will override the settings from the LDAP group sync.',
        });
      });

      it.each`
        phrase                                                       | member                        | role
        ${'user is not a LDAP user'}                                 | ${updateableCustomRoleMember} | ${newRole}
        ${'user role is LDAP synced and LDAP sync role is selected'} | ${ldapMember}                 | ${ldapRole}
        ${'user role is overridden and LDAP sync role is selected'}  | ${ldapOverriddenMember}       | ${ldapRole}
        ${'user role is overridden and another role is selected'}    | ${ldapOverriddenMember}       | ${newRole}
      `('does not show warning when $phrase', async ({ member, role }) => {
        createWrapper({ member, role: {} });
        await wrapper.setProps({ role });

        expect(wrapper.emitted('alert')).toBeUndefined();
      });
    });

    describe('when role is overridden and LDAP role is saved', () => {
      const member = cloneDeep(ldapOverriddenMember);

      beforeEach(() => {
        mockAxios.onPatch(ldapMember.ldapOverridePath).replyOnce(HTTP_STATUS_OK);
        return createWrapperAndConfirmOverage({ member, role: ldapRole });
      });

      it('calls LDAP override API', () => {
        const expectedData = JSON.stringify({ group_member: { override: false } });

        expect(mockAxios.history.patch[0].data).toBe(expectedData);
      });

      it('sets member isOverridden to false', () => {
        expect(member.isOverridden).toBe(false);
      });

      it('emits info alert', () => {
        expect(wrapper.emitted('alert')).toHaveLength(2);
        expect(wrapper.emitted('alert')[1][0]).toEqual({
          variant: 'info',
          message:
            'Reverted to LDAP group sync settings. The role will be updated after the next LDAP sync.',
        });
      });
    });

    describe('when role is LDAP synced and another role is saved', () => {
      const member = cloneDeep(ldapMember);

      beforeEach(() => {
        mockAxios.onPatch(ldapMember.ldapOverridePath).replyOnce(HTTP_STATUS_OK);
        callRoleUpdateApi.mockResolvedValue({});
        return createWrapperAndConfirmOverage({ member });
      });

      it('calls LDAP override API', () => {
        const expectedData = JSON.stringify({ group_member: { override: true } });

        expect(mockAxios.history.patch[0].data).toBe(expectedData);
      });

      it('saves new role', () => {
        expect(callRoleUpdateApi).toHaveBeenCalledTimes(1);
      });

      it('sets member isOverridden to true', () => {
        expect(member.isOverridden).toBe(true);
      });
    });

    describe('when role is overridden and another role is saved', () => {
      const member = cloneDeep(ldapOverriddenMember);

      beforeEach(() => createWrapperAndConfirmOverage({ member, role: newRole }));

      it('does not call LDAP override API', () => {
        expect(mockAxios.history.patch).toHaveLength(0);
      });

      it('saves new role', () => {
        expect(callRoleUpdateApi).toHaveBeenCalledTimes(1);
      });

      it('sets member isOverridden to true', () => {
        expect(member.isOverridden).toBe(true);
      });
    });
  });
});
