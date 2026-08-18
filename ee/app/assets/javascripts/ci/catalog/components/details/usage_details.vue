<script>
import {
  GlTable,
  GlLink,
  GlIcon,
  GlTruncateText,
  GlKeysetPagination,
  GlFilteredSearch,
  GlLoadingIcon,
  GlButton,
  GlButtonGroup,
  GlCollapsibleListbox,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { OPERATORS_IS, OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  SORT_BY_OLDEST_VERSION,
  SORT_BY_VERSION,
  SORT_BY_LAST_USED,
  SORT_BY_PROJECT_NAME,
  TOKEN_TYPE_COMPONENT,
  TOKEN_TYPE_VERSION,
} from '../../constants';
import ComponentNameToken from './tokens/component_name_token.vue';
import VersionToken from './tokens/version_token.vue';

const STATUS = {
  outdated: { icon: 'warning', iconClass: 'gl-text-warning', label: s__('CiCatalog|Outdated') },
  upToDate: {
    icon: 'status_success',
    iconClass: 'gl-text-success',
    label: s__('CiCatalog|Up to date'),
  },
};

export default {
  name: 'UsageDetails',
  components: {
    GlTable,
    GlIcon,
    GlLink,
    GlTruncateText,
    GlKeysetPagination,
    GlFilteredSearch,
    GlLoadingIcon,
    GlButton,
    GlButtonGroup,
    GlCollapsibleListbox,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    componentUsages: {
      type: Array,
      required: true,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    resourcePath: {
      type: String,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['next-page', 'prev-page', 'filters-changed', 'sort'],
  data() {
    return {
      filterTokens: [],
      selectedSortOption: SORT_BY_OLDEST_VERSION,
      sortAscending: true,
    };
  },
  computed: {
    items() {
      return this.componentUsages.map((item) => {
        const sortedComponents = this.sortComponents(item.componentsUsed);
        const oldestComponent = sortedComponents[0];
        const versionName = oldestComponent?.version?.name;
        const statusDetails = oldestComponent?.outdated ? STATUS.outdated : STATUS.upToDate;
        const status = oldestComponent ? { versionName, ...statusDetails } : null;

        return {
          project: item.project,
          status,
          componentsUsedString: this.formatComponentsList(sortedComponents),
        };
      });
    },
    availableTokens() {
      return [
        {
          type: TOKEN_TYPE_COMPONENT,
          title: s__('CiCatalog|Component'),
          unique: true,
          token: ComponentNameToken,
          operators: OPERATORS_IS,
          resourcePath: this.resourcePath,
        },
        {
          type: TOKEN_TYPE_VERSION,
          title: s__('CiCatalog|Version'),
          unique: true,
          multiSelect: true,
          token: VersionToken,
          operators: OPERATORS_OR,
          resourcePath: this.resourcePath,
        },
      ];
    },
    sortIcon() {
      return this.sortAscending ? 'sort-lowest' : 'sort-highest';
    },
    sortDirectionLabel() {
      return this.sortAscending
        ? s__('CiCatalog|Sort direction: ascending')
        : s__('CiCatalog|Sort direction: descending');
    },
    sortOrder() {
      return `${this.selectedSortOption}_${this.sortAscending ? 'ASC' : 'DESC'}`;
    },
  },
  watch: {
    sortOrder(newSortOrder) {
      this.$emit('sort', newSortOrder);
    },
  },
  methods: {
    sortComponents(components) {
      return [...components].sort((a, b) => {
        return a.version.name.localeCompare(b.version.name, undefined, { numeric: true });
      });
    },
    formatComponentsList(sortedComponents) {
      return sortedComponents
        .map((item) => {
          return `${item.component.name} (${item.version.name})`;
        })
        .join(', ');
    },
    getFilterValue(filters, type) {
      const filter = filters.find((f) => f.type === type);
      return filter ? [filter.value?.data].flat().filter(Boolean) : [];
    },
    onFilteredSearch(filters = []) {
      this.filterTokens = filters;

      const componentName = this.getFilterValue(filters, TOKEN_TYPE_COMPONENT)[0] || null;
      const versionIds = this.getFilterValue(filters, TOKEN_TYPE_VERSION);

      this.$emit('filters-changed', { componentName, versionIds });
    },
    toggleSortDirection() {
      this.sortAscending = !this.sortAscending;
    },
    onSortSelect(sortOption) {
      this.selectedSortOption = sortOption;
    },
  },
  tableFields: [
    {
      key: 'project',
      label: s__('CiCatalog|Project path'),
      thClass: '@lg/panel:gl-w-3/10',
    },
    {
      key: 'status',
      label: s__('CiCatalog|Status'),
      thClass: '@lg/panel:gl-w-1/5',
    },
    {
      key: 'componentsUsed',
      label: s__('CiCatalog|Components used'),
      thClass: 'gl-text-right',
      tdClass: 'gl-text-right',
    },
  ],
  toggleButtonProps: { class: '!gl-text-sm' },
  sortOptions: [
    { value: SORT_BY_OLDEST_VERSION, text: s__('CiCatalog|Oldest version') },
    { value: SORT_BY_VERSION, text: s__('CiCatalog|Newest version') },
    { value: SORT_BY_LAST_USED, text: s__('CiCatalog|Last used') },
    { value: SORT_BY_PROJECT_NAME, text: s__('CiCatalog|Project name') },
  ],
};
</script>
<template>
  <div>
    <h2 class="gl-mt-5 gl-text-size-h2">{{ s__('CiCatalog|Usage statistics') }}</h2>
    <p class="gl-mb-5 gl-text-secondary">
      {{
        s__(
          'CiCatalog|The list of projects that included a component from this project in a pipeline in the last 30 days. Only displays projects you have permission to view.',
        )
      }}
    </p>

    <div class="gl-mb-5 gl-flex gl-justify-end gl-gap-3">
      <gl-filtered-search
        :value="filterTokens"
        :placeholder="s__('CiCatalog|Search by component')"
        :available-tokens="availableTokens"
        class="gl-flex-grow"
        show-friendly-text
        @submit="onFilteredSearch"
        @clear="onFilteredSearch"
      />
      <gl-button-group>
        <gl-collapsible-listbox
          :selected="selectedSortOption"
          :items="$options.sortOptions"
          @select="onSortSelect"
        />
        <gl-button
          v-gl-tooltip
          data-testid="sort-direction-button"
          :icon="sortIcon"
          :aria-label="sortDirectionLabel"
          :title="sortDirectionLabel"
          @click="toggleSortDirection"
        />
      </gl-button-group>
    </div>

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />

    <gl-table
      v-else
      :items="items"
      :fields="$options.tableFields"
      :empty-text="__('No results found')"
      stacked="sm"
      fixed
      show-empty
    >
      <template #head(componentsUsed)>
        <span class="gl-ml-auto">{{ s__('CiCatalog|Components used') }}</span>
      </template>
      <template #cell(project)="{ item: { project } }">
        <gl-link v-if="project" :href="project.webPath" class="gl-font-bold">{{
          project.nameWithNamespace
        }}</gl-link>
        <span v-else class="gl-text-subtle">{{ s__('CiCatalog|Private project') }}</span>
      </template>
      <template #cell(status)="{ item: { status } }">
        <span v-if="status" class="gl-text-sm"
          ><gl-icon :name="status.icon" :class="status.iconClass" /> {{ status.label }} &middot;
          {{ status.versionName }}</span
        >
      </template>
      <template #cell(componentsUsed)="{ item }">
        <div class="gl-flex gl-flex-col gl-items-end gl-gap-2">
          <gl-truncate-text
            class="gl-text-sm"
            :show-more-text="s__('CiCatalog|See more')"
            :show-less-text="s__('CiCatalog|See less')"
            :toggle-button-props="$options.toggleButtonProps"
            :lines="2"
            :mobile-lines="4"
          >
            {{ item.componentsUsedString }}
          </gl-truncate-text>
        </div>
      </template>
    </gl-table>
    <div class="gl-mt-5 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-bind="pageInfo"
        :prev-text="__('Previous')"
        :next-text="__('Next')"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </div>
  </div>
</template>
