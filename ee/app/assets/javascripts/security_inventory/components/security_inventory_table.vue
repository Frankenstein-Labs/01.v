<script>
import {
  GlTableLite,
  GlSkeletonLoader,
  GlFormCheckbox,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ProjectAttributesUpdateDrawer from 'ee_component/security_configuration/security_attributes/components/project_attributes_update_drawer.vue';
import BulkAttributesUpdateDrawer from 'ee_component/security_configuration/security_attributes/components/bulk_attributes_update_drawer.vue';
import { MAX_SELECTED_COUNT, ACTION_TYPE_BULK_EDIT_SCANNERS } from '../constants';
import BulkScannersUpdateDrawer from './bulk_scanners_update_drawer.vue';
import NameCell from './name_cell.vue';
import VulnerabilityCell from './vulnerability_cell.vue';
import ToolCoverageCell from './tool_coverage_cell.vue';
import ActionCell from './action_cell.vue';
import AttributesCell from './attributes_cell.vue';
import CheckboxCell from './checkbox_cell.vue';

const SKELETON_ROW_COUNT = 3;

export default {
  components: {
    GlTableLite,
    GlSkeletonLoader,
    GlFormCheckbox,
    GlIcon,
    NameCell,
    VulnerabilityCell,
    ToolCoverageCell,
    ActionCell,
    AttributesCell,
    CheckboxCell,
    ProjectAttributesUpdateDrawer,
    BulkAttributesUpdateDrawer,
    BulkScannersUpdateDrawer,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['canReadAttributes', 'canManageAttributes', 'canApplyProfiles'],
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasSearch: {
      type: Boolean,
      required: false,
      default: false,
    },
    currentPath: {
      type: String,
      required: true,
    },
  },
  emits: ['selected-count', 'refetch'],
  data() {
    return {
      selectedProject: null,
      selectedItems: [],
    };
  },
  computed: {
    displayItems() {
      return this.isLoading && this.items.length === 0
        ? Array(SKELETON_ROW_COUNT).fill({})
        : this.items;
    },
    shouldShowBulkEdit() {
      return (
        this.canManageAttributes ||
        (this.glFeatures.securityScanProfilesFeature && this.canApplyProfiles)
      );
    },
    isAnyItemSelected() {
      return this.items.some((item) => this.isSelected(item));
    },
    areAllItemsSelected() {
      return this.items.every((item) => this.isSelected(item));
    },
    isSelectedLimitReached() {
      return this.selectedItems.length >= MAX_SELECTED_COUNT;
    },
    securityAttributesTooltip() {
      return s__(
        'SecurityAttributes|You must have at least the Maintainer role in this group to manage security attributes.',
      );
    },
    fields() {
      const fields = [
        { key: 'name', label: __('Name'), thClass: 'gl-w-1/4' },
        { key: 'vulnerabilities', label: __('Vulnerabilities'), thClass: 'gl-w-1/5' },
        { key: 'toolCoverage', label: __('Tool Coverage'), thClass: 'gl-w-1/3' },
        // spliced element gets inserted here
        { key: 'actions', label: '', thClass: 'gl-w-2/20' },
      ];
      if (this.canReadAttributes) {
        fields.splice(3, 0, {
          key: 'securityAttributes',
          label: s__('SecurityAttributes|Security attributes'),
          thClass: 'gl-w-1/6',
        });
        if (this.shouldShowBulkEdit) {
          fields.splice(0, 0, {
            key: 'checkbox',
            label: '',
            thClass: 'gl-w-0',
            tdClass: '!gl-pt-6',
          });
        }
      }
      return fields;
    },
  },
  methods: {
    isSelected(item) {
      return this.selectedItems.includes(item.id);
    },
    selectItem(item, checked) {
      if (checked) {
        this.selectedItems.push(item.id);
      } else {
        this.selectedItems = this.selectedItems.filter(
          (selectedItemId) => selectedItemId !== item.id,
        );
      }
      this.$emit('selected-count', this.selectedItems.length);
    },
    selectAll(selected) {
      if (selected) {
        this.selectedItems = [...this.items.map((item) => item.id)].slice(0, MAX_SELECTED_COUNT);
      } else {
        this.selectedItems = [];
      }
      this.$emit('selected-count', this.selectedItems.length);
    },
    clearSelection() {
      this.selectAll(false);
    },
    bulkEdit(type) {
      if (type === ACTION_TYPE_BULK_EDIT_SCANNERS) {
        this.$nextTick(() => {
          this.$refs.bulkScannersDrawer.openDrawer();
        });
      } else {
        this.$nextTick(() => {
          this.$refs.bulkAttributesDrawer.openDrawer();
        });
      }
    },
    openAttributesDrawer(item) {
      this.selectedProject = item;
      this.$nextTick(() => {
        this.$refs.attributesDrawer.openDrawer();
      });
    },
    openScannersDrawer(item) {
      this.clearSelection();
      this.selectedItems = [item];
      this.bulkEdit(ACTION_TYPE_BULK_EDIT_SCANNERS);
    },
    refreshDashboard() {
      this.$emit('refetch');
    },
    subgroupHref(item) {
      const parentPath = item.fullPath?.substring(0, item.fullPath.lastIndexOf('/'));
      if (!parentPath || parentPath === this.currentPath) return '';
      return `#${parentPath}`;
    },
  },
};
</script>

<template>
  <div>
    <gl-table-lite :items="displayItems" :fields="fields" hover table-class="gl-table-fixed">
      <template v-if="shouldShowBulkEdit" #head(checkbox)>
        <gl-form-checkbox
          v-gl-tooltip.right
          :title="__('Select all items')"
          :checked="isAnyItemSelected"
          :indeterminate="isAnyItemSelected && !areAllItemsSelected"
          :disabled="isLoading"
          class="gl-min-h-4"
          @change="selectAll"
        />
      </template>

      <template v-if="shouldShowBulkEdit" #cell(checkbox)="{ item }">
        <checkbox-cell
          v-if="!isLoading"
          :item="item"
          :is-selected="isSelected(item)"
          :is-selected-limit-reached="isSelectedLimitReached"
          @select-item="selectItem"
        />
      </template>

      <template #head(securityAttributes)="{ label }">
        {{ label }}
        <button
          v-gl-tooltip
          type="button"
          class="gl-ml-2 gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0"
          :title="securityAttributesTooltip"
          :aria-label="securityAttributesTooltip"
          data-testid="security-attributes-tooltip-button"
        >
          <gl-icon name="information-o" />
        </button>
      </template>

      <template #cell(name)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :width="200" :height="20" preserve-aspect-ratio="none">
          <rect x="0" y="5" width="15" height="15" rx="3" />
          <rect x="24" y="5" width="50" height="5" rx="2" />
          <rect x="24" y="15" width="100" height="5" rx="2" />
        </gl-skeleton-loader>
        <name-cell
          v-else
          :item="item"
          :show-search-param="hasSearch"
          :subgroup-href="subgroupHref(item)"
        />
      </template>

      <template #cell(vulnerabilities)="{ item, index }">
        <gl-skeleton-loader v-if="isLoading" :width="250" :height="20">
          <rect x="0" y="6" width="230" height="13" rx="6" />
        </gl-skeleton-loader>
        <vulnerability-cell v-else :item="item" :index="index" />
      </template>

      <template #cell(toolCoverage)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :width="300" :height="30" preserve-aspect-ratio="none">
          <rect x="0" y="5" width="32" height="20" rx="10" />
          <rect x="38" y="5" width="32" height="20" rx="10" />
          <rect x="76" y="5" width="32" height="20" rx="10" />
          <rect x="114" y="5" width="32" height="20" rx="10" />
          <rect x="152" y="5" width="32" height="20" rx="10" />
          <rect x="190" y="5" width="32" height="20" rx="10" />
        </gl-skeleton-loader>
        <tool-coverage-cell v-else :item="item" />
      </template>

      <template #cell(securityAttributes)="{ item, index }">
        <gl-skeleton-loader v-if="isLoading" :width="250" :height="40">
          <rect x="0" y="5" width="100" height="15" rx="6" />
          <rect x="105" y="5" width="100" height="15" rx="6" />
          <rect x="0" y="25" width="100" height="15" rx="6" />
        </gl-skeleton-loader>
        <attributes-cell
          v-else
          :index="index"
          :item="item"
          @open-attributes-drawer="openAttributesDrawer"
        />
      </template>

      <template #cell(actions)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :width="32" :height="18">
          <rect x="0" y="3" width="12" height="12" rx="2" />
        </gl-skeleton-loader>
        <action-cell
          v-else
          :item="item"
          @open-attributes-drawer="openAttributesDrawer"
          @open-scanners-drawer="openScannersDrawer"
        />
      </template>
    </gl-table-lite>

    <project-attributes-update-drawer
      v-if="selectedProject"
      :key="selectedProject.id"
      ref="attributesDrawer"
      :project-id="selectedProject.id"
      :selected-attributes="selectedProject.securityAttributes.nodes"
      @saved="refreshDashboard"
    />
    <bulk-attributes-update-drawer
      v-if="selectedItems.length"
      ref="bulkAttributesDrawer"
      :item-ids="selectedItems"
      @refetch="refreshDashboard"
    />
    <bulk-scanners-update-drawer
      ref="bulkScannersDrawer"
      :item-ids="selectedItems"
      @refetch="refreshDashboard"
    />
  </div>
</template>
