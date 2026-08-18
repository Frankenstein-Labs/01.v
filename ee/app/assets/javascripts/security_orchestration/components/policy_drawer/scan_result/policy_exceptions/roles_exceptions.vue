<script>
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import groupCustomRoles from 'ee/security_orchestration/graphql/queries/group_custom_roles.query.graphql';
import projectCustomRoles from 'ee/security_orchestration/graphql/queries/project_custom_roles.query.graphql';
import { isRoleApprover } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PolicyExceptionsLoader from './policy_exceptions_loader.vue';

export default {
  i18n: {
    label: __('Loading custom roles'),
  },
  name: 'RolesExceptions',
  components: {
    GlAccordion,
    GlAccordionItem,
    PolicyExceptionsLoader,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    roles: {
      type: Array,
      required: false,
      default: () => [],
    },
    customRoles: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      loading: false,
      loadingFailed: false,
      allCustomRoles: [],
    };
  },
  computed: {
    hasCustomRolesLoaded() {
      return this.allCustomRoles.length > 0;
    },
    rolesTotalCount() {
      return (this.roles?.length || 0) + (this.customRoles?.length || 0);
    },
    title() {
      return sprintf(s__('SecurityOrchestration|Roles (%{count})'), {
        count: this.rolesTotalCount,
      });
    },
    customRolesIds() {
      return this.customRoles?.map(({ id }) => id) || [];
    },
    selectedCustomRoles() {
      return this.allCustomRoles?.filter((role) =>
        this.customRolesIds.includes(getIdFromGraphQLId(role.id)),
      );
    },
  },
  methods: {
    async loadCustomRoles() {
      this.loading = true;
      this.loadingFailed = false;

      try {
        const query = isGroup(this.namespaceType) ? groupCustomRoles : projectCustomRoles;

        const { data } = await this.$apollo.query({
          query,
          variables: {
            fullPath: this.namespacePath,
          },
        });

        this.allCustomRoles =
          data[this.namespaceType]?.memberRoles?.nodes.filter(isRoleApprover) || [];
      } catch {
        this.loadingFailed = true;
        this.allCustomRoles = [];
      } finally {
        this.loading = false;
      }
    },
    toggleAccordion(opened) {
      if (opened && !this.hasCustomRolesLoaded) {
        this.loadCustomRoles();
      }
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="title" @input="toggleAccordion">
      <ul class="gl-mb-0 gl-list-none gl-pl-4">
        <li v-for="role in roles" :key="role">
          {{ role }}
        </li>
      </ul>
      <div>
        <policy-exceptions-loader v-if="loading" class="gl-mb-2" :label="$options.i18n.label" />
        <ul v-else class="gl-list-none gl-pl-4">
          <template v-if="loadingFailed">
            <li v-for="role in customRoles" :key="role.id">{{ __('id:') }} {{ role.id }}</li>
          </template>
          <template v-else>
            <li v-for="role in selectedCustomRoles" :key="role.id">
              {{ role.name }}
            </li>
          </template>
        </ul>
      </div>
    </gl-accordion-item>
  </gl-accordion>
</template>
