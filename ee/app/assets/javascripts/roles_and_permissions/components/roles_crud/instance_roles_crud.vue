<script>
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import instanceRolesQuery from '../../graphql/instance_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewCustomRoleOption, createNewAdminRoleOption } from './utils';

export default {
  name: 'InstanceRolesCrud',
  components: { RolesCrud },
  mixins: [glLicensedFeaturesMixin()],
  inject: ['newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    isCustomRolesAvailable() {
      return this.glLicensedFeatures.customRoles;
    },
    newRoleOptions() {
      if (!this.newRolePath) return [];

      const items = [createNewCustomRoleOption(this.newRolePath)];
      if (this.isCustomRolesAvailable) {
        items.push(createNewAdminRoleOption(this.newRolePath));
      }

      return items;
    },
  },
  apollo: {
    roles: {
      query: instanceRolesQuery,
      variables() {
        return {
          includeCustomRoles: this.isCustomRolesAvailable,
        };
      },
      update: (data) => data,
      error: showRolesFetchError,
    },
  },
};
</script>

<template>
  <roles-crud
    :roles="roles"
    :loading="$apollo.queries.roles.loading"
    :new-role-options="newRoleOptions"
    @deleted="() => $apollo.queries.roles.refetch()"
  />
</template>
