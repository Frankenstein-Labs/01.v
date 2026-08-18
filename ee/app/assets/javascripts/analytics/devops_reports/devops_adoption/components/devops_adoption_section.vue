<script>
import { GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { I18N_TABLE_HEADER_TEXT } from '../constants';
import DevopsAdoptionAddDropdown from './devops_adoption_add_dropdown.vue';
import DevopsAdoptionEmptyState from './devops_adoption_empty_state.vue';
import DevopsAdoptionTable from './devops_adoption_table.vue';

export default {
  name: 'DevopsAdoptionSection',
  components: {
    DevopsAdoptionTable,
    GlLoadingIcon,
    GlSprintf,
    DevopsAdoptionEmptyState,
    DevopsAdoptionAddDropdown,
  },
  i18n: {
    tableHeaderText: I18N_TABLE_HEADER_TEXT,
  },
  props: {
    isLoading: {
      type: Boolean,
      required: true,
    },
    hasEnabledNamespaceData: {
      type: Boolean,
      required: true,
    },
    timestamp: {
      type: String,
      required: true,
    },
    hasGroupData: {
      type: Boolean,
      required: true,
    },
    cols: {
      type: Array,
      required: true,
    },
    enabledNamespaces: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    groups: {
      type: Array,
      required: true,
    },
    isLoadingGroups: {
      type: Boolean,
      required: true,
    },
    hasSubgroups: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: [
    'enabled-namespaces-added',
    'enabled-namespaces-removed',
    'fetch-groups',
    'track-modal-open-state',
  ],
};
</script>
<template>
  <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />
  <div v-else-if="hasEnabledNamespaceData" class="gl-mt-3">
    <div class="gl-mb-3" data-testid="tableHeader">
      <p class="gl-text-subtle">
        <gl-sprintf :message="$options.i18n.tableHeaderText">
          <template #timestamp>{{ timestamp }}</template>
        </gl-sprintf>
      </p>

      <devops-adoption-add-dropdown
        class="gl-mb-3 @md/panel:gl-hidden"
        :groups="groups"
        :enabled-namespaces="enabledNamespaces"
        :is-loading-groups="isLoadingGroups"
        :has-subgroups="hasSubgroups"
        @fetch-groups="$emit('fetch-groups', $event)"
        @enabled-namespaces-added="$emit('enabled-namespaces-added', $event)"
        @enabled-namespaces-removed="$emit('enabled-namespaces-removed', $event)"
        @track-modal-open-state="$emit('track-modal-open-state', $event)"
      />
    </div>
    <devops-adoption-table
      :cols="cols"
      :enabled-namespaces="enabledNamespaces.nodes"
      @enabled-namespaces-removed="$emit('enabled-namespaces-removed', $event)"
      @track-modal-open-state="$emit('track-modal-open-state', $event)"
    />
  </div>
  <devops-adoption-empty-state v-else :has-groups-data="hasGroupData" />
</template>
