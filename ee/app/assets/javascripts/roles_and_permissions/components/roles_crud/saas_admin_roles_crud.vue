<script>
import adminRolesQuery from '../../graphql/admin_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewAdminRoleOption } from './utils';

export default {
  name: 'SaasAdminRolesCrud',
  components: { RolesCrud },
  inject: ['newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    newRoleOptions() {
      return this.newRolePath ? [createNewAdminRoleOption(this.newRolePath)] : [];
    },
  },
  apollo: {
    roles: {
      query: adminRolesQuery,
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
