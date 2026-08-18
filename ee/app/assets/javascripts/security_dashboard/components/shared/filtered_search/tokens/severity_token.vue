<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { ALL_ID as ALL_SEVERITIES_VALUE } from '../constants';
import SearchSuggestion from '../components/search_suggestion.vue';

export default {
  components: {
    GlFilteredSearchToken,
    SearchSuggestion,
  },
  mixins: [glListenersMixin],
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
    return {
      selectedSeverities: this.value.data || [ALL_SEVERITIES_VALUE],
    };
  },
  computed: {
    toggleText() {
      return getSelectedOptionsText({
        options: this.$options.items,
        selected: this.selectedSeverities,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    toggleSelected(selectedValue) {
      const allSeveritiesSelected = selectedValue === ALL_SEVERITIES_VALUE;

      if (this.selectedSeverities.includes(selectedValue)) {
        this.selectedSeverities = this.selectedSeverities.filter((s) => s !== selectedValue);
      } else {
        this.selectedSeverities = this.selectedSeverities.filter((s) => s !== ALL_SEVERITIES_VALUE);
        this.selectedSeverities.push(selectedValue);
      }

      if (!this.selectedSeverities.length || allSeveritiesSelected) {
        this.selectedSeverities = [ALL_SEVERITIES_VALUE];
      }
    },
    isSeveritySelected(name) {
      return Boolean(this.selectedSeverities.find((s) => name === s));
    },
  },
  i18n: {
    label: s__('SecurityReports|Severity'),
  },
  items: [
    {
      value: ALL_SEVERITIES_VALUE,
      text: s__('SecurityReports|All severities'),
    },
    ...Object.entries(SEVERITY_LEVELS).map(([id, text]) => ({
      value: id.toUpperCase(),
      text,
    })),
  ],
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedSeverities"
    v-on="glListeners()"
    @select="toggleSelected"
  >
    <template #view>
      <span data-testid="severity-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <search-suggestion
        v-for="severity in $options.items"
        :key="severity.value"
        :value="severity.value"
        :text="severity.text"
        :selected="isSeveritySelected(severity.value)"
        :data-testid="`suggestion-${severity.value}`"
      />
    </template>
  </gl-filtered-search-token>
</template>
