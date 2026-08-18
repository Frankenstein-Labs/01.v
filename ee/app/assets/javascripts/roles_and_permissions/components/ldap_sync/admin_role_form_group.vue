<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import adminRolesQuery from 'ee/admin/users/graphql/admin_roles.query.graphql';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';

export default {
  name: 'AdminRoleFormGroup',
  components: { GlFormGroup, GlCollapsibleListbox },
  props: {
    value: {
      type: String,
      required: false,
      default: null,
    },
    state: {
      type: Boolean,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['input'],
  data() {
    return {
      adminMemberRoles: [],
    };
  },
  apollo: {
    adminMemberRoles: {
      query: adminRolesQuery,
      update(data) {
        return data.adminMemberRoles.nodes.map((role) => ({
          value: role.id,
          text: role.name,
          description: role.description,
        }));
      },
      error() {
        createAlert({ message: s__('AdminUsers|Could not load custom admin roles.') });
      },
    },
  },
};
</script>

<template>
  <gl-form-group
    :label="s__('LDAP|Custom admin role')"
    :state="state"
    :invalid-feedback="__('This field is required')"
  >
    <gl-collapsible-listbox
      :selected="value"
      :items="adminMemberRoles"
      :loading="$apollo.queries.adminMemberRoles.loading"
      :disabled="disabled"
      category="secondary"
      :variant="state ? 'default' : 'danger'"
      :toggle-text="value ? '' : s__('MemberRole|Select a role')"
      class="gl-max-w-30"
      block
      @select="$emit('input', $event)"
    >
      <template #list-item="{ item }">
        <div class="gl-line-clamp-2 gl-font-bold">{{ item.text }}</div>
        <div class="gl-mt-1 gl-line-clamp-2 gl-text-sm gl-text-subtle">{{ item.description }}</div>
      </template>
    </gl-collapsible-listbox>
  </gl-form-group>
</template>
