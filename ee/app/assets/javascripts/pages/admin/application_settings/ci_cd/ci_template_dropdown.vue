<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __, n__, s__ } from '~/locale';
import { filterItems } from './helpers';

export default {
  name: 'CiTemplateDropdown',
  i18n: {
    searchPlaceholder: s__('AdminSettings|No required configuration'),
    headerText: s__('AdminSettings|Select a CI/CD template'),
    searchSummaryText: s__('AdminSettings|templates found'),
    resetButtonLabel: __('Reset'),
  },
  components: {
    GlCollapsibleListbox,
  },
  inject: {
    initialSelectedGitlabCiYmlName: {
      default: null,
    },
    gitlabCiYmls: {
      default: {},
    },
  },
  data() {
    return {
      selected: this.initialSelectedGitlabCiYmlName,
      searchTerm: '',
    };
  },
  computed: {
    items() {
      return filterItems(this.gitlabCiYmls, this.searchTerm);
    },
    toggleText() {
      return this.selected || this.$options.i18n.searchPlaceholder;
    },
    numberOfResults() {
      return this.items.reduce((count, current) => count + current.options.length, 0);
    },
    searchSummary() {
      return n__(`%d template found`, `%d templates found`, this.numberOfResults);
    },
  },
  methods: {
    onReset() {
      this.selected = null;
    },
    onSearch(query) {
      this.searchTerm = query.trim().toLowerCase();
    },
  },
};
</script>

<template>
  <div>
    <input
      id="required_instance_ci_template_name"
      type="hidden"
      name="application_setting[required_instance_ci_template]"
      :value="selected"
    />
    <gl-collapsible-listbox
      v-model="selected"
      searchable
      :header-text="$options.i18n.headerText"
      :items="items"
      :reset-button-label="$options.i18n.resetButtonLabel"
      :search-placeholder="$options.i18n.searchPlaceholder"
      :toggle-text="toggleText"
      @reset="onReset"
      @search="onSearch"
    >
      <template #search-summary-sr-only>
        {{ searchSummary }}
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
