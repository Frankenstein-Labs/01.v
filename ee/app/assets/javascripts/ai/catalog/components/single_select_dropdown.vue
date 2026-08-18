<script>
import { GlAvatarLabeled, GlBadge, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { fetchPolicies } from '~/lib/graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';
import { MINIMUM_QUERY_LENGTH, PAGE_SIZE } from '../constants';

export default {
  name: 'SingleSelectDropdown',
  components: {
    GlAvatarLabeled,
    GlBadge,
    GlCollapsibleListbox,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
    isValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
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
    searchable: {
      type: Boolean,
      required: false,
      default: false,
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
  },
  emits: ['input', 'error'],
  data() {
    return {
      isLoadingInitial: true,
      isLoadingMore: false,
      items: null,
      searchTerm: '',
    };
  },
  apollo: {
    items: {
      query() {
        return this.query;
      },
      // Use cache-and-network so the list reflects the latest state after
      // mutations affecting items (e.g. enabling a catalog item). Otherwise
      // re-opening the dropdown in the same session shows a stale cached list.
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          ...this.queryVariables,
          search: this.searchTerm,
          first: PAGE_SIZE,
        };
      },
      skip() {
        return this.isSearchQueryTooShort;
      },
      update(data) {
        return this.getConnection(data);
      },
      result() {
        this.isLoadingInitial = false;
      },
      error(error) {
        Sentry.captureException(error);
        this.onError();
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.items.loading && !this.isLoadingMore;
    },
    isSearchQueryTooShort() {
      return this.searchTerm && this.searchTerm.length < MINIMUM_QUERY_LENGTH;
    },
    noResultsText() {
      return this.isSearchQueryTooShort
        ? __('Enter at least three characters to search')
        : __('No results found');
    },
    selectedItem() {
      return this.items?.nodes?.find((item) => this.value === item.id);
    },
    dropdownText() {
      return this.itemText(this.selectedItem) || this.placeholderText;
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
    hasNextPage() {
      return this.items?.pageInfo?.hasNextPage;
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
    async onBottomReached() {
      if (!this.hasNextPage || this.isLoadingMore) return;

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.items.fetchMore({
          variables: {
            ...this.queryVariables,
            search: this.searchTerm,
            first: PAGE_SIZE,
            after: this.items?.pageInfo?.endCursor,
          },
        });
      } catch (error) {
        Sentry.captureException(error);
        this.onError();
      } finally {
        this.isLoadingMore = false;
      }
    },
    onError() {
      this.$emit('error');
    },
    onSearch: debounce(function debouncedSearch(query) {
      this.searchTerm = query;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onItemSelect(itemId) {
      const selectedItem = this.items?.nodes?.find((item) => itemId === item.id);
      if (!selectedItem || this.itemDisabledFn(selectedItem)) return;

      this.$emit('input', selectedItem);
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
};
</script>

<template>
  <gl-collapsible-listbox
    :selected="value"
    :items="itemList"
    :toggle-id="id"
    :toggle-text="dropdownText"
    :state="isValid"
    :header-text="placeholderText"
    :loading="isLoadingInitial"
    :searchable="searchable"
    :searching="isLoading"
    :no-results-text="noResultsText"
    block
    fluid-width
    is-check-centered
    :infinite-scroll="hasNextPage"
    :infinite-scroll-loading="isLoadingMore"
    :disabled="disabled"
    @bottom-reached="onBottomReached"
    @search="onSearch"
    @select="onItemSelect"
  >
    <template #list-item="{ item }">
      <div v-if="item" class="gl-flex gl-w-full gl-items-center gl-justify-between gl-gap-3">
        <gl-avatar-labeled
          :shape="$options.AVATAR_SHAPE_OPTION_RECT"
          :size="32"
          :src="item.avatarUrl"
          :label="itemLabel(item)"
          :entity-name="itemLabel(item)"
          :sub-label="itemSubLabel(item)"
          class="gl-min-w-0 gl-flex-1"
        />
        <gl-badge v-if="itemTrailingLabel(item)" variant="neutral" class="gl-shrink-0">
          {{ itemTrailingLabel(item) }}
        </gl-badge>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
