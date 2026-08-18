<script>
import { GlFormGroup, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { intersectionBy, uniqueId } from 'lodash-es';

import { createAlert } from '~/alert';
import { s__, __ } from '~/locale';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';

import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';

export default {
  name: 'WorkItemBulkEditStatus',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
    GlIcon,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    checkedItems: {
      type: Array,
      required: true,
    },
    value: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['input'],
  data() {
    return {
      statusToggleId: uniqueId('wi-status-toggle-'),
      workItemTypes: [],
      searchTerm: '',
    };
  },
  computed: {
    hasItemsSelected() {
      return this.checkedItems.length > 0;
    },
    checkedItemTypeIds() {
      return Array.from(new Set(this.checkedItems.map((item) => item.workItemType.id)));
    },
    toggleText() {
      const selected = this.availableStatuses.find((option) => option.value === this.value);
      return selected?.text || __('Select status');
    },
    workItemTypesSupportingStatus() {
      if (this.$apollo.queries.workItemTypes?.loading) {
        return [];
      }
      return this.workItemTypes.reduce((acc, item) => {
        const statusWidget = item.widgetDefinitions.find(
          (widget) => widget.type === WIDGET_TYPE_STATUS,
        );
        if (statusWidget?.allowedStatuses.length > 0) {
          acc[item.id] = statusWidget.allowedStatuses;
        }

        return acc;
      }, {});
    },
    statusSupportingTypeIds() {
      return Object.keys(this.workItemTypesSupportingStatus);
    },
    selectedUniqueTypeIds() {
      return Array.from(new Set(this.checkedItemTypeIds));
    },
    hasSupportedItemsSelected() {
      return this.selectedUniqueTypeIds.every((typeId) =>
        this.statusSupportingTypeIds.includes(typeId),
      );
    },
    availableStatuses() {
      let statuses = [];
      const statusObjectTransformer = (status) => ({
        ...status,
        value: status.id,
        text: status.name,
      });

      // Early return [] in following cases
      // 1. workItemTypesSupportingStatus is still not populated
      // 2. User has not selected any item
      // 3. User has at least one selection that doesn't support statuses
      if (
        !this.statusSupportingTypeIds.length ||
        !this.selectedUniqueTypeIds.length ||
        !this.hasSupportedItemsSelected
      ) {
        return [];
      }

      // Only one item is selected, return statuses for the same
      // when available, return [] otherwise
      if (this.selectedUniqueTypeIds.length === 1) {
        statuses = this.workItemTypesSupportingStatus[this.selectedUniqueTypeIds[0]] || [];
      }

      // More than one item is selected, find unique type IDs
      // and create an intersecting list of supported statuses.
      if (this.checkedItemTypeIds.length > 1) {
        const statusesForIds = this.selectedUniqueTypeIds.reduce((acc, typeId) => {
          if (this.workItemTypesSupportingStatus[typeId]) {
            acc.push(this.workItemTypesSupportingStatus[typeId]);
          }
          return acc;
        }, []);
        statuses = intersectionBy(...statusesForIds, 'id');
      }

      return statuses.map(statusObjectTransformer);
    },
    statuses() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.availableStatuses, this.searchTerm, {
          key: ['name'],
        });
      }
      return this.availableStatuses;
    },
    noResultsText() {
      return this.hasSupportedItemsSelected
        ? ''
        : s__('WorkItem|No available status for all selected items.');
    },
  },
  watch: {
    /*
     * This watcher ensures that if user selects a mixed combination
     * of work items from the list where some of them do not support
     * statuses, we show empty state in status dropdown, and also
     * reset the value from the sidebar to avoid side-effects of
     * previously selected status.
     */
    availableStatuses(newStatuses) {
      if (!newStatuses.length) {
        this.$emit('input', '');
      }
    },
  },
  methods: {
    getAdaptiveStatusColor,
    handleReset() {
      this.$emit('input', undefined);
      this.$refs.listbox.close?.();
    },
    handleSearch(searchTerm) {
      this.searchTerm = searchTerm.trim();
    },
  },
  apollo: {
    workItemTypes: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.workItemTypes?.nodes || [];
      },
      skip() {
        return !this.hasItemsSelected;
      },
      error(error) {
        createAlert({
          message: s__('WorkItem|Something went wrong while fetching statuses. Please try again.'),
          captureError: true,
          error,
        });
      },
    },
  },
};
</script>

<template>
  <gl-form-group :label="__('Status')" :label-for="statusToggleId">
    <gl-collapsible-listbox
      ref="listbox"
      block
      is-check-centered
      :header-text="__('Select status')"
      :searchable="true"
      :items="statuses"
      :reset-button-label="__('Reset')"
      :selected="value"
      :item-value="value"
      :toggle-id="statusToggleId"
      :toggle-text="toggleText"
      :disabled="!hasItemsSelected"
      :no-results-text="noResultsText"
      @search="handleSearch"
      @hidden="handleSearch('')"
      @reset="handleReset"
      @select="$emit('input', $event)"
    >
      <template #list-item="{ item }">
        <div class="gl-truncate" data-testid="status-list-item">
          <gl-icon
            :name="item.iconName"
            :size="12"
            class="gl-mr-2"
            :style="{ color: getAdaptiveStatusColor(item.color) }"
          />
          <span>{{ item.text }}</span>
        </div>
      </template>
    </gl-collapsible-listbox>
  </gl-form-group>
</template>
