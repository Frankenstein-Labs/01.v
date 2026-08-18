<script>
import { GlButton, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { createAlert } from '~/alert';
import ldapAdminRoleLinksQuery from '../../graphql/ldap_sync/ldap_admin_role_links.query.graphql';
import ldapAdminRoleLinkCreateMutation from '../../graphql/ldap_sync/ldap_admin_role_link_create.mutation.graphql';
import ldapAdminRoleLinkDestroyMutation from '../../graphql/ldap_sync/ldap_admin_role_link_destroy.mutation.graphql';
import CreateSyncForm from './create_sync_form.vue';
import SyncAllButton from './sync_all_button.vue';
import LdapSyncItem from './ldap_sync_item.vue';

export default {
  name: 'LdapSyncCrud',
  components: {
    CrudComponent,
    GlButton,
    GlAlert,
    GlSprintf,
    GlLink,
    ConfirmActionModal,
    CreateSyncForm,
    SyncAllButton,
    LdapSyncItem,
  },
  inject: ['ldapUsersPath'],
  data() {
    return {
      ldapAdminRoleLinks: [],
      linkToDelete: null,
      alert: null,
      isSavingLink: false,
    };
  },
  apollo: {
    ldapAdminRoleLinks: {
      query: ldapAdminRoleLinksQuery,
      update(data) {
        return data.ldapAdminRoleLinks.nodes;
      },
      error() {
        this.ldapAdminRoleLinks = null;
      },
    },
  },
  computed: {
    isRoleLinksLoading() {
      return this.$apollo.queries.ldapAdminRoleLinks.loading;
    },
    roleLinksCount() {
      return this.ldapAdminRoleLinks.length;
    },
  },
  methods: {
    async createLink(data, hideFormFn) {
      try {
        this.alert?.dismiss();
        this.isSavingLink = true;

        const response = await this.$apollo.mutate({
          mutation: ldapAdminRoleLinkCreateMutation,
          variables: data,
        });

        const error = response.data.ldapAdminRoleLinkCreate.errors[0];
        if (error) {
          this.alert = createAlert({ message: error });
        } else {
          this.$apollo.queries.ldapAdminRoleLinks.refetch();
          hideFormFn();
        }
      } catch ({ message }) {
        this.alert = createAlert({ message });
      } finally {
        this.isSavingLink = false;
      }
    },
    async deleteLink() {
      const response = await this.$apollo.mutate({
        mutation: ldapAdminRoleLinkDestroyMutation,
        variables: { id: this.linkToDelete.id },
      });

      const error = response.data.ldapAdminRoleLinkDestroy.errors[0];
      if (error) {
        return Promise.reject(error);
      }

      this.$apollo.queries.ldapAdminRoleLinks.refetch();
      return Promise.resolve();
    },
  },
};
</script>

<template>
  <gl-alert v-if="!ldapAdminRoleLinks" variant="danger" :dismissible="false">{{
    s__('MemberRole|Could not load LDAP synchronizations. Please refresh the page to try again.')
  }}</gl-alert>

  <crud-component
    v-else
    :title="s__('LDAP|Active synchronizations')"
    :description="
      s__(
        'MemberRole|Automatically sync your LDAP directory to custom admin roles. For users matched to multiple LDAP syncs, the oldest sync entry will be used.',
      )
    "
    :count="roleLinksCount"
    :is-loading="isRoleLinksLoading"
  >
    <template #actions="{ showForm }">
      <div
        v-if="!isRoleLinksLoading"
        class="gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap @md/panel:gl-justify-end @lg/panel:gl-flex-nowrap"
      >
        <gl-link v-if="roleLinksCount" :href="ldapUsersPath" class="gl-my-3 gl-mr-3">
          {{ s__('MemberRole|View LDAP synced users') }}
        </gl-link>

        <div class="gl-flex gl-flex-wrap gl-gap-3 @md/panel:gl-flex-nowrap">
          <sync-all-button v-if="roleLinksCount" />
          <gl-button variant="confirm" @click="showForm">
            {{ s__('LDAP|Add synchronization') }}
          </gl-button>
        </div>
      </div>

      <confirm-action-modal
        v-if="linkToDelete"
        modal-id="remove-ldap-sync-modal"
        :title="s__('MemberRole|Remove LDAP synchronization')"
        :action-text="s__('MemberRole|Remove sync')"
        variant="confirm"
        :action-fn="deleteLink"
        @close="linkToDelete = null"
      >
        <gl-sprintf
          :message="
            s__(
              'MemberRole|This removes automatic syncing with your LDAP server. Users will have their current role unassigned on the next sync. %{confirmStart}Are you sure you want to remove LDAP synchronization?%{confirmEnd}',
            )
          "
        >
          <template #confirm="{ content }">
            <p class="gl-mb-0 gl-mt-4">{{ content }}</p>
          </template>
        </gl-sprintf>
      </confirm-action-modal>
    </template>

    <template #form="{ hideForm }">
      <create-sync-form
        :busy="isSavingLink"
        @submit="createLink($event, hideForm)"
        @cancel="hideForm"
      />
    </template>

    <ul v-if="ldapAdminRoleLinks.length" class="content-list">
      <ldap-sync-item
        v-for="link in ldapAdminRoleLinks"
        :key="link.id"
        :role-link="link"
        @delete="linkToDelete = link"
      />
    </ul>

    <div v-else class="gl-text-center gl-text-sm gl-text-subtle">
      {{
        s__(
          'MemberRole|No active LDAP synchronizations. Add synchronization to connect your LDAP directory with custom admin roles.',
        )
      }}
    </div>
  </crud-component>
</template>
