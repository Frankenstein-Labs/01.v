<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
} from '@gitlab/ui';
import { visitUrl, joinPaths } from '~/lib/utils/url_utility';
import DashboardDeleteModal from './dashboard_delete_modal.vue';
import { EDIT_DASHBOARD_PATH } from './constants';

export default {
  name: 'DashboardsListItemActionsEE',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    DashboardDeleteModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    actionLabel: {
      type: String,
      required: true,
    },
    dashboardUrl: {
      type: String,
      required: false,
      default: '',
    },
    id: {
      type: String,
      required: false,
      default: '',
    },
    system: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  methods: {
    handleEditAction() {
      visitUrl(joinPaths(this.dashboardUrl, EDIT_DASHBOARD_PATH));
    },
    handleDeleteAction() {
      this.$refs.deleteModal.show();
    },
    handleDeleteSuccess() {
      this.$refs.deleteModal.hide();
    },
  },
};
</script>

<template>
  <div>
    <dashboard-delete-modal ref="deleteModal" :dashboard-id="id" @delete="handleDeleteSuccess" />

    <gl-disclosure-dropdown
      v-gl-tooltip.hover
      icon="ellipsis_v"
      category="tertiary"
      :title="actionLabel"
      no-caret
      left
      :toggle-text="__('More actions')"
      text-sr-only
    >
      <gl-disclosure-dropdown-item
        v-if="!system"
        data-testid="dashboard-edit-action"
        @action="handleEditAction"
      >
        <template #list-item>
          {{ __('Edit') }}
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item>
        <template #list-item>
          {{ __('Make a copy') }}
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item>
        <template #list-item>
          {{ __('Share') }}
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-group v-if="!system" bordered>
        <gl-disclosure-dropdown-item
          variant="danger"
          data-testid="dashboard-delete-action"
          @action="handleDeleteAction"
        >
          <template #list-item>
            {{ __('Delete') }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>
  </div>
</template>
