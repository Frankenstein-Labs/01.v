<script>
import { GlSprintf, GlButton, GlDisclosureDropdown, GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import DeleteRoleModal from '../delete_role_modal.vue';
import RolesTable from '../roles_table/roles_table.vue';
import RolesExport from '../roles_table/roles_export.vue';

export default {
  name: 'RolesCrud',
  components: {
    GlSprintf,
    GlButton,
    GlDisclosureDropdown,
    RolesTable,
    DeleteRoleModal,
    RolesExport,
    CrudComponent,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin(), GlToastMixin],
  props: {
    roles: {
      type: Object,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    newRoleOptions: {
      type: Array,
      required: true,
    },
  },
  emits: ['deleted'],
  data() {
    return {
      roleToDelete: null,
    };
  },
  computed: {
    defaultRoles() {
      return this.roles?.standardRoles?.nodes;
    },
    customRoles() {
      return this.roles?.memberRoles?.nodes;
    },
    adminRoles() {
      return this.roles?.adminMemberRoles?.nodes;
    },
    rolesList() {
      return [
        ...(this.defaultRoles || []),
        ...(this.customRoles || []),
        ...(this.adminRoles || []),
      ];
    },
    canExportRoles() {
      // Check that the backend feature is enabled and that the current user can export members.
      return (
        this.glFeatures.membersPermissionsDetailedExport && this.glAbilities.exportGroupMemberships
      );
    },
  },
  methods: {
    processRoleDeletion() {
      this.roleToDelete = null;
      this.$toast.show(s__('MemberRole|Role successfully deleted.'));
      this.$emit('deleted');
    },
  },
  userPermissionsDocPath: helpPagePath('user/permissions'),
};
</script>

<template>
  <crud-component>
    <template #title>
      <div>
        {{ __('Roles') }}

        <div class="gl-ml-3 gl-inline-flex gl-gap-3 gl-text-sm gl-font-normal gl-text-subtle">
          <div v-if="defaultRoles">
            <gl-sprintf :message="s__('MemberRole|%{count} Default')">
              <template #count>
                <span class="gl-font-bold">{{ defaultRoles.length }}</span>
              </template>
            </gl-sprintf>
          </div>
          <div v-if="customRoles">
            <gl-sprintf :message="s__('MemberRole|%{count} Custom')">
              <template #count>
                <span class="gl-font-bold">{{ customRoles.length }}</span>
              </template>
            </gl-sprintf>
          </div>
          <div v-if="adminRoles">
            <gl-sprintf :message="s__('MemberRole|%{count} Admin')">
              <template #count>
                <span class="gl-font-bold">{{ adminRoles.length }}</span>
              </template>
            </gl-sprintf>
          </div>
        </div>
      </div>
    </template>

    <template #actions>
      <roles-export v-if="canExportRoles" />

      <gl-disclosure-dropdown
        v-if="newRoleOptions.length > 1"
        :items="newRoleOptions"
        :toggle-text="s__('MemberRole|New role')"
        placement="bottom-end"
        fluid-width
      >
        <template #list-item="{ item }">
          <div class="gl-mx-3 gl-w-34">
            <div class="gl-font-bold">{{ item.text }}</div>
            <div class="gl-mt-2 gl-text-subtle">{{ item.description }}</div>
          </div>
        </template>
      </gl-disclosure-dropdown>
      <gl-button
        v-else-if="newRoleOptions.length === 1"
        :href="newRoleOptions[0].href"
        size="small"
      >
        {{ s__('MemberRole|New role') }}
      </gl-button>
    </template>

    <roles-table :roles="rolesList" :busy="loading" @delete-role="roleToDelete = $event" />

    <delete-role-modal
      :role="roleToDelete"
      @deleted="processRoleDeletion"
      @close="roleToDelete = null"
    />
  </crud-component>
</template>
