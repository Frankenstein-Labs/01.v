<script>
import { s__, sprintf } from '~/locale';
import deleteMemberRoleMutation from 'ee/roles_and_permissions/graphql/delete_member_role.mutation.graphql';
import deleteAdminRoleMutation from 'ee/roles_and_permissions/graphql/admin_role/delete_role.mutation.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { isAdminRole } from '../utils';

export default {
  name: 'DeleteRoleModal',
  components: { ConfirmActionModal },
  props: {
    role: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['close', 'deleted'],
  methods: {
    async deleteRole() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: isAdminRole(this.role) ? deleteAdminRoleMutation : deleteMemberRoleMutation,
          variables: { id: convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.role.id) },
        });

        const error = data.memberRoleDelete.errors[0];

        if (error) {
          const message = sprintf(s__('MemberRole|Failed to delete role. %{error}'), { error });
          return Promise.reject(message);
        }

        this.$emit('deleted');
        return Promise.resolve();
      } catch {
        return Promise.reject(s__('MemberRole|Failed to delete role.'));
      }
    },
  },
};
</script>

<template>
  <confirm-action-modal
    v-if="role"
    modal-id="delete-role-modal"
    :title="s__('MemberRole|Delete role?')"
    :action-fn="deleteRole"
    :action-text="s__('MemberRole|Delete role')"
    @close="$emit('close')"
  >
    {{ s__('MemberRole|Are you sure you want to delete this role?') }}
  </confirm-action-modal>
</template>
