<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import groupRolesQuery from '../../graphql/group_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewCustomRoleOption } from './utils';

export default {
  name: 'SaasGroupRolesCrud',
  components: { RolesCrud },
  mixins: [glFeatureFlagsMixin(), glLicensedFeaturesMixin()],
  inject: ['groupFullPath', 'newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    newRoleOptions() {
      return this.newRolePath ? [createNewCustomRoleOption(this.newRolePath)] : [];
    },
  },
  apollo: {
    roles: {
      query: groupRolesQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
          includeCustomRoles: this.glLicensedFeatures.customRoles,
        };
      },
      update: (data) => data.group,
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
