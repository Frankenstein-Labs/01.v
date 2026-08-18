<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { debounce } from 'lodash-es';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__, n__ } from '~/locale';
import { SELECTIVE_SYNC_NAMESPACES } from '../constants';

const mapItemToListboxFormat = (item) => ({ ...item, value: item.id, text: item.full_name });

export default {
  name: 'GeoSiteFormNamespaces',
  i18n: {
    noSelectedDropdownTitle: s__('Geo|Select groups to replicate'),
    withSelectedDropdownTitle: (len) => n__('Geo|%d group selected', 'Geo|%d groups selected', len),
    nothingFound: s__('Geo|Nothing found…'),
  },
  components: {
    GlCollapsibleListbox,
  },
  props: {
    selectedNamespaces: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['update-sync-options'],
  data() {
    return {
      search: '',
    };
  },
  computed: {
    ...mapState(['synchronizationNamespaces', 'isLoading']),
    dropdownItems() {
      return this.synchronizationNamespaces?.map(mapItemToListboxFormat) || [];
    },
    dropdownTitle() {
      if (this.selectedNamespaces.length === 0) {
        return this.$options.i18n.noSelectedDropdownTitle;
      }

      return this.$options.i18n.withSelectedDropdownTitle(this.selectedNamespaces.length);
    },
  },
  watch: {
    search() {
      this.debounceSearch();
    },
  },
  methods: {
    ...mapActions(['fetchSyncNamespaces']),
    setSearch(search) {
      this.search = search;
    },
    debounceSearch: debounce(function debouncedSearch() {
      this.fetchSyncNamespaces(this.search);
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onItemSelect(items) {
      this.$emit('update-sync-options', { key: SELECTIVE_SYNC_NAMESPACES, value: items });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="dropdownItems"
    :toggle-text="dropdownTitle"
    :selected="selectedNamespaces"
    :searching="isLoading"
    :no-results-text="$options.i18n.nothingFound"
    multiple
    searchable
    @shown="fetchSyncNamespaces(search)"
    @search="setSearch"
    @select="onItemSelect"
  />
</template>
