<script>
import { GlForm, GlButton } from '@gitlab/ui';
import ServerFormGroup from './server_form_group.vue';
import SyncMethodFormGroup, { GROUP_CN, USER_FILTER } from './sync_method_form_group.vue';
import GroupCnFormGroup from './group_cn_form_group.vue';
import UserFilterFormGroup from './user_filter_form_group.vue';
import AdminRoleFormGroup from './admin_role_form_group.vue';

export default {
  name: 'CreateSyncForm',
  components: {
    GlForm,
    GlButton,
    ServerFormGroup,
    SyncMethodFormGroup,
    GroupCnFormGroup,
    UserFilterFormGroup,
    AdminRoleFormGroup,
  },
  inject: ['ldapServers'],
  props: {
    busy: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['cancel', 'submit'],
  data() {
    return {
      server: this.ldapServers[0]?.value,
      syncMethod: null,
      groupCn: null,
      userFilter: '',
      roleId: null,
      isPrimaryValidationEnabled: false, // For server dropdown and sync method radios.
      isSecondaryValidationEnabled: false, // For group cn/user filter and admin role dropdown.
    };
  },
  computed: {
    isServerValid() {
      return !this.isPrimaryValidationEnabled || Boolean(this.server);
    },
    isSyncMethodValid() {
      return !this.isPrimaryValidationEnabled || Boolean(this.syncMethod);
    },
    isGroupCnSelected() {
      return this.syncMethod === GROUP_CN;
    },
    isUserFilterSelected() {
      return this.syncMethod === USER_FILTER;
    },
    isGroupCnValid() {
      return this.isSecondaryValidationEnabled && this.isGroupCnSelected
        ? Boolean(this.groupCn)
        : true;
    },
    isUserFilterValid() {
      return this.isSecondaryValidationEnabled && this.isUserFilterSelected
        ? this.userFilter.length > 0
        : true;
    },
    isRoleIdValid() {
      return !this.isSecondaryValidationEnabled || Boolean(this.roleId);
    },
  },
  watch: {
    server() {
      // Clear the selected group when the server is changed because the group may not exist on the
      // other server.
      this.groupCn = null;
    },
    syncMethod() {
      // Reset the validation for the group cn/user filter and admin role dropdown when the sync
      // method is changed.
      this.isSecondaryValidationEnabled = false;
    },
  },
  methods: {
    emitFormData() {
      this.isPrimaryValidationEnabled = true;
      this.isSecondaryValidationEnabled = true;

      if (
        this.isServerValid &&
        (this.isGroupCnValid || this.isUserFilterValid) &&
        this.isRoleIdValid
      ) {
        this.$emit('submit', {
          provider: this.server,
          ...(this.isGroupCnSelected ? { cn: this.groupCn } : {}),
          ...(this.isUserFilterSelected ? { filter: this.userFilter } : {}),
          adminMemberRoleId: this.roleId,
        });
      }
    },
  },
};
</script>

<template>
  <gl-form>
    <server-form-group v-model="server" :state="isServerValid" :disabled="busy" />
    <sync-method-form-group v-model="syncMethod" :state="isSyncMethodValid" :disabled="busy" />

    <template v-if="syncMethod">
      <group-cn-form-group
        v-if="isGroupCnSelected"
        v-model="groupCn"
        :state="isGroupCnValid"
        :server="server"
        :disabled="busy"
      />
      <user-filter-form-group
        v-else-if="isUserFilterSelected"
        v-model.trim="userFilter"
        :state="isUserFilterValid"
        :disabled="busy"
      />

      <admin-role-form-group v-model="roleId" :state="isRoleIdValid" :disabled="busy" />
    </template>

    <div class="gl-mt-7 gl-flex gl-flex-wrap gl-gap-3">
      <gl-button :disabled="busy" @click="$emit('cancel')">
        {{ __('Cancel') }}
      </gl-button>
      <gl-button variant="confirm" :loading="busy" @click="emitFormData">
        {{ __('Add') }}
      </gl-button>
    </div>
  </gl-form>
</template>
