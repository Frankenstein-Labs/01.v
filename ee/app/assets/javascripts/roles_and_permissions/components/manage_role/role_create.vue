<script>
import createMemberRoleMutation from 'ee/roles_and_permissions/graphql/create_member_role.mutation.graphql';
import createAdminRoleMutation from 'ee/roles_and_permissions/graphql/admin_role/create_role.mutation.graphql';
import { s__, sprintf } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import RoleForm from './role_form.vue';

export default {
  name: 'RoleCreate',
  components: { RoleForm },
  inject: ['isAdminRole'],
  props: {
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    listPagePath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isSubmitting: false,
      alert: null,
    };
  },
  computed: {
    titleText() {
      return this.isAdminRole
        ? s__('MemberRole|Create admin role')
        : s__('MemberRole|Create member role');
    },
  },
  methods: {
    async saveRole(input) {
      try {
        this.alert?.dismiss();
        this.isSubmitting = true;

        const { data } = await this.$apollo.mutate({
          mutation: this.isAdminRole ? createAdminRoleMutation : createMemberRoleMutation,
          variables: { ...input, groupPath: this.groupFullPath },
        });

        const error = data.memberRoleCreate.errors[0];
        if (error) {
          this.showError(sprintf(s__('MemberRole|Failed to create role: %{error}'), { error }));
        } else {
          this.goToPreviousPage();
        }
      } catch {
        this.showError(s__('MemberRole|Failed to create role.'));
      }
    },
    showError(message) {
      this.isSubmitting = false;
      this.alert = createAlert({ message });
    },
    goToPreviousPage() {
      visitUrl(this.listPagePath);
    },
  },
};
</script>

<template>
  <role-form
    :title="titleText"
    :submit-text="s__('MemberRole|Create role')"
    :busy="isSubmitting"
    :show-base-role="!isAdminRole"
    @submit="saveRole"
    @cancel="goToPreviousPage"
  />
</template>
