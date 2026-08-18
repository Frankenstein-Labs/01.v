<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import UserTypeSelectorCe, {
  USER_TYPE_REGULAR,
  USER_TYPE_ADMIN,
} from '~/admin/users/components/user_type/user_type_selector.vue';
import RegularAccessSummary from '~/admin/users/components/user_type/regular_access_summary.vue';
import AdminAccessSummary from '~/admin/users/components/user_type/admin_access_summary.vue';
import { s__ } from '~/locale';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import { LDAP_TAB_QUERYSTRING_VALUE } from 'ee/roles_and_permissions/components/role_tabs.vue';
import AuditorAccessSummary from './auditor_access_summary.vue';
import AdminRoleDropdown from './admin_role_dropdown.vue';

export const USER_TYPE_AUDITOR = {
  value: 'auditor',
  text: s__('AdminUsers|Auditor'),
  description: s__(
    'AdminUsers|Read-only access to all groups and projects. No access to the Admin area by default.',
  ),
};

export default {
  name: 'UserTypeSelectorEE',
  components: {
    UserTypeSelectorCe,
    AdminRoleDropdown,
    RegularAccessSummary,
    AuditorAccessSummary,
    AdminAccessSummary,
    GlAlert,
    GlSprintf,
    GlLink,
  },
  mixins: [glLicensedFeaturesMixin()],
  inject: ['manageRolesPath'],
  props: {
    userType: {
      type: String,
      required: true,
    },
    isCurrentUser: {
      type: Boolean,
      required: true,
    },
    licenseAllowsAuditorUser: {
      type: Boolean,
      required: true,
    },
    adminRole: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      currentUserType: this.userType,
    };
  },
  computed: {
    isRegularSelected() {
      return this.currentUserType === USER_TYPE_REGULAR.value;
    },
    isAuditorSelected() {
      return this.currentUserType === USER_TYPE_AUDITOR.value;
    },
    isAdminSelected() {
      return this.currentUserType === USER_TYPE_ADMIN.value;
    },
    userTypes() {
      return this.licenseAllowsAuditorUser
        ? [USER_TYPE_REGULAR, USER_TYPE_AUDITOR, USER_TYPE_ADMIN]
        : [USER_TYPE_REGULAR, USER_TYPE_ADMIN];
    },
    shouldShowAdminRoleDropdown() {
      return (
        this.glLicensedFeatures.customRoles && (this.isRegularSelected || this.isAuditorSelected)
      );
    },
    shouldShowLdapAlert() {
      return Boolean(this.shouldShowAdminRoleDropdown && this.adminRole?.ldap);
    },
    manageLdapSyncUrl() {
      return `${this.manageRolesPath}?tab=${LDAP_TAB_QUERYSTRING_VALUE}`;
    },
  },
};
</script>

<template>
  <user-type-selector-ce
    :user-type="userType"
    :is-current-user="isCurrentUser"
    :user-types="userTypes"
    @access-change="currentUserType = $event"
  >
    <template v-if="shouldShowAdminRoleDropdown" #description>
      <p class="gl-mb-0 gl-text-subtle">
        {{ s__('AdminUsers|Review and set Admin area access with a custom admin role.') }}
      </p>
    </template>

    <gl-alert v-if="shouldShowLdapAlert" :dismissible="false" class="gl-mb-4">
      <gl-sprintf
        :message="
          s__(
            `AdminUsers|This user's access level is managed with LDAP. Remove user's mapping or change group's role in %{linkStart}LDAP synchronization%{linkEnd} to modify access.`,
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="manageLdapSyncUrl">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <regular-access-summary v-if="isRegularSelected">
      <admin-role-dropdown
        v-if="shouldShowAdminRoleDropdown"
        :role="adminRole"
        class="gl-ml-1 gl-mt-2"
      />
    </regular-access-summary>

    <auditor-access-summary v-else-if="isAuditorSelected">
      <admin-role-dropdown
        v-if="shouldShowAdminRoleDropdown"
        :role="adminRole"
        class="gl-ml-1 gl-mt-2"
      />
    </auditor-access-summary>

    <admin-access-summary v-else-if="isAdminSelected" />
  </user-type-selector-ce>
</template>
