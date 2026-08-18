<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ACTION_TYPE_BULK_EDIT_ATTRIBUTES, ACTION_TYPE_BULK_EDIT_SCANNERS } from '../constants';

export default {
  name: 'BulkEditActionsDropdown',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['canManageAttributes', 'canApplyProfiles'],
  emits: ['bulk-edit'],
  computed: {
    availableActions() {
      const actions = [];

      if (this.canApplyProfiles) {
        actions.push({
          text: s__('SecurityInventory|Manage security scanners'),
          type: ACTION_TYPE_BULK_EDIT_SCANNERS,
        });
      }
      if (this.canManageAttributes) {
        actions.push({
          text: s__('SecurityAttributes|Manage security attributes'),
          type: ACTION_TYPE_BULK_EDIT_ATTRIBUTES,
        });
      }

      return actions;
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    :toggle-text="s__('SecurityInventory|Select bulk action')"
    :items="availableActions"
    :disabled="availableActions.length === 0"
  >
    <gl-disclosure-dropdown-item
      v-for="action in availableActions"
      :key="action.type"
      :item="action"
      @action="$emit('bulk-edit', action.type)"
    />
  </gl-disclosure-dropdown>
</template>
