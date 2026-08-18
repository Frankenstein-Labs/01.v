<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { s__, __, sprintf } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';

export default {
  i18n: {
    selectedLabel: __('Selected'),
    licenses: __('Licenses'),
    customLicense: s__('ScanResultPolicy|Custom license'),
    addCustomLicense: s__('ScanResultPolicy|Add "%{name}"'),
    header: s__('ScanResultPolicy|Choose or enter a license'),
  },
  name: 'DenyAllowLicenses',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    selected: {
      type: Object,
      required: false,
      default: undefined,
    },
    alreadySelectedLicenses: {
      type: Array,
      required: false,
      default: () => [],
    },
    allLicenses: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['select'],
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    allSelected() {
      const deduplicatedSelection = [...new Set(this.getMappedItemsFromSelectedValues('text'))];
      return this.allLicenses.length === deduplicatedSelection.length;
    },
    unselectedLicenses() {
      const items = this.allLicenses.filter(
        ({ value }) => !this.getMappedItemsFromSelectedValues('value').includes(value),
      );

      return searchInItemsProperties({
        items,
        properties: ['text'],
        searchQuery: this.searchTerm,
      });
    },
    customLicenseOption() {
      const name = this.searchTerm;
      if (!name) return null;

      // Only offer a custom entry when the search matches no known (SPDX) license,
      // so predefined licenses always take precedence over free-text input.
      if (this.unselectedLicenses.length > 0) return null;

      const alreadySelected =
        this.getMappedItemsFromSelectedValues('value').includes(name) ||
        this.selected?.value === name;
      if (alreadySelected) return null;

      return { value: name, text: name };
    },
    licenses() {
      const groups = [];

      if (!this.allSelected) {
        const options = this.unselectedLicenses.filter(
          ({ value }) => value !== this.selected?.value,
        );

        if (options.length) {
          groups.unshift({ text: this.$options.i18n.licenses, options });
        }
      }

      if (this.selected) {
        groups.unshift({
          text: this.$options.i18n.selectedLabel,
          options: [this.selected],
        });
      }

      if (this.customLicenseOption) {
        groups.push({
          text: this.$options.i18n.customLicense,
          options: [
            {
              value: this.customLicenseOption.value,
              text: sprintf(this.$options.i18n.addCustomLicense, {
                name: this.customLicenseOption.value,
              }),
            },
          ],
        });
      }

      return groups;
    },
    selectedItem() {
      return this.selected?.value || '';
    },
    toggleText() {
      return this.selected?.text || this.$options.i18n.header;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    getMappedItemsFromSelectedValues(key) {
      return this.alreadySelectedLicenses.map((item) => item[key]).filter(Boolean);
    },
    selectLicense(id) {
      const license = this.allLicenses.find((item) => item.value === id) || { value: id, text: id };
      this.$emit('select', license);
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    class="gl-max-w-30"
    :header-text="$options.i18n.header"
    :items="licenses"
    :toggle-text="toggleText"
    :selected="selectedItem"
    size="small"
    searchable
    @search="debouncedSearch"
    @select="selectLicense"
  />
</template>
