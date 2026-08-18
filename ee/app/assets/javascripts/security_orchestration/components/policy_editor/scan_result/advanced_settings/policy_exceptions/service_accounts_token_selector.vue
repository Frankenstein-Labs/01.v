<script>
import { GlCollapsibleListbox, GlTruncate, GlPopover } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { s__ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';
import Api from '~/api';

export default {
  ID: 'token-selector',
  name: 'ServiceAccountsTokenSelector',
  i18n: {
    tokensHeader: s__('ScanResultPolicy|Select access tokens'),
    tokenTypeName: s__('ScanResultPolicy|token'),
    popoverTitle: s__('ScanResultPolicy|No tokens available'),
    popoverContent: s__('ScanResultPolicy|Select service account or create a token'),
  },
  components: {
    GlCollapsibleListbox,
    GlPopover,
    GlTruncate,
  },
  inject: ['rootNamespacePath'],
  props: {
    accountId: {
      type: Number,
      required: false,
      default: undefined,
    },
    selectedTokensIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['loading-error', 'set-tokens'],
  data() {
    return {
      tokens: [],
      loading: false,
      searchTerm: '',
    };
  },
  computed: {
    elementId() {
      return `${this.accountId}_${this.$options.ID}`;
    },
    disabled() {
      return !this.accountId || this.tokens.length === 0;
    },
    tokensItems() {
      return (
        this.tokens?.reduce((acc, { id, name }) => {
          acc[id] = name;
          return acc;
        }, {}) || {}
      );
    },
    listBoxItems() {
      return (
        this.tokens?.map(({ name, id, full_name: fullName }) => ({
          text: name,
          value: id,
          fullName,
        })) || []
      );
    },
    filteredItems() {
      return searchInItemsProperties({
        items: this.listBoxItems,
        properties: ['text', 'value'],
        searchQuery: this.searchTerm,
      });
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedTokensIds.map(String),
        items: this.tokensItems,
        itemTypeName: this.$options.i18n.tokenTypeName,
        useAllSelected: false,
      });
    },
  },
  watch: {
    accountId: {
      immediate: true,
      handler(newValue) {
        if (newValue) {
          this.loadTokens(newValue);
        }
      },
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    setSearchTerm(term) {
      this.searchTerm = term;
    },
    setTokens(ids) {
      this.$emit(
        'set-tokens',
        ids.map((id) => ({ id })),
      );
    },
    async loadTokens(accountId) {
      try {
        this.loading = true;
        const { data } = await Api.groupServiceAccountsTokens(this.rootNamespacePath, accountId);

        this.tokens = data;
      } catch {
        this.$emit('loading-error');
        this.tokens = [];
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      :id="elementId"
      block
      multiple
      class="gl-w-full"
      searchable
      :disabled="disabled"
      :loading="loading"
      :selected="selectedTokensIds"
      :header-text="$options.i18n.tokensHeader"
      :items="filteredItems"
      :toggle-text="toggleText"
      @search="debouncedSearch"
      @select="setTokens"
    >
      <template #list-item="{ item }">
        <span :class="['gl-block', { 'gl-font-bold': item.fullName }]">
          <gl-truncate :text="item.text" with-tooltip />
        </span>
        <span v-if="item.fullName" class="gl-mt-1 gl-block gl-text-sm gl-text-subtle">
          <gl-truncate position="middle" :text="item.fullName" with-tooltip />
        </span>
      </template>
    </gl-collapsible-listbox>

    <gl-popover
      v-if="disabled"
      placement="top"
      :title="$options.i18n.popoverTitle"
      :content="$options.i18n.popoverContent"
      :show-close-button="false"
      :target="elementId"
    />
  </div>
</template>
