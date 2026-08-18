<script>
import {
  GlTable,
  GlFormCheckbox,
  GlIcon,
  GlSprintf,
  GlTooltipDirective,
  GlKeysetPagination,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import { __, s__, n__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { smoothScrollTop } from '~/lib/utils/scroll_utils';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import groupScannerDetailsProjectsQuery from 'ee/security_configuration/graphql/scan_profiles/group_scanner_details_projects.query.graphql';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import CheckboxCell from 'ee/security_inventory/components/checkbox_cell.vue';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import AttributesCell from 'ee/security_inventory/components/attributes_cell.vue';
import { MAX_SELECTED_COUNT } from 'ee/security_inventory/constants';

const DEFAULT_PAGE_SIZE = 20;

export default {
  name: 'EnableScannersSelectItems',
  components: {
    GlTable,
    GlFormCheckbox,
    GlIcon,
    GlSprintf,
    GlKeysetPagination,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    InventoryDashboardFilteredSearchBar,
    NameCell,
    CheckboxCell,
    ToolCoverageCell,
    AttributesCell,
    HelpPopover,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['groupFullPath', 'groupId', 'canReadAttributes', 'enableScanners'],
  apollo: {
    itemsData: {
      query: groupScannerDetailsProjectsQuery,
      variables() {
        const {
          search = '',
          securityAnalyzerFilters = [],
          vulnerabilityCountFilters = [],
          attributeFilters = [],
        } = this.filters;
        return {
          fullPath: this.groupFullPath,
          namespaceId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
          first: this.before ? null : DEFAULT_PAGE_SIZE,
          after: this.after,
          last: this.before ? DEFAULT_PAGE_SIZE : null,
          before: this.before,
          search,
          securityAnalyzerFilters,
          vulnerabilityCountFilters,
          attributeFilters,
          canReadAttributes: this.canReadAttributes,
        };
      },
      update: (data) => data?.namespaceSecurityProjects,
    },
  },
  data() {
    return {
      itemsData: {},
      after: null,
      before: null,
      filters: {},
    };
  },
  computed: {
    selectedItems() {
      return this.enableScanners.selectedItems;
    },
    selectedCountMessage() {
      const selectedCount = this.selectedItems.length;
      return sprintf(
        n__(
          '%{strongStart}%{selectedCount}%{strongEnd} item selected',
          '%{strongStart}%{selectedCount}%{strongEnd} items selected',
          selectedCount,
        ),
        { selectedCount },
      );
    },
    isLoading() {
      return this.$apollo.queries.itemsData.loading;
    },
    items() {
      return this.itemsData?.nodes ?? [];
    },
    pageInfo() {
      return this.itemsData?.pageInfo ?? {};
    },
    isAnyItemSelected() {
      return this.items.some((item) => this.isItemSelected(item));
    },
    areAllItemsSelected() {
      return this.items.every((item) => this.isItemSelected(item));
    },
    isSelectedLimitReached() {
      return this.selectedItems.length >= MAX_SELECTED_COUNT;
    },
    fields() {
      return [
        {
          key: 'checkbox',
          label: '',
          thClass: 'gl-w-0',
          tdClass: '!gl-bg-default !gl-align-middle',
        },
        { key: 'name', label: __('Item'), tdClass: '!gl-bg-default', thClass: 'gl-w-1/3' },
        {
          key: 'toolCoverage',
          label: s__('SecurityConfiguration|Scanner coverage'),
          tdClass: '!gl-bg-default !gl-align-middle',
          thClass: 'gl-w-1/3',
        },
        ...(this.canReadAttributes
          ? [
              {
                key: 'securityAttributes',
                label: __('Security attributes'),
                tdClass: '!gl-bg-default !gl-align-middle',
                thClass: 'gl-w-1/3',
              },
            ]
          : []),
        {
          key: 'actions',
          label: '',
          thClass: 'gl-w-0',
          tdClass: '!gl-bg-default !gl-align-middle',
        },
      ];
    },
  },
  methods: {
    isItemSelected(item) {
      return this.selectedItems.some(({ id }) => id === item.id);
    },
    handleFilter(filters) {
      this.filters = filters;
      this.after = null;
      this.before = null;
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
      smoothScrollTop();
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
      smoothScrollTop();
    },
    viewProjectAction(item) {
      return {
        text: __('View project'),
        href: `/${item.fullPath}`,
        extraAttrs: { target: '_blank' },
      };
    },
  },
  MAX_SELECTED_COUNT,
};
</script>
<template>
  <div>
    <inventory-dashboard-filtered-search-bar
      :namespace="groupFullPath"
      class="gl-mb-4"
      @filter-subgroups-and-projects="handleFilter"
    />

    <div
      class="gl-border-b gl-sticky gl-top-0 gl-z-2 gl-mb-5 gl-flex gl-items-center gl-justify-between gl-bg-default gl-px-3 gl-py-4"
    >
      <span>
        <gl-sprintf :message="selectedCountMessage">
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
        <gl-icon
          v-if="isSelectedLimitReached"
          v-gl-tooltip="
            sprintf(__('You can select up to %{maximumCount} items at once'), {
              maximumCount: $options.MAX_SELECTED_COUNT,
            })
          "
          name="warning"
          variant="warning"
          class="gl-ml-1"
        />
      </span>
    </div>

    <gl-table
      :fields="fields"
      :items="items"
      :busy="isLoading"
      table-class="!gl-bg-strong gl-rounded-xl"
      show-empty
      borderless
    >
      <template #head(checkbox)>
        <gl-form-checkbox
          v-gl-tooltip.right
          :title="__('Select all items')"
          :checked="isAnyItemSelected"
          :indeterminate="isAnyItemSelected && !areAllItemsSelected"
          :disabled="isLoading || isSelectedLimitReached"
          class="gl-min-h-4"
          @change="(selected) => enableScanners.toggleVisibleItems(selected, items)"
        />
      </template>
      <template #head(toolCoverage)="{ label }">
        {{ label }}
        <help-popover class="gl-ml-2">
          {{
            s__(
              'SecurityConfiguration|Shows scanner coverage across all configuration methods, including security policies and CI configuration.',
            )
          }}
        </help-popover>
      </template>
      <template #cell(checkbox)="{ item }">
        <checkbox-cell
          v-if="!isLoading"
          :item="item"
          :is-selected="isItemSelected(item)"
          :is-selected-limit-reached="isSelectedLimitReached"
          @select-item="enableScanners.toggleItem"
        />
      </template>
      <template #cell(name)="{ item }">
        <name-cell :item="item" />
      </template>
      <template #cell(toolCoverage)="{ item }">
        <tool-coverage-cell :item="item" />
      </template>
      <template #cell(securityAttributes)="{ item, index }">
        <attributes-cell :item="item" :index="index" />
      </template>
      <template #cell(actions)="{ item }">
        <gl-disclosure-dropdown
          category="tertiary"
          size="small"
          icon="ellipsis_v"
          :toggle-text="__('More actions')"
          text-sr-only
          no-caret
        >
          <gl-disclosure-dropdown-item :item="viewProjectAction(item)">
            <template #list-item>
              <gl-icon name="external-link" variant="subtle" />
              {{ __('View project') }}
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown>
      </template>
    </gl-table>

    <div
      v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage"
      class="gl-mt-5 gl-flex gl-justify-center"
    >
      <gl-keyset-pagination v-bind="pageInfo" @prev="handlePrev" @next="handleNext" />
    </div>
  </div>
</template>
