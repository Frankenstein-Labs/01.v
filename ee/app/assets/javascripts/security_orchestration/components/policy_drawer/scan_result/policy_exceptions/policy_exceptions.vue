<script>
import { s__, __, n__, sprintf } from '~/locale';
import BranchPatternException from './branch_pattern_exception.vue';
import UsersGroupsExceptions from './users_groups_exceptions.vue';
import RolesExceptions from './roles_exceptions.vue';
import ServiceAccountsException from './service_accounts_exception.vue';
import TokensException from './tokens_exception.vue';

export default {
  i18n: {
    header: s__('SecurityOrchestration|Policy Bypass Options'),
  },
  name: 'PolicyExceptions',
  components: {
    BranchPatternException,
    UsersGroupsExceptions,
    RolesExceptions,
    ServiceAccountsException,
    TokensException,
  },
  props: {
    exceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    tokens() {
      return this.exceptions.access_tokens || [];
    },
    hasTokens() {
      return this.tokens.length > 0;
    },
    branches() {
      return this.exceptions.branches || [];
    },
    serviceAccounts() {
      return this.exceptions.service_accounts || [];
    },
    hasServiceAccounts() {
      return this.serviceAccounts.length > 0;
    },
    hasBranches() {
      return this.branches.length > 0;
    },
    groups() {
      return this.exceptions?.groups || [];
    },
    users() {
      return this.exceptions?.users || [];
    },
    hasGroupsOrUsers() {
      return this.users.length > 0 || this.groups.length > 0;
    },
    customRoles() {
      return this.exceptions?.custom_roles?.filter((role) => role && role.id) || [];
    },
    roles() {
      return this.exceptions?.roles || [];
    },
    hasRoles() {
      return this.roles.length > 0 || this.customRoles.length > 0;
    },
    totalExceptionsCount() {
      let sum = 0;

      Object.values(this.exceptions).forEach((exceptions) => {
        const length = Array.isArray(exceptions) ? exceptions.length : 0;
        sum += length;
      });

      return sum;
    },
    subHeaderText() {
      const configurations = n__('configuration', 'configurations', this.totalExceptionsCount);

      return sprintf(__('%{count} bypass %{configurations} defined:'), {
        configurations,
        count: this.totalExceptionsCount,
      });
    },
  },
};
</script>

<template>
  <div>
    <h5 data-testid="header">{{ $options.i18n.header }}</h5>
    <p v-if="totalExceptionsCount" data-testid="subheader" class="gl-mb-2">{{ subHeaderText }}</p>

    <tokens-exception v-if="hasTokens" :tokens="tokens" />
    <branch-pattern-exception v-if="hasBranches" :branches="branches" />
    <service-accounts-exception v-if="hasServiceAccounts" :service-accounts="serviceAccounts" />
    <users-groups-exceptions v-if="hasGroupsOrUsers" :groups="groups" :users="users" />
    <roles-exceptions v-if="hasRoles" :roles="roles" :custom-roles="customRoles" />
  </div>
</template>
