<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';
import { ALL_ID as ALL_SCANNERS_ID } from '../constants';

export const DEFAULT_VENDORS = ['', 'GitLab'];

export default {
  components: {
    GlFilteredSearchToken,
    SearchSuggestion,
  },
  mixins: [glListenersMixin],
  inject: ['scanners'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    const defaultSelected = this.value.data || [ALL_SCANNERS_ID];

    return {
      selectedScanners: defaultSelected,
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedScanners,
      };
    },
    items() {
      return [
        { value: ALL_SCANNERS_ID, text: this.$options.i18n.allItemsText },
        ...this.scanners.map((scanner) => ({
          value: scanner.external_id,
          text: DEFAULT_VENDORS.includes(scanner.vendor)
            ? scanner.name
            : `${scanner.name} (${scanner.vendor})`,
        })),
      ];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.items,
        selected: this.selectedScanners,
        placeholder: this.$options.i18n.allItemsText,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedScanners = [ALL_SCANNERS_ID];
    },
    updateSelected(selectedValue) {
      if (selectedValue === ALL_SCANNERS_ID) {
        this.selectedScanners = [ALL_SCANNERS_ID];
        return;
      }

      // Make sure to remove the All Scanners selection
      this.selectedScanners = this.selectedScanners.filter((i) => i !== ALL_SCANNERS_ID);

      if (this.selectedScanners.includes(selectedValue)) {
        this.selectedScanners = this.selectedScanners.filter((i) => i !== selectedValue);
      } else {
        this.selectedScanners.push(selectedValue);
      }

      if (this.selectedScanners.length === 0) {
        this.selectedScanners = [ALL_SCANNERS_ID];
      }
    },
    isScannerSelected(name) {
      return Boolean(this.selectedScanners.find((s) => name === s));
    },
  },
  i18n: {
    label: s__('SecurityReports|Scanner'),
    allItemsText: s__('SecurityReports|All scanners'),
  },
  ALL_SCANNERS_ID,
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedScanners"
    :value="tokenValue"
    data-testid="scanner-token"
    v-on="glListeners()"
    @select="updateSelected"
    @destroy="resetSelected"
  >
    <template #view>
      <span data-testid="scanner-token-value">
        {{ toggleText }}
      </span>
    </template>
    <template #suggestions>
      <search-suggestion
        v-for="scanner in items"
        :key="scanner.value"
        :value="scanner.value"
        :text="scanner.text"
        :selected="isScannerSelected(scanner.value)"
        :data-testid="`suggestion-${scanner.value}`"
      />
    </template>
  </gl-filtered-search-token>
</template>
