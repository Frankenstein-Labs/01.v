<script>
import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { isValidServiceAccount } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';
import ServiceAccountsTokenSelector from './service_accounts_token_selector.vue';

export default {
  name: 'ServiceAccountsItem',
  i18n: {
    accountsHeader: s__('ScanResultPolicy|Select service accounts'),
    serviceAccountDefaultText: s__('ScanResultPolicy|Select service account'),
  },
  components: {
    GlButton,
    GlCollapsibleListbox,
    ServiceAccountsTokenSelector,
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    alreadySelectedIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    serviceAccounts: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedItem: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['remove', 'set-account', 'token-loading-error'],
  data() {
    return {
      searchTerm: '',
      /**
       * This functionality will be used eventually
       * when backend can process it
       * https://gitlab.com/groups/gitlab-org/-/epics/18112#note_2645892137
       */
      showTokenSelector: false,
    };
  },
  computed: {
    selectedId() {
      return this.selectedItem?.id || '';
    },
    selectedServiceAccount() {
      return this.findServiceAccount(this.selectedId) || {};
    },
    selectedTokensIds() {
      return this.selectedItem?.tokens?.map(({ id }) => id) || [];
    },
    toggleText() {
      return this.selectedServiceAccount.name || this.$options.i18n.serviceAccountDefaultText;
    },
    listBoxItems() {
      const alreadySelectedItems = ({ id }) =>
        id === this.selectedId || !this.alreadySelectedIds?.includes(id);
      const mapToListBoxItem = ({ name, id }) => ({ text: name, value: id });

      return this.serviceAccounts
        ?.filter(isValidServiceAccount)
        .filter(alreadySelectedItems)
        .map(mapToListBoxItem);
    },
    filteredItems() {
      return searchInItemsProperties({
        items: this.listBoxItems,
        properties: ['text', 'value'],
        searchQuery: this.searchTerm,
      });
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    findServiceAccount(id = '') {
      return this.serviceAccounts?.filter(Boolean).find((account) => account.id === id);
    },
    removeItem() {
      this.$emit('remove');
    },
    setSearchTerm(term) {
      this.searchTerm = term;
    },
    setServiceAccount(id) {
      this.$emit('set-account', { id });
    },
    setTokens(tokens) {
      this.$emit('set-account', {
        ...this.selectedItem,
        tokens,
      });
    },
  },
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-gap-5 @md/panel:gl-flex-row @md/panel:gl-items-center"
  >
    <div class="gl-flex gl-w-full gl-flex-col gl-items-center gl-gap-3 @md/panel:gl-flex-row">
      <gl-collapsible-listbox
        block
        searchable
        class="gl-w-full gl-flex-1"
        :loading="loading"
        :items="filteredItems"
        :header-text="$options.i18n.accountsHeader"
        :toggle-text="toggleText"
        :selected="selectedId"
        @search="debouncedSearch"
        @select="setServiceAccount"
      />

      <service-accounts-token-selector
        v-if="showTokenSelector"
        class="gl-flex-1"
        :account-id="selectedServiceAccount.id"
        :selected-tokens-ids="selectedTokensIds"
        @loading-error="$emit('token-loading-error')"
        @set-tokens="setTokens"
      />
    </div>

    <gl-button :aria-label="__('Remove')" icon="remove" @click="removeItem" />
  </div>
</template>
