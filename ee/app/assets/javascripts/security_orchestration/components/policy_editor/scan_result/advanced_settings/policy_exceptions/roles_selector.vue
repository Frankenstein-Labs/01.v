<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';

export default {
  i18n: {
    roleSelectorLabel: s__('ScanResultPolicy|Select role exceptions'),
    roleSelectorDescription: s__('ScanResultPolicy|Choose which roles can bypass this policy'),
  },
  name: 'RolesSelector',
  components: {
    GlFormGroup,
    RoleSelect,
  },
  props: {
    selectedRoles: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['error', 'set-roles'],
  methods: {
    isCustomRole(id) {
      return !Number.isNaN(parseInt(id, 10));
    },
    selectRoles({ role_approvers: roles = [] }) {
      const payload = roles.reduce(
        (acc, roleId) => {
          const isCustom = this.isCustomRole(roleId);
          const targetArray = isCustom ? 'custom_roles' : 'roles';
          const id = isCustom ? { id: roleId } : roleId;
          acc[targetArray].push(id);
          return acc;
        },
        { roles: [], custom_roles: [] },
      );

      this.$emit('set-roles', payload);
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <gl-form-group
      id="roles-list"
      class="gl-w-full"
      label-for="roles-list"
      :label="$options.i18n.roleSelectorLabel"
      :description="$options.i18n.roleSelectorDescription"
    >
      <role-select
        class="gl-w-full"
        :custom-dropdown-classes="['gl-flex-1']"
        :selected="selectedRoles"
        data-testid="roles-items"
        @error="$emit('error')"
        @select-items="selectRoles"
      />
    </gl-form-group>
  </div>
</template>
