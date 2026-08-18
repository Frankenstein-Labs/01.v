<script>
import { GlButton, GlIcon, GlSprintf, GlSkeletonLoader, GlBadge } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import memberRolePermissionsQuery from '../../graphql/member_role_permissions.query.graphql';
import adminRolePermissionsQuery from '../../graphql/admin_role/role_permissions.query.graphql';
import { isCustomRole, isAdminRole, isPermissionPreselected } from '../../utils';

export default {
  name: 'RoleDetailsContent',
  i18n: {
    badgeText: s__('MemberRole|Added from %{role}'),
  },
  components: { GlButton, GlIcon, GlSprintf, GlSkeletonLoader, GlBadge, SettingsSection },
  props: {
    role: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      allPermissions: [],
    };
  },
  apollo: {
    allPermissions: {
      query() {
        return this.isAdminRole ? adminRolePermissionsQuery : memberRolePermissionsQuery;
      },
      variables: { includeDescription: false },
      update(data) {
        return data.memberRolePermissions.nodes.map((permission) => {
          const isPreselected = isPermissionPreselected(
            permission,
            this.role.baseAccessLevel?.stringValue,
          );

          return {
            ...permission,
            checked: this.enabledPermissions.has(permission.value) || isPreselected,
            isPreselected,
          };
        });
      },
      error() {
        createAlert({ message: s__('MemberRole|Could not fetch available permissions.') });
      },
      skip() {
        // Default roles don't have custom permissions, so don't fetch the available permissions.
        return this.isDefaultRole;
      },
    },
  },
  computed: {
    enabledPermissions() {
      return new Set(this.role.enabledPermissions.nodes.map(({ value }) => value));
    },
    checkedPermissionsCount() {
      return this.allPermissions.filter(({ checked }) => checked).length;
    },
    isDefaultRole() {
      return !this.isCustomRole && !this.isAdminRole;
    },
    isCustomRole() {
      return isCustomRole(this.role);
    },
    isAdminRole() {
      return isAdminRole(this.role);
    },
    idLabel() {
      return this.isCustomRole || this.isAdminRole
        ? s__('MemberRole|Role ID')
        : s__('MemberRole|Access level');
    },
    roleId() {
      // Custom roles should show the custom role ID. Base roles don't have an ID, so show the access level instead.
      return getIdFromGraphQLId(this.role.id) || this.role.accessLevel;
    },
    roleType() {
      if (this.isCustomRole) {
        return __('Custom');
      }
      if (this.isAdminRole) {
        return s__('MemberRole|Custom admin role');
      }

      return s__('MemberRole|Default');
    },
  },
  userPermissionsDocsPath: helpPagePath('user/permissions'),
};
</script>
<template>
  <div>
    <settings-section :heading="__('General')">
      <dl class="gl-mb-0">
        <dt data-testid="id-header">{{ idLabel }}</dt>
        <dd class="gl-text-subtle" data-testid="id-value">{{ roleId }}</dd>
        <dt data-testid="type-header">{{ s__('MemberRole|Role type') }}</dt>
        <dd class="gl-text-subtle" data-testid="type-value">{{ roleType }}</dd>

        <dt data-testid="description-header">{{ __('Description') }}</dt>
        <dd class="gl-mb-0 gl-leading-20 gl-text-subtle" data-testid="description-value">
          {{ role.description }}
        </dd>
      </dl>
    </settings-section>

    <settings-section :heading="__('Permissions')">
      <dl class="gl-mb-0">
        <dt v-if="isCustomRole" data-testid="base-role-header">
          {{ s__('MemberRole|Base role') }}
        </dt>
        <dd v-if="isCustomRole || isDefaultRole" class="gl-flex gl-gap-x-5 gl-text-subtle">
          <span v-if="isCustomRole" data-testid="base-role-value">
            {{ role.baseAccessLevel.humanAccess }}
          </span>
          <gl-button
            :href="$options.userPermissionsDocsPath"
            icon="external-link"
            variant="link"
            target="_blank"
            data-testid="view-permissions-button"
          >
            {{ s__('MemberRole|View permissions') }}
          </gl-button>
        </dd>

        <template v-if="isCustomRole || isAdminRole">
          <dt data-testid="custom-permissions-header">
            {{ s__('MemberRole|Custom permissions') }}
          </dt>
          <dd
            v-if="allPermissions.length"
            class="gl-text-subtle"
            data-testid="custom-permissions-value"
          >
            <gl-sprintf :message="s__('MemberRole|%{count} of %{total} permissions added')">
              <template #count>{{ checkedPermissionsCount }}</template>
              <template #total>{{ allPermissions.length }}</template>
            </gl-sprintf>
          </dd>

          <div class="gl-mt-5 gl-flex gl-flex-col gl-gap-y-3" data-testid="custom-permissions-list">
            <gl-skeleton-loader v-if="$apollo.queries.allPermissions.loading" />
            <div
              v-for="permission in allPermissions"
              :key="permission.value"
              :data-testid="`permission-${permission.value}`"
              :class="{ 'gl-text-subtle': !permission.checked }"
            >
              <gl-icon v-if="permission.checked" name="check-sm" variant="success" />
              <gl-icon v-else name="merge-request-close-m" variant="disabled" />

              <span class="gl-ml-2">{{ permission.name }}</span>
              <gl-badge v-if="permission.isPreselected" variant="info" class="-gl-my-1 gl-ml-2">
                <gl-sprintf :message="$options.i18n.badgeText">
                  <template #role>{{ role.baseAccessLevel.humanAccess }}</template>
                </gl-sprintf>
              </gl-badge>
            </div>
          </div>
        </template>
      </dl>
    </settings-section>
  </div>
</template>
