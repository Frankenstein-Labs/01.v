<script>
import {
  GlTable,
  GlButton,
  GlModalDirective,
  GlTooltipDirective,
  GlIcon,
  GlBadge,
  GlLink,
} from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { __, sprintf } from '~/locale';
import {
  TABLE_SORT_BY_STORAGE_KEY,
  TABLE_SORT_DESC_STORAGE_KEY,
  I18N_TABLE_REMOVE_BUTTON,
  I18N_TABLE_REMOVE_BUTTON_DISABLED,
  I18N_GROUP_COL_LABEL,
  I18N_TABLE_ACTIONS_LABEL,
} from '../constants';
import { getGroupAdoptionPath } from '../utils/helpers';
import DevopsAdoptionDeleteModal from './devops_adoption_delete_modal.vue';
import DevopsAdoptionTableCellFlag from './devops_adoption_table_cell_flag.vue';

const NAME_HEADER = 'name';

const formatter = (value, key, item) => {
  if (key === NAME_HEADER) {
    return item.namespace?.fullName;
  }

  if (item.latestSnapshot && item.latestSnapshot[key] === false) {
    return 1;
  }
  if (item.latestSnapshot && item.latestSnapshot[key]) {
    return 2;
  }

  return 0;
};

const thClass = ['!gl-bg-default', 'gl-text-subtle'];

const fieldOptions = {
  thClass,
  // eslint-disable-next-line max-params
  thAttr: (value, key, item, type) => (type === 'head' ? { 'data-testid': 'headers' } : {}),
  formatter,
  sortable: true,
  sortByFormatted: true,
};

export default {
  name: 'DevopsAdoptionTable',
  components: {
    GlTable,
    DevopsAdoptionTableCellFlag,
    GlButton,
    LocalStorageSync,
    DevopsAdoptionDeleteModal,
    GlIcon,
    GlBadge,
    GlLink,
    HelpIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModal: GlModalDirective,
  },
  inject: {
    groupGid: {
      default: null,
    },
  },
  i18n: {
    removeButtonDisabled: I18N_TABLE_REMOVE_BUTTON_DISABLED,
    removeButton: I18N_TABLE_REMOVE_BUTTON,
  },
  sortByStorageKey: TABLE_SORT_BY_STORAGE_KEY,
  sortDescStorageKey: TABLE_SORT_DESC_STORAGE_KEY,
  props: {
    enabledNamespaces: {
      type: Array,
      required: true,
    },
    cols: {
      type: Array,
      required: true,
    },
  },
  emits: ['enabled-namespaces-removed', 'track-modal-open-state'],
  data() {
    return {
      sortBy: NAME_HEADER,
      sortDesc: false,
      selectedNamespace: null,
      deleteModalId: uniqueId('delete-modal-'),
    };
  },
  computed: {
    tableHeaderFields() {
      return [
        {
          key: 'name',
          label: I18N_GROUP_COL_LABEL,
          ...fieldOptions,
          isRowHeader: true,
          thClass: ['gl-w-30', ...thClass],
        },
        ...this.cols.map((item) => ({
          ...item,
          ...fieldOptions,
        })),
        {
          key: 'actions',
          tdClass: 'actions-cell !gl-text-right',
          ...fieldOptions,
          sortable: false,
          label: I18N_TABLE_ACTIONS_LABEL,
        },
      ];
    },
  },
  methods: {
    setSelectedNamespace(namespace) {
      this.selectedNamespace = namespace;
    },
    headerSlotName(key) {
      return `head(${key})`;
    },
    cellSlotName(key) {
      return `cell(${key})`;
    },
    isCurrentGroup(item) {
      return item.namespace?.id === this.groupGid;
    },
    getDeleteButtonTooltipText(item) {
      return this.isCurrentGroup(item)
        ? this.$options.i18n.removeButtonDisabled
        : this.$options.i18n.removeButton;
    },
    getGroupAdoptionPath(fullPath) {
      return getGroupAdoptionPath(fullPath);
    },
    helpIconAltText(tooltipText) {
      return sprintf(__('%{tooltipText} image'), {
        tooltipText,
      });
    },
  },
};
</script>
<template>
  <div>
    <local-storage-sync v-model="sortBy" :storage-key="$options.sortByStorageKey" />
    <local-storage-sync v-model="sortDesc" :storage-key="$options.sortDescStorageKey" />
    <gl-table
      :fields="tableHeaderFields"
      :items="enabledNamespaces"
      :sort-by.sync="sortBy"
      :sort-desc.sync="sortDesc"
      thead-class="gl-border-t-0 gl-border-b-solid gl-border-b-1 gl-border-b-default"
      stacked="sm"
    >
      <template v-for="header in tableHeaderFields" #[headerSlotName(header.key)]>
        <div :key="header.key" class="gl-flex gl-items-center">
          <span>{{ header.label }}</span>
          <gl-button
            v-if="header.tooltip"
            v-gl-tooltip="header.tooltip"
            variant="link"
            class="gl-ml-3"
            :aria-label="header.tooltip"
          >
            <help-icon data-testid="question-icon" :alt="helpIconAltText(header.tooltip)" />
          </gl-button>
        </div>
      </template>

      <template #cell(name)="{ item }">
        <div data-testid="namespace">
          <template v-if="item.latestSnapshot">
            <template v-if="isCurrentGroup(item)">
              <span class="gl-font-bold gl-text-subtle">{{ item.namespace.fullName }}</span>
              <gl-badge class="gl-ml-1" variant="info">{{ __('This group') }}</gl-badge>
            </template>
            <gl-link
              v-else
              :href="getGroupAdoptionPath(item.namespace.fullPath)"
              class="gl-font-bold gl-text-subtle"
            >
              {{ item.namespace.fullName }}
            </gl-link>
          </template>
          <template v-else>
            <span class="gl-text-subtle">{{ item.namespace.fullName }}</span>
            <gl-icon name="hourglass" variant="subtle" />
          </template>
        </div>
      </template>

      <template v-for="col in cols" #[cellSlotName(col.key)]="{ item }">
        <devops-adoption-table-cell-flag
          v-if="item.latestSnapshot"
          :key="col.key"
          :data-testid="col.testId"
          :enabled="Boolean(item.latestSnapshot[col.key])"
          :name="col.tooltip"
          with-text
        />
      </template>

      <template #cell(actions)="{ item }">
        <span v-gl-tooltip.hover="getDeleteButtonTooltipText(item)" data-testid="actions">
          <gl-button
            v-gl-modal="deleteModalId"
            :disabled="isCurrentGroup(item)"
            category="tertiary"
            icon="remove"
            :aria-label="$options.i18n.removeButton"
            data-testid="select-namespace"
            @click="setSelectedNamespace(item)"
          />
        </span>
      </template>
    </gl-table>
    <devops-adoption-delete-modal
      v-if="selectedNamespace"
      :modal-id="deleteModalId"
      :namespace="selectedNamespace"
      @enabled-namespaces-removed="$emit('enabled-namespaces-removed', $event)"
      @track-modal-open-state="$emit('track-modal-open-state', $event)"
    />
  </div>
</template>
