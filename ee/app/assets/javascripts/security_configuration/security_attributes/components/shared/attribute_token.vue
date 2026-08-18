<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_SECURITY_ATTRIBUTE } from 'ee/graphql_shared/constants';
import { OPERATORS_TO_GROUP } from '~/vue_shared/components/filtered_search_bar/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  transformFilters: (data, { filters, operator: tokenOperator }) => ({
    securityAttributesFilters: [
      ...(filters.securityAttributesFilters ?? []),
      {
        operator: tokenOperator === '||' ? 'IS_ONE_OF' : 'IS_NOT_ONE_OF',
        attributes: data.map((id) => convertToGraphQLId(TYPENAME_SECURITY_ATTRIBUTE, id)),
      },
    ],
  }),
  name: 'AttributeToken',
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlIcon,
  },
  mixins: [glListenersMixin],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['complete'],
  data() {
    return {
      selectedValues: this.value.data || [],
    };
  },
  computed: {
    tokenValue() {
      if (this.active && Array.isArray(this.value.data)) {
        return { data: [], operator: this.value.operator };
      }
      return {
        data: this.value.data ?? '',
        operator: this.value.operator,
      };
    },
    searchTerm() {
      return this.active && typeof this.value.data === 'string' ? this.value.data : '';
    },
    filteredAttributeOptions() {
      const options = this.config.attributeOptions || [];
      const term = this.searchTerm.trim().toLowerCase();
      if (!term) return options;
      return options.filter(({ name }) => name.toLowerCase().includes(term));
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.config.attributeOptions,
        selected: this.selectedValues,
        maxOptionsShown: 2,
      });
    },
    isMultiSelect() {
      return this.config.multiSelect && OPERATORS_TO_GROUP.includes(this.value.operator);
    },
  },
  methods: {
    resetSelected() {
      this.selectedValues = [];
    },
    toggleSelected(selectedValue) {
      if (!this.isMultiSelect) {
        this.selectedValues = [selectedValue];
        this.$emit('complete', { ...this.value, data: selectedValue });
        return;
      }
      if (this.selectedValues.includes(selectedValue)) {
        this.selectedValues = this.selectedValues.filter((s) => s !== selectedValue);
        return;
      }
      this.selectedValues.push(selectedValue);
    },
    isSelected(value) {
      return this.selectedValues.includes(value);
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    v-bind="{ ...$props, ...$attrs }"
    :config="config"
    :multi-select-values="selectedValues"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelected"
    @destroy="resetSelected"
  >
    <template #view>
      <span>{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="attribute in filteredAttributeOptions"
        :key="attribute.id"
        :value="attribute.id"
      >
        <div class="gl-flex gl-items-center">
          <gl-icon
            v-if="isMultiSelect"
            name="check"
            class="gl-mr-3 gl-shrink-0"
            :class="{
              'gl-invisible': !selectedValues.includes(attribute.id),
            }"
            variant="subtle"
          />
          {{ attribute.name }}
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
