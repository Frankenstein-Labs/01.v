<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';

export default {
  validValues: ['IN_USE', 'NOT_FOUND', 'UNKNOWN'],
  transformFilters: (filters) => {
    return { reachability: Array.isArray(filters) ? filters[0] : filters };
  },
  transformQueryParams: (params) => {
    return Array.isArray(params) ? params[0] : params;
  },
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
      selectedReachability: this.value.data?.[0] || '',
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedReachability,
      };
    },
    queryStringValue() {
      return this.selectedReachability ? [this.selectedReachability] : [];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.$options.items,
        selected: this.selectedReachability,
      });
    },
  },
  methods: {
    toggleSelected(selectedValue) {
      this.selectedReachability = selectedValue;
    },
  },
  i18n: {
    label: s__('SecurityReports|Reachability'),
  },
  items: [
    {
      value: 'IN_USE',
      text: s__('SecurityReports|Yes'),
    },
    {
      value: 'NOT_FOUND',
      text: s__('SecurityReports|Not found'),
    },
    {
      value: 'UNKNOWN',
      text: s__('SecurityReports|Not available'),
    },
  ],
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelected"
  >
    <template #view>
      <span data-testid="reachability-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <search-suggestion
        v-for="item in $options.items"
        :key="item.value"
        :value="item.value"
        :text="item.text"
        :selected="item.value === selectedReachability"
        :data-testid="`suggestion-${item.value}`"
      />
    </template>
  </gl-filtered-search-token>
</template>
