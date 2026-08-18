<script>
import { GlTable, GlBadge, GlLoadingIcon, GlLink } from '@gitlab/ui';
import { ACCESS_LEVEL_SECURITY_MANAGER_INTEGER } from '~/access_level/constants';
import SecurityManagerNewBadge from '~/access_level/components/security_manager_new_badge.vue';
import { s__ } from '~/locale';
import { isCustomRole, isAdminRole } from '../../utils';
import RoleActions from './role_actions.vue';

export const TABLE_FIELDS = [
  { key: 'name', label: s__('MemberRole|Name'), tdClass: '@md/panel:gl-w-3/10' },
  { key: 'description', label: s__('MemberRole|Description') },
  {
    key: 'usersCount',
    label: s__('MemberRole|Direct users assigned'),
    thClass: 'gl-whitespace-nowrap gl-w-0',
    tdClass: 'gl-text-right',
  },
  {
    key: 'actions',
    label: s__('MemberRole|Actions'),
    thClass: 'gl-w-0',
    tdClass: 'gl-text-right',
  },
];

export default {
  name: 'RolesTable',
  components: { GlTable, GlBadge, GlLoadingIcon, GlLink, RoleActions, SecurityManagerNewBadge },
  props: {
    roles: {
      type: Array,
      required: true,
    },
    busy: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['delete-role'],
  methods: {
    isCustomRole,
    isAdminRole,
    isSecurityManagerRole({ accessLevel }) {
      return accessLevel === ACCESS_LEVEL_SECURITY_MANAGER_INTEGER;
    },
  },
  TABLE_FIELDS,
};
</script>

<template>
  <gl-table :fields="$options.TABLE_FIELDS" :items="roles" :busy="busy" stacked="md">
    <template #table-busy>
      <gl-loading-icon size="md" />
    </template>

    <template #cell(name)="{ item }">
      <div
        class="gl-flex gl-flex-wrap gl-items-center gl-justify-end gl-gap-3 @md/panel:gl-justify-start"
      >
        <gl-link :href="item.detailsPath">{{ item.name }}</gl-link>
        <gl-badge v-if="isCustomRole(item)">
          {{ s__('MemberRole|Custom member role') }}
        </gl-badge>
        <gl-badge v-else-if="isAdminRole(item)" icon="admin" variant="info">
          {{ s__('MemberRole|Custom admin role') }}
        </gl-badge>
        <security-manager-new-badge v-else-if="isSecurityManagerRole(item)" />
      </div>
    </template>

    <template #cell(description)="{ item: { description } }">
      <template v-if="description">{{ description }}</template>
      <span v-else class="gl-text-subtle">{{ s__('MemberRole|No description') }}</span>
    </template>

    <template #cell(actions)="{ item }">
      <role-actions class="-gl-m-3" :role="item" @delete="$emit('delete-role', item)" />
    </template>
  </gl-table>
</template>
