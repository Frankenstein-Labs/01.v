<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';

export default {
  i18n: {
    userSelectorLabel: s__('ScanResultPolicy|Select user exceptions'),
    userSelectorDescription: s__('ScanResultPolicy|Choose which users can bypass this policy'),
  },
  name: `UsersSelector`,
  components: {
    GlFormGroup,
    UserSelect,
  },
  props: {
    selectedUsers: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['set-users'],
  computed: {
    selectedUsersIds() {
      return this.selectedUsers.map(({ id }) => id).filter(Boolean);
    },
  },
  methods: {
    setUsers({ user_approvers_ids: users = [] }) {
      this.$emit(
        'set-users',
        users.map((id) => ({ id })),
      );
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <gl-form-group
      id="users-list"
      class="gl-w-full"
      label-for="users-list"
      :label="$options.i18n.userSelectorLabel"
      :description="$options.i18n.userSelectorDescription"
    >
      <user-select :selected="selectedUsersIds" @select-items="setUsers" />
    </gl-form-group>
  </div>
</template>
