<script>
import { isEqual } from 'lodash-es';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { I18N_ROLE_SAVE_SUCCESS, I18N_ROLE_SAVE_ERROR } from '~/members/constants';
import { MEMBERS_TAB_TYPES } from 'ee/members/constants';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { callRoleUpdateApi, setMemberRole, ldapRole } from './utils';
import GuestOverageConfirmation from './guest_overage_confirmation.vue';

export default {
  name: 'RoleUpdater',
  components: { GuestOverageConfirmation },
  mixins: [glSlotsMixin],
  inject: ['context', 'group', 'project'],
  props: {
    member: {
      type: Object,
      required: true,
    },
    role: {
      type: Object,
      required: true,
    },
  },
  emits: ['alert', 'busy', 'reset'],
  computed: {
    isLdapUser() {
      return this.member.canOverride;
    },
    isLdapUserRoleSynced() {
      return this.isLdapUser && !this.member.isOverridden;
    },
    isLdapRoleSelected() {
      return isEqual(this.role, ldapRole);
    },
  },
  watch: {
    role() {
      // If the user is currently synced to the LDAP role but the selected role is different, show an override warning.
      if (this.isLdapUserRoleSynced && !this.isLdapRoleSelected) {
        this.emitAlert({
          variant: 'warning',
          dismissible: false,
          message: s__(
            'MemberRole|This member is an LDAP user. Changing their role will override the settings from the LDAP group sync.',
          ),
        });
      }
    },
  },
  methods: {
    async saveRole() {
      try {
        this.emitBusy(true);
        this.emitAlert(null);

        if (this.isLdapUser) {
          await this.saveLdapRole();
        } else {
          await this.saveStandardRole();
        }
      } catch (error) {
        captureException(error);
        this.emitAlert({
          message: error.response?.data?.message || I18N_ROLE_SAVE_ERROR,
          variant: 'danger',
          dismissible: false,
        });
      } finally {
        this.emitBusy(false);
      }
    },
    async saveLdapRole() {
      const { member } = this;
      // If the LDAP role was selected, lock the ability to change a member's role.
      if (this.isLdapRoleSelected) {
        await this.setLdapOverride(false);
        member.isOverridden = false;
        this.emitAlert({
          variant: 'info',
          message: s__(
            'MemberRole|Reverted to LDAP group sync settings. The role will be updated after the next LDAP sync.',
          ),
        });
      } else {
        // If the user is using the LDAP sync role and we're changing it, unlock the ability to change the role first.
        if (this.isLdapUserRoleSynced) {
          await this.setLdapOverride(true);
        }
        // Save the role as usual.
        await this.saveStandardRole();
        member.isOverridden = true;
      }
    },
    async setLdapOverride(override) {
      return axios.patch(this.member.ldapOverridePath, { group_member: { override } });
    },
    async saveStandardRole() {
      const { member, role } = this;
      const { data } = await callRoleUpdateApi(member, role);
      // At this point the role has not been changed yet, but was enqueued for approval, in this
      // case we restore the role to it's initial state in the UI.
      if (data?.enqueued) {
        this.emitReset();
        this.emitAlert({
          message: s__('Members|Role change request was sent to the administrator.'),
          variant: 'info',
        });
      } else {
        setMemberRole(member, role);
        // If the backend provided license info, update the member. This will show/hide the "Is using seat" badge.
        if (data?.using_license !== undefined) {
          member.usingLicense = data?.using_license;
        }

        this.emitAlert({ message: I18N_ROLE_SAVE_SUCCESS, variant: 'success' });
      }

      // In either case if a role was changed or enqueued for promotion — we need to update the
      // Promotion requests tab data.
      if (this.$store.hasModule(MEMBERS_TAB_TYPES.promotionRequest)) {
        const { context, group, project } = this;
        this.$store.dispatch(
          // eslint-disable-next-line @gitlab/no-hardcoded-urls -- False positive, Vuex action path, not a URL
          `${MEMBERS_TAB_TYPES.promotionRequest}/invalidatePromotionRequestsData`,
          { context, group, project },
          { root: true },
        );
      }
    },
    emitAlert(alert) {
      this.$emit('alert', alert);
    },
    emitBusy(isBusy) {
      this.$emit('busy', isBusy);
    },
    emitReset() {
      this.$emit('reset');
    },
  },
};
</script>

<template>
  <guest-overage-confirmation
    :group-path="group.path"
    :member="member"
    :role="role"
    @busy="emitBusy"
    @confirm="saveRole"
    @cancel="emitReset"
  >
    <template v-if="glSlots().default" #default="{ checkOverage }">
      <slot :save-role="checkOverage"></slot>
    </template>
  </guest-overage-confirmation>
</template>
