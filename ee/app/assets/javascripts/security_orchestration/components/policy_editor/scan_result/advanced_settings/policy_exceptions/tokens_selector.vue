<script>
import { GlFormGroup, GlCollapsibleListbox, GlFormCheckboxGroup, GlTruncate } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { s__ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';

export default {
  RECENTLY_USED_TOKENS_MAX: 3,
  i18n: {
    title: s__('ScanResultPolicy|Select token exceptions'),
    description: s__(
      'ScanResultPolicy|Apply this approval rule to any branch or a specific protected branch.',
    ),
    tokensHeader: s__('ScanResultPolicy|Access tokens'),
    accessTokenTypeName: s__('ScanResultPolicy|access token'),
  },
  name: 'TokensSelector',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
    GlFormCheckboxGroup,
    GlTruncate,
  },
  inject: ['availableAccessTokens'],
  props: {
    selectedTokens: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['set-access-tokens'],
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    selectedTokensIds() {
      return this.selectedTokens.map(({ id }) => id);
    },
    accessTokensItems() {
      return (
        this.availableAccessTokens?.reduce((acc, { id, name }) => {
          acc[id] = name;
          return acc;
        }, {}) || {}
      );
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedTokensIds.map(String),
        items: this.accessTokensItems,
        itemTypeName: this.$options.i18n.accessTokenTypeName,
        useAllSelected: false,
      });
    },
    listBoxItems() {
      return (
        this.availableAccessTokens?.map(({ name, id, full_name: fullName }) => ({
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
    hasRecentlyUsedItems() {
      return this.recentlyUsedItems.length > 0;
    },
    recentlyUsedItems() {
      return this.listBoxItems.slice(0, this.$options.RECENTLY_USED_TOKENS_MAX);
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
      const payload = ids.map((id) => ({ id }));
      this.$emit('set-access-tokens', payload);
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <gl-form-group
      id="tokens-list"
      :optional="false"
      label-for="tokens-list"
      :label="$options.i18n.title"
      :description="$options.i18n.description"
    >
      <gl-collapsible-listbox
        block
        multiple
        class="gl-w-full"
        searchable
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
    </gl-form-group>

    <div class="gl-mt-6">
      <h5 class="gl-mb-5">{{ s__('ScanResultPolicy|Recently created') }}</h5>
      <div>
        <gl-form-checkbox-group
          v-if="hasRecentlyUsedItems"
          data-testid="recently-selected-list"
          :options="recentlyUsedItems"
          :checked="selectedTokensIds"
          @input="setTokens"
        />
        <p v-else>
          {{ s__('ScanResultPolicy|There are no access tokens created') }}
        </p>
      </div>
    </div>
  </div>
</template>
