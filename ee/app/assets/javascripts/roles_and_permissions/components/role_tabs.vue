<script>
import { GlTabs, GlTab, GlSprintf, GlLink } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import InstanceRolesCrud from './roles_crud/instance_roles_crud.vue';
import SaasGroupRolesCrud from './roles_crud/saas_group_roles_crud.vue';
import SaasAdminRolesCrud from './roles_crud/saas_admin_roles_crud.vue';
import LdapSyncCrud from './ldap_sync/ldap_sync_crud.vue';

export const LDAP_TAB_QUERYSTRING_VALUE = 'ldap';

export default {
  name: 'RoleTabs',
  components: { PageHeading, GlTabs, GlTab, GlSprintf, GlLink, LdapSyncCrud },
  inject: ['ldapServers', 'groupFullPath'],
  props: {
    signInRestrictionsSettingsPath: {
      type: String,
      required: false,
      default: '',
    },
    isSaas: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    showTabs() {
      return Boolean(this.ldapServers);
    },
    crudType() {
      if (this.isSaas) {
        // If there's a groupFullPath, this is the top-level group roles and permissions page.
        // Otherwise, it's the admin area roles and permissions page.
        return this.groupFullPath ? SaasGroupRolesCrud : SaasAdminRolesCrud;
      }

      return InstanceRolesCrud;
    },
  },
  userPermissionsDocPath: helpPagePath('user/permissions'),
  LDAP_TAB_QUERYSTRING_VALUE,
};
</script>

<template>
  <div>
    <page-heading :heading="s__('MemberRole|Roles and permissions')">
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'MemberRole|Manage which actions users can take with %{linkStart}roles and permissions%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.userPermissionsDocPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </page-heading>

    <div
      v-if="signInRestrictionsSettingsPath"
      class="gl-mb-6 gl-rounded-base gl-bg-orange-50 gl-p-5"
      :class="{ '!gl-mb-3': showTabs }"
      data-testid="security-recommendation-alert"
    >
      <gl-sprintf
        :message="
          s__(
            'MemberRole|To enhance security, we recommend enabling %{adminModeLinkStart}Admin Mode%{adminModeLinkEnd} and %{mfaLinkStart}Enforce two-factor authentication for administrators%{mfaLinkEnd} when using custom admin roles. Admin Mode requires users to re-authenticate before accessing the Admin area.',
          )
        "
      >
        <template #adminModeLink="{ content }">
          <gl-link :href="signInRestrictionsSettingsPath">{{ content }}</gl-link>
        </template>
        <template #mfaLink="{ content }">
          <gl-link :href="signInRestrictionsSettingsPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>

    <gl-tabs v-if="showTabs" sync-active-tab-with-query-params>
      <gl-tab :title="__('Roles')" query-param-value="roles" lazy>
        <component :is="crudType" class="gl-mt-5" />
      </gl-tab>
      <gl-tab
        :title="__('LDAP Synchronization')"
        :query-param-value="$options.LDAP_TAB_QUERYSTRING_VALUE"
        lazy
      >
        <ldap-sync-crud class="gl-mt-5" />
      </gl-tab>
    </gl-tabs>

    <component :is="crudType" v-else class="gl-mt-5" />
  </div>
</template>
