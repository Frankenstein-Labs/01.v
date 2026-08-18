<script>
import { GlSprintf, GlLink, GlAlert } from '@gitlab/ui';
import { pull } from 'lodash-es';
import { helpPagePath } from '~/helpers/help_page_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { isPermissionPreselected } from '../../utils';
import memberPermissionsQuery from '../../graphql/member_role_permissions.query.graphql';
import adminPermissionsQuery from '../../graphql/admin_role/role_permissions.query.graphql';
import PermissionCategory from './permission_category.vue';
import {
  getPermissionsTree,
  getCustomPermissionsTreeTemplate,
  getAdminPermissionsTreeTemplate,
} from './utils';

export default {
  name: 'PermissionsSelector',
  components: { GlLink, GlSprintf, GlAlert, CrudComponent, PermissionCategory },
  inject: ['isAdminRole'],
  model: {
    prop: 'permissions',
    event: 'change',
  },
  props: {
    permissions: {
      type: Array,
      required: true,
    },
    isValid: {
      type: Boolean,
      required: true,
    },
    baseAccessLevel: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['change'],
  data() {
    return {
      availablePermissions: [],
    };
  },
  apollo: {
    availablePermissions: {
      query() {
        return this.isAdminRole ? adminPermissionsQuery : memberPermissionsQuery;
      },
      update(data) {
        return data.memberRolePermissions?.nodes || [];
      },
      error() {
        this.availablePermissions = [];
      },
    },
  },
  computed: {
    docsPath() {
      return helpPagePath('user/custom_roles/abilities');
    },
    isLoadingPermissions() {
      return this.$apollo.queries.availablePermissions.loading;
    },
    isErrorLoadingPermissions() {
      return !this.isLoadingPermissions && !this.hasAvailablePermissions;
    },
    hasAvailablePermissions() {
      return this.availablePermissions.length > 0;
    },
    parentPermissionsLookup() {
      return this.selectablePermissions.reduce((acc, { value, requirements }) => {
        const required = this.getSelectableValues(requirements);
        if (required?.length) {
          acc[value] = required;
        }

        return acc;
      }, {});
    },
    childPermissionsLookup() {
      return this.selectablePermissions.reduce((acc, { value, requirements }) => {
        this.getSelectableValues(requirements)?.forEach((requirement) => {
          // Create the array if it doesn't exist, then add the requirement to it.
          acc[requirement] = acc[requirement] || [];
          acc[requirement].push(value);
        });

        return acc;
      }, {});
    },
    permissionsList() {
      return this.availablePermissions.map((permission) => {
        const isPreselected = isPermissionPreselected(permission, this.baseAccessLevel);

        return {
          ...permission,
          checked: this.permissions.includes(permission.value) || isPreselected,
          disabled: isPreselected,
        };
      });
    },
    permissionsTree() {
      const template = this.isAdminRole
        ? getAdminPermissionsTreeTemplate()
        : getCustomPermissionsTreeTemplate();

      return getPermissionsTree(template, this.permissionsList);
    },
    selectablePermissions() {
      return this.permissionsList.filter((item) => !item.disabled);
    },
    selectablePermissionValues() {
      return new Set(this.selectablePermissions.map(({ value }) => value));
    },
    checkedPermissionsCount() {
      return this.permissionsList.filter(({ checked }) => checked).length;
    },
  },
  methods: {
    updatePermissions({ value }) {
      const selected = [...this.permissions];

      if (selected.includes(value)) {
        // Permission is being removed, remove it and deselect any child permissions.
        pull(selected, value);
        this.deselectChildPermissions(value, selected);
      } else {
        // Permission is being added, select it and select any parent permissions.
        selected.push(value);
        this.selectParentPermissions(value, selected);
      }

      this.emitPermissionsUpdate(selected);
    },
    emitPermissionsUpdate(permissions) {
      this.$emit('change', permissions);
    },
    selectParentPermissions(permission, selected) {
      const parentPermissions = this.parentPermissionsLookup[permission];

      parentPermissions?.forEach((parent) => {
        // Only select the parent permission if it's not selected. This prevents an infinite loop if there are
        // circular dependencies, i.e. A depends on B and B depends on A.
        if (!selected.includes(parent)) {
          selected.push(parent);
          this.selectParentPermissions(parent, selected);
        }
      });
    },
    deselectChildPermissions(permission, selected) {
      const childPermissions = this.childPermissionsLookup[permission];

      childPermissions?.forEach((child) => {
        // Only unselect the child permission if it's already selected. This prevents an infinite loop if there are
        // circular dependencies, i.e. A depends on B and B depends on A.
        if (selected.includes(child)) {
          pull(selected, child);
          this.deselectChildPermissions(child, selected);
        }
      });
    },
    getSelectableValues(values) {
      return values?.filter((value) => this.selectablePermissionValues.has(value));
    },
  },
};
</script>

<template>
  <crud-component
    :title="s__('MemberRole|Custom permissions')"
    class="gl-mb-5"
    title-class="gl-flex-wrap"
    :is-loading="$apollo.queries.availablePermissions.loading"
  >
    <template v-if="hasAvailablePermissions" #count>
      <span data-testid="permissions-selected-message">
        <gl-sprintf :message="s__('MemberRole|%{count} of %{total} permissions selected')">
          <template #count>{{ checkedPermissionsCount }}</template>
          <template #total>{{ availablePermissions.length }}</template>
        </gl-sprintf>
      </span>
    </template>

    <template v-if="!isAdminRole || !isValid" #description>
      <span v-if="!isAdminRole" data-testid="learn-more">
        <gl-sprintf
          :message="
            s__('MemberRole|Learn more about %{linkStart}available custom permissions%{linkEnd}.')
          "
        >
          <template #link="{ content }">
            <gl-link :href="docsPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </span>

      <p
        v-if="!isValid"
        class="gl-mb-0 gl-mt-2 gl-text-base gl-text-danger"
        data-testid="validation-message"
      >
        {{ s__('MemberRole|Select at least one permission.') }}
      </p>
    </template>

    <gl-alert v-if="isErrorLoadingPermissions" :dismissible="false" variant="danger">
      {{ s__('MemberRole|Could not fetch available permissions.') }}
    </gl-alert>

    <permission-category
      v-for="category in permissionsTree"
      v-else
      :key="category.name"
      :category="category"
      :base-access-level="baseAccessLevel"
      @change="updatePermissions"
    />
  </crud-component>
</template>
