<script>
import { GlButton, GlSprintf } from '@gitlab/ui';
import { createAlert, VARIANT_INFO } from '~/alert';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { s__, sprintf } from '~/locale';
import groupMembersExportMutation from '../../graphql/group_members_export.mutation.graphql';

export default {
  name: 'RolesExport',
  components: { GlButton, GlSprintf, ConfirmActionModal },
  inject: ['groupId', 'currentUserEmail'],
  data() {
    return {
      showModal: false,
    };
  },
  methods: {
    async exportRoles() {
      try {
        const response = await this.$apollo.mutate({
          mutation: groupMembersExportMutation,
          variables: { groupId: convertToGraphQLId(TYPENAME_GROUP, this.groupId) },
        });

        const data = response.data.groupMembersExport;
        if (data.errors[0]) {
          return this.handleExportError();
        }

        createAlert({
          message: sprintf(this.$options.i18n.exportRoleSuccess, { email: this.currentUserEmail }),
          variant: VARIANT_INFO,
        });
        return Promise.resolve();
      } catch {
        return this.handleExportError();
      }
    },
    handleExportError() {
      return Promise.reject(this.$options.i18n.exportRoleError);
    },
  },
  i18n: {
    exportRoleReport: s__('MemberRole|Export role report'),
    exportRoleDescription: s__(
      'MemberRole|The CSV report contains a list of users, assigned role and access in all groups, subgroups, and projects. When the export is completed, it will be sent as an attachment to %{email}.',
    ),
    exportRoleSuccess: s__('MemberRole|Role report requested. CSV will be emailed to %{email}.'),
    exportRoleError: s__(
      'MemberRole|Unable to export role report. Contact support if this error persists.',
    ),
  },
};
</script>

<template>
  <div class="gl-display-contents">
    <gl-button icon="export" @click="showModal = true">
      {{ $options.i18n.exportRoleReport }}
    </gl-button>

    <confirm-action-modal
      v-if="showModal"
      modal-id="export-roles-modal"
      :title="$options.i18n.exportRoleReport"
      :action-text="$options.i18n.exportRoleReport"
      :action-fn="exportRoles"
      variant="confirm"
      @close="showModal = false"
    >
      <gl-sprintf :message="$options.i18n.exportRoleDescription">
        <template #email>
          <code>{{ currentUserEmail }}</code>
        </template>
      </gl-sprintf>
    </confirm-action-modal>
  </div>
</template>
