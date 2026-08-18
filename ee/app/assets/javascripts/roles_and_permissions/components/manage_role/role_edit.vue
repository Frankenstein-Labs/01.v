<script>
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import memberRoleQuery from '../../graphql/role_details/member_role.query.graphql';
import adminRoleQuery from '../../graphql/admin_role/role.query.graphql';
import updateMemberRoleMutation from '../../graphql/update_member_role.mutation.graphql';
import updateAdminRoleMutation from '../../graphql/admin_role/update_role.mutation.graphql';
import { DETAILS_QUERYSTRING } from '../role_details/role_details.vue';
import RoleForm from './role_form.vue';

export default {
  name: 'RoleEdit',
  components: { GlLoadingIcon, GlAlert, RoleForm },
  inject: ['isAdminRole'],
  props: {
    roleId: {
      type: Number,
      required: true,
    },
    listPagePath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      memberRole: null,
      isSubmitting: false,
      alert: null,
    };
  },
  apollo: {
    memberRole: {
      query() {
        return this.isAdminRole ? adminRoleQuery : memberRoleQuery;
      },
      variables() {
        return { id: this.roleGraphqlId };
      },
      error() {
        this.memberRole = null;
      },
    },
  },
  computed: {
    roleGraphqlId() {
      return convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.roleId);
    },
    titleText() {
      return this.isAdminRole
        ? s__('MemberRole|Edit admin role')
        : s__('MemberRole|Edit member role');
    },
  },
  methods: {
    async saveRole(input) {
      try {
        this.alert?.dismiss();
        this.isSubmitting = true;

        const response = await this.$apollo.mutate({
          mutation: this.isAdminRole ? updateAdminRoleMutation : updateMemberRoleMutation,
          variables: { ...input, id: this.roleGraphqlId },
        });

        const error = response.data.memberRoleUpdate.errors[0];
        if (error) {
          this.showError(sprintf(s__('MemberRole|Failed to save role: %{error}'), { error }));
        } else {
          this.goToPreviousPage();
        }
      } catch {
        this.showError(s__('MemberRole|Failed to save role.'));
      }
    },
    showError(message) {
      this.isSubmitting = false;
      this.alert = createAlert({ message });
    },
    goToPreviousPage() {
      // URL to send the user back to after they submit or cancel the form, depending on which page they came from.
      const url = new URLSearchParams(window.location.search).has(DETAILS_QUERYSTRING)
        ? this.memberRole?.detailsPath || this.listPagePath
        : this.listPagePath;

      visitUrl(url);
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="$apollo.queries.memberRole.loading" size="lg" class="gl-mt-7" />

  <gl-alert v-else-if="!memberRole" :dismissible="false" variant="danger" class="gl-mt-5">
    {{ s__('MemberRole|Failed to load custom role.') }}
  </gl-alert>

  <role-form
    v-else
    :title="titleText"
    :role="memberRole"
    :submit-text="s__('MemberRole|Save role')"
    :busy="isSubmitting"
    :show-base-role="!isAdminRole"
    @submit="saveRole"
    @cancel="goToPreviousPage"
  />
</template>
