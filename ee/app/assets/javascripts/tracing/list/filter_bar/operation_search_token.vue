<script>
import { GlFilteredSearchSuggestion, GlDropdownText } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { SERVICE_NAME_FILTER_TOKEN_TYPE } from './filters';

export default {
  name: 'OperationSearchToken',
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
    GlDropdownText,
  },
  mixins: [glListenersMixin],
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    currentValue: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      operations: [],
      suggestionsList: [],
      loading: false,
    };
  },
  computed: {
    showNoServiceFooter() {
      return this.servicesForSuggestions.length === 0;
    },
    shouldLoadSuggestions() {
      return this.servicesForSuggestions.length > 0;
    },
    servicesForSuggestions() {
      const serviceFilters = this.currentValue.filter(
        ({ type, value }) => type === SERVICE_NAME_FILTER_TOKEN_TYPE && value.operator === '=',
      );
      return serviceFilters.map(({ value }) => value.data);
    },
  },
  methods: {
    async fetchSuggestions(searchTerm) {
      if (!this.shouldLoadSuggestions) {
        this.suggestionsList = [];
        return;
      }
      if (this.operations.length === 0 && this.active) {
        await this.fetchOperations();
      }
      this.suggestionsList = isEmpty(searchTerm)
        ? this.operations
        : this.operations.filter(({ name }) =>
            name.toLowerCase().includes(searchTerm.toLowerCase()),
          );
    },
    async fetchOperations() {
      this.loading = true;
      try {
        const fetchAll = this.servicesForSuggestions.map((s) => this.config.fetchOperations(s));
        this.operations = (await Promise.all(fetchAll)).flat();
      } catch (e) {
        createAlert({
          message: s__(
            'Tracing|Error: Something went wrong while fetching the operations. Try again.',
          ),
        });
        this.operations = [];
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <base-token
    v-bind="$attrs"
    :active="active"
    :config="config"
    :value="value"
    :suggestions-loading="loading"
    :suggestions="suggestionsList"
    v-on="glListeners()"
    @fetch-suggestions="fetchSuggestions"
  >
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="operation in suggestions"
        :key="operation.name"
        :value="operation.name"
      >
        {{ operation.name }}
      </gl-filtered-search-suggestion>
    </template>

    <template v-if="showNoServiceFooter" #footer>
      <gl-dropdown-text>{{ s__('Tracing|Select a service to load suggestions') }}</gl-dropdown-text>
    </template>
  </base-token>
</template>
