<script>
import { GlFilteredSearchSuggestion, GlLoadingIcon, GlDropdownText } from '@gitlab/ui';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import adminRolesQuery from '../graphql/admin_roles.query.graphql';

export default {
  name: 'AdminRoleToken',
  components: { BaseToken, GlFilteredSearchSuggestion, GlLoadingIcon, GlDropdownText },
  mixins: [glListenersMixin],
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      adminMemberRoles: [],
    };
  },
  computed: {
    isLoadingRoles() {
      return this.$apollo.queries.adminMemberRoles.loading;
    },
    roleName() {
      return this.adminMemberRoles.find(({ id }) => this.value.data === id)?.name;
    },
  },
  apollo: {
    adminMemberRoles: {
      query: adminRolesQuery,
      update({ adminMemberRoles }) {
        return adminMemberRoles.nodes.map((role) => ({
          ...role,
          id: getIdFromGraphQLId(role.id).toString(),
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
  <base-token
    :active="active"
    :value="value"
    :config="config"
    :suggestions="adminMemberRoles"
    :suggestions-loading="isLoadingRoles"
    v-on="glListeners()"
  >
    <template #view>
      <gl-loading-icon v-if="isLoadingRoles" />
      <template v-else>{{ roleName }}</template>
    </template>

    <template #suggestions-list>
      <gl-filtered-search-suggestion
        v-for="role in adminMemberRoles"
        :key="role.id"
        :value="role.id"
      >
        {{ role.name }}
      </gl-filtered-search-suggestion>
    </template>

    <template v-if="!adminMemberRoles.length && !isLoadingRoles" #footer>
      <gl-dropdown-text>{{ __('No results found') }}</gl-dropdown-text>
    </template>
  </base-token>
</template>
