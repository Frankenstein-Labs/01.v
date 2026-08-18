<script>
import { GlLink, GlSprintf, GlTable, GlIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { EMPTY_STATUS_CHECK } from '../constants';
import Actions from './actions.vue';
import Branch from './branch.vue';
import ModalCreate from './modal_create.vue';
import ModalDelete from './modal_delete.vue';
import ModalUpdate from './modal_update.vue';

export const i18n = {
  title: s__('StatusCheck|Status checks'),
  description: s__(
    'StatusCheck|Check for a status response in merge requests. %{linkStart}Learn more%{linkEnd}.',
  ),
  apiHeader: __('API'),
  branchHeader: __('Target branches'),
  sharedSecretHeader: __('HMAC enabled'),
  sharedSecret: __('Shared secret'),
  actionsHeader: __('Actions'),
  emptyTableText: s__('StatusCheck|No status checks are defined yet.'),
  nameHeader: s__('StatusCheck|Service name'),
};

export default {
  name: 'StatusChecks',
  components: {
    Actions,
    Branch,
    CrudComponent,
    GlLink,
    GlIcon,
    GlSprintf,
    GlTable,
    ModalCreate,
    ModalDelete,
    ModalUpdate,
  },
  data() {
    return {
      statusCheckToDelete: EMPTY_STATUS_CHECK,
      statusCheckToUpdate: EMPTY_STATUS_CHECK,
    };
  },
  computed: {
    ...mapState(['statusChecks']),
  },
  methods: {
    openDeleteModal(statusCheck) {
      this.statusCheckToDelete = statusCheck;
      this.$refs.deleteModal.show();
    },
    openUpdateModal(statusCheck) {
      this.statusCheckToUpdate = statusCheck;
      this.$refs.updateModal.show();
    },
  },
  fields: [
    {
      key: 'name',
      label: i18n.nameHeader,
      thClass: 'gl-w-2/10',
    },
    {
      key: 'externalUrl',
      label: i18n.apiHeader,
      thClass: 'gl-w-4/10',
    },
    {
      key: 'protectedBranches',
      label: i18n.branchHeader,
      thClass: 'gl-w-2/10',
    },
    {
      key: 'sharedSecret',
      label: i18n.sharedSecretHeader,
      thClass: 'gl-w-2/10',
    },
    {
      key: 'actions',
      label: i18n.actionsHeader,
      thAlignRight: true,
      tdClass: '!gl-whitespace-nowrap @md/panel:!gl-pl-0 @md/panel:!gl-pr-0',
    },
  ],
  helpUrl: helpPagePath('/user/project/merge_requests/status_checks'),
  i18n,
};
</script>

<template>
  <crud-component :title="$options.i18n.title" icon="check-circle" :count="statusChecks.length">
    <template #description>
      <gl-sprintf :message="$options.i18n.description">
        <template #link>
          <gl-link class="gl-text-sm" :href="$options.helpUrl" target="_blank">{{
            __('Learn more')
          }}</gl-link>
        </template>
      </gl-sprintf>
    </template>

    <template #actions>
      <modal-create />
    </template>

    <gl-table
      :items="statusChecks"
      :fields="$options.fields"
      primary-key="id"
      :empty-text="$options.i18n.emptyTableText"
      show-empty
      stacked="md"
      data-testid="status-checks-table"
    >
      <template #cell(protectedBranches)="{ item }">
        <branch :branches="item.protectedBranches" />
      </template>
      <template #cell(sharedSecret)="{ item: { hmac } }">
        <gl-icon
          v-if="hmac"
          :aria-label="$options.i18n.sharedSecret"
          name="check-circle-filled"
          class="gl-text-success"
        />
      </template>
      <template #cell(actions)="{ item = {} }">
        <actions
          :status-check="item"
          @open-delete-modal="openDeleteModal"
          @open-update-modal="openUpdateModal"
        />
      </template>
    </gl-table>

    <modal-delete ref="deleteModal" :status-check="statusCheckToDelete" />
    <modal-update ref="updateModal" :status-check="statusCheckToUpdate" />
  </crud-component>
</template>
