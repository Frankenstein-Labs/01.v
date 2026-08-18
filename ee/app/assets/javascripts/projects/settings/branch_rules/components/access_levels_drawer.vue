<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getProjectMemberRoles from 'ee/graphql_shared/queries/project_member_roles.query.graphql';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import AccessLevelsDrawerCe from '~/projects/settings/branch_rules/components/access_levels_drawer.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import CustomRolesCheckboxes from './custom_roles_checkboxes.vue';

export default {
  name: 'EEAccessLevelsDrawer',
  components: {
    AccessLevelsDrawerCe,
    CustomRolesCheckboxes,
  },
  mixins: [glListenersMixin],
  inject: {
    showEnterpriseAccessLevels: { default: false },
    customRolesForProtectedBranchesEnabled: { default: false },
  },
  inheritAttrs: false,
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      customRoles: [],
    };
  },
  computed: {
    customRolesEnabled() {
      return this.showEnterpriseAccessLevels && this.customRolesForProtectedBranchesEnabled;
    },
    formattedCustomRoles() {
      return this.customRoles.map((role) => ({
        ...role,
        id: getIdFromGraphQLId(role.id),
      }));
    },
  },
  apollo: {
    customRoles: {
      query: getProjectMemberRoles,
      variables() {
        return { fullPath: this.projectPath };
      },
      skip() {
        if (this.customRoles.length) return true; // already fetched once
        return !this.customRolesEnabled || !this.projectPath || !this.isOpen;
      },
      update(data) {
        return data?.namespace?.memberRoles?.nodes || [];
      },
      error(error) {
        createAlert({
          message: s__('BranchRules|Something went wrong while fetching custom roles.'),
          captureError: true,
          error,
        });
      },
    },
  },
};
</script>

<template>
  <access-levels-drawer-ce
    :is-open="isOpen"
    :project-path="projectPath"
    v-bind="$attrs"
    v-on="glListeners()"
  >
    <template #ee-custom-roles="{ selectedIds, onChange }">
      <custom-roles-checkboxes
        v-if="customRolesEnabled"
        :custom-roles="formattedCustomRoles"
        :selected-ids="selectedIds"
        @change="onChange"
      />
    </template>
  </access-levels-drawer-ce>
</template>
