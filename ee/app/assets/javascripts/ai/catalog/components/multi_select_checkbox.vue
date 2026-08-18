<script>
import {
  GlAvatarLabeled,
  GlBadge,
  GlEmptyState,
  GlFormCheckboxGroup,
  GlFormCheckbox,
  GlFormGroup,
  GlLoadingIcon,
  GlKeysetPagination,
  GlSearchBoxByType,
} from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { __, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';
import { MINIMUM_QUERY_LENGTH, PAGE_SIZE } from '../constants';

export default {
  name: 'MultiSelectCheckbox',
  components: {
    GlAvatarLabeled,
    GlBadge,
    GlEmptyState,
    GlFormCheckboxGroup,
    GlFormCheckbox,
    GlFormGroup,
    GlLoadingIcon,
    GlKeysetPagination,
    GlSearchBoxByType,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    isValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    query: {
      type: Object,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: true,
    },
    dataKey: {
      type: String,
      required: true,
    },
    placeholderText: {
      type: String,
      required: true,
    },
    itemTextFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    itemLabelFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    itemSubLabelFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    itemDisabledFn: {
      type: Function,
      required: false,
      default: () => false,
    },
    itemTrailingLabelFn: {
      type: Function,
      required: false,
      default: () => null,
    },
    projectLabelDescription: {
      type: String,
      required: true,
    },
    projectInvalidFeedback: {
      type: String,
      required: true,
    },
  },
  emits: ['input', 'error'],
  data() {
    return {
      items: null,
      searchTerm: '',
      selectedProjects: [],
      totalProjectsCount: null,
      pageInfo: {},
      cursor: {
        first: PAGE_SIZE,
        after: null,
        last: null,
        before: null,
      },
    };
  },
  apollo: {
    items: {
      query() {
        return this.query;
      },
      // Skip the cache to paginate
      fetchPolicy: fetchPolicies.NO_CACHE,
      variables() {
        return {
          ...this.queryVariables,
          search: this.isSearchQueryTooShort ? '' : this.searchTerm,
          ...this.cursor,
        };
      },
      skip() {
        return this.isSearchQueryTooShort;
      },
      result({ data }) {
        this.pageInfo = data?.[this.dataKey]?.pageInfo;
        const count = data?.[this.dataKey]?.count;
        this.totalProjectsCount = count > 99 ? '99+' : count;
      },
      update(data) {
        return this.getConnection(data);
      },
      error(error) {
        Sentry.captureException(error);
        this.onError();
      },
    },
  },
  computed: {
    projectFieldLabelCount() {
      return sprintf('(%{count})', {
        count: this.totalProjectsCount,
      });
    },
    isLoading() {
      return this.$apollo.queries.items.loading;
    },
    isSearchQueryTooShort() {
      return this.searchTerm && this.searchTerm.length < MINIMUM_QUERY_LENGTH;
    },
    noResultsText() {
      return this.isSearchQueryTooShort
        ? __('Enter at least three characters to search')
        : __('No results found');
    },
    itemList() {
      if (this.isSearchQueryTooShort) {
        return [];
      }

      return (this.items?.nodes || []).map((item) => ({
        ...item,
        text: this.itemText(item),
        value: String(item.id),
        disabled: this.itemDisabledFn(item),
      }));
    },
  },
  methods: {
    getConnection(data) {
      return this.dataKey.split('.').reduce((acc, key) => acc?.[key], data) || null;
    },
    itemText(item) {
      return this.itemTextFn(item);
    },
    itemLabel(item) {
      return this.itemLabelFn(item);
    },
    itemSubLabel(item) {
      return this.itemSubLabelFn(item);
    },
    itemTrailingLabel(item) {
      return this.itemTrailingLabelFn(item);
    },
    onError() {
      this.$emit('error');
    },
    onSelect(options) {
      this.$emit('input', options);
    },
    prevPage() {
      this.cursor = {
        first: null,
        after: null,
        last: PAGE_SIZE,
        before: this.pageInfo?.startCursor,
      };
    },
    nextPage() {
      this.cursor = {
        first: PAGE_SIZE,
        after: this.pageInfo?.endCursor,
        last: null,
        before: null,
      };
    },
    onSearch() {
      this.cursor = {
        first: PAGE_SIZE,
        after: null,
        last: null,
        before: null,
      };
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
  checkboxGroupStyle: { scrollbarWidth: 'none' },
};
</script>

<template>
  <div>
    <gl-form-group
      :label-description="projectLabelDescription"
      :label-for="id"
      :state="isValid"
      :invalid-feedback="projectInvalidFeedback"
    >
      <template #label>
        {{ __('Select projects') }}
        <span v-if="!isLoading" class="gl-font-normal">{{ projectFieldLabelCount }}</span>
      </template>
      <div
        class="gl-border gl-flex gl-items-center gl-gap-3 gl-rounded-t-lg gl-border-b-0 gl-bg-subtle gl-p-3"
        :class="{ 'gl-border-control-error': !isValid }"
      >
        <gl-search-box-by-type
          v-model="searchTerm"
          :placeholder="placeholderText"
          class="gl-max-w-28"
          @input="onSearch"
        />
      </div>
      <gl-form-checkbox-group
        :id="id"
        v-model="selectedProjects"
        :style="$options.checkboxGroupStyle"
        class="gl-border gl-max-h-30 gl-min-h-30 gl-overflow-y-scroll gl-rounded-b-lg gl-border-t-0"
        :class="{ 'gl-border-control-error': !isValid }"
      >
        <div
          v-for="item in itemList"
          :key="item.id"
          class="gl-border-t gl-inline-flex gl-w-full gl-items-center gl-p-3"
        >
          <gl-form-checkbox
            :id="item.id"
            :key="item.id"
            :value="item"
            :disabled="item.disabled"
            @input="onSelect"
          >
            <div class="gl-w-full gl-content-center gl-justify-between gl-gap-3">
              <gl-avatar-labeled
                :shape="$options.AVATAR_SHAPE_OPTION_RECT"
                :size="32"
                :src="item.avatarUrl"
                :label="itemLabel(item)"
                :entity-name="itemLabel(item)"
                :sub-label="itemSubLabel(item)"
                class="gl-min-w-0 gl-flex-1"
              />
              <gl-badge
                v-if="itemTrailingLabel(item)"
                variant="neutral"
                class="gl-ml-3 gl-shrink-0"
              >
                {{ itemTrailingLabel(item) }}
              </gl-badge>
            </div>
          </gl-form-checkbox>
        </div>
        <gl-empty-state
          v-if="!isLoading && !itemList.length"
          :title="noResultsText"
          :description="s__('AICatalog|No projects match your search.')"
        />
        <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />
      </gl-form-checkbox-group>
    </gl-form-group>
    <gl-keyset-pagination
      v-bind="pageInfo"
      class="gl-mb-3 gl-flex gl-justify-end"
      @next="nextPage"
      @prev="prevPage"
    />
  </div>
</template>
