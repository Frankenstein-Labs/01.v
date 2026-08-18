<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, sprintf } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import customFieldOptionsQuery from 'ee/work_items/graphql/work_item_custom_field_select_options.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'CustomFieldToken',
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
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
  },
  data() {
    return {
      options: [],
      loading: true,
      hasStartedQuery: false,
    };
  },
  computed: {
    fieldId() {
      return this.config.field?.id;
    },
  },
  methods: {
    getActiveOption(options, data) {
      return options.find((option) => this.getId(option) === data);
    },
    async fetchCustomFieldOptions(searchTerm = '') {
      if (!this.fieldId) {
        return;
      }

      let shouldFilter = true;

      // if we have a search term on initial load
      // then it is an ID, so don't filter search results by it
      if (searchTerm && !this.hasStartedQuery) {
        shouldFilter = false;
      }

      this.hasStartedQuery = true;

      this.loading = true;

      await this.$apollo
        .query({
          query: customFieldOptionsQuery,
          variables: {
            fieldId: this.fieldId,
          },
        })
        .then(({ data }) => {
          const { customField } = data;
          this.options = customField?.selectOptions || [];

          if (shouldFilter) {
            this.options = this.options.filter((option) =>
              option.value.toLowerCase().includes(searchTerm.toLowerCase()),
            );
          }
        })
        .catch((error) => {
          const message = sprintf(
            s__(
              'WorkItemCustomFields|Options could not be loaded for field: %{dropdownLabel}. Please try again.',
            ),
            {
              dropdownLabel: this.config.field?.name || 'UNKNOWN_FIELD',
            },
          );

          createAlert({
            message,
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.loading = false;
        });
    },
    getId(option) {
      return getIdFromGraphQLId(option.id).toString();
    },
    getOptionText(option) {
      return option.value;
    },
  },
};
</script>

<template>
  <base-token
    :active="active"
    :config="config"
    :value="value"
    :suggestions="options"
    :suggestions-loading="loading"
    :get-active-token-value="getActiveOption"
    :value-identifier="getId"
    @fetch-suggestions="fetchCustomFieldOptions"
    v-on="glListeners()"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      {{ activeTokenValue ? getOptionText(activeTokenValue) : inputValue }}
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="option in suggestions"
        :key="option.id || option.value"
        :value="getId(option)"
      >
        {{ getOptionText(option) }}
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
