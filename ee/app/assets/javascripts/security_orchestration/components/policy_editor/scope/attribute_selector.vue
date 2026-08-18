<script>
import { GlCollapsibleListbox, GlFormGroup, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getSecurityCategoriesAndAttributes from 'ee/security_configuration/graphql/group_security_categories_and_attributes.query.graphql';
import CriteriaItem from 'ee/security_orchestration/components/policy_editor/shared/criteria_item.vue';
import AttributeValueSelector from './attribute_value_selector.vue';
import {
  categoryToYamlKey,
  getInitialCategoryKey,
  getInitialExceptionType,
  getInitialExcludingAttributeIds,
  getInitialIncludingAttributeIds,
} from './utils';
import { INCLUDING, EXCLUDING, SUPPORTED_SECURITY_CATEGORY_KEYS } from './constants';

export default {
  i18n: {
    categoryHeader: s__('SecurityOrchestration|Select category'),
    categoryPlaceholder: s__('SecurityOrchestration|Select a category'),
    errorMessage: s__('SecurityOrchestration|Failed to load security categories'),
    noCategoriesText: s__('SecurityOrchestration|No security categories'),
    sentence: s__(
      'SecurityOrchestration|%{categorySelector} matched %{includingSelector} with %{exceptionSelector}',
    ),
    sentenceWithExceptions: s__(
      'SecurityOrchestration|%{categorySelector} matched %{includingSelector} with %{exceptionSelector} %{excludingSelector}',
    ),
    noExceptions: s__('SecurityOrchestration|no exceptions'),
    exceptions: s__('SecurityOrchestration|exceptions'),
  },
  EXCEPTION_ITEMS: [
    { value: INCLUDING, text: s__('SecurityOrchestration|no exceptions') },
    { value: EXCLUDING, text: s__('SecurityOrchestration|exceptions') },
  ],
  name: 'AttributeSelector',
  components: {
    AttributeValueSelector,
    CriteriaItem,
    GlCollapsibleListbox,
    GlFormGroup,
    GlSprintf,
  },
  inject: ['rootNamespacePath'],
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    disabledCategoryKeys: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['changed', 'error', 'categories-loaded'],
  apollo: {
    securityCategories: {
      query: getSecurityCategoriesAndAttributes,
      variables() {
        return {
          fullPath: this.rootNamespacePath,
        };
      },
      update(data) {
        return data?.group?.securityCategories || [];
      },
      result(result) {
        this.$emit('categories-loaded', result.data?.group?.securityCategories?.length ?? 0);
      },
      error() {
        this.$emit('error', this.$options.i18n.errorMessage);
      },
    },
  },
  data() {
    return {
      securityCategories: [],
      selectedCategoryKey: getInitialCategoryKey(this.policyScope),
      selectedIncludingIds: getInitialIncludingAttributeIds(this.policyScope),
      selectedExcludingIds: getInitialExcludingAttributeIds(this.policyScope),
      selectedExceptionType: getInitialExceptionType(this.policyScope),
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.securityCategories.loading;
    },
    categoryDropdownItems() {
      return this.securityCategories
        .filter((category) =>
          SUPPORTED_SECURITY_CATEGORY_KEYS.includes(categoryToYamlKey(category)),
        )
        .map((category) => {
          const value = categoryToYamlKey(category);
          return {
            value,
            text: category.name,
            disabled: this.disabledCategoryKeys.includes(value),
          };
        });
    },
    selectedCategory() {
      if (!this.selectedCategoryKey) return null;
      return this.securityCategories.find((c) => categoryToYamlKey(c) === this.selectedCategoryKey);
    },
    selectedCategoryToggleText() {
      return this.selectedCategory?.name || this.$options.i18n.categoryPlaceholder;
    },
    attributeDropdownItems() {
      if (!this.selectedCategory) return [];
      return this.selectedCategory.securityAttributes.map((attr) => ({
        value: attr.id,
        text: attr.name,
        color: attr.color,
      }));
    },
    hasNoAttributesForCategory() {
      return (
        Boolean(this.selectedCategoryKey) &&
        !this.isLoading &&
        this.attributeDropdownItems.length === 0
      );
    },
    isAttributeSelectorDisabled() {
      return this.disabled || !this.selectedCategoryKey;
    },
    isExceptionsMode() {
      return this.selectedExceptionType === EXCLUDING;
    },
    sentenceMessage() {
      return this.isExceptionsMode
        ? this.$options.i18n.sentenceWithExceptions
        : this.$options.i18n.sentence;
    },
    exceptionToggleText() {
      return this.isExceptionsMode
        ? this.$options.i18n.exceptions
        : this.$options.i18n.noExceptions;
    },
  },
  methods: {
    selectCategory(yamlKey) {
      this.selectedCategoryKey = yamlKey;
      this.selectedIncludingIds = [];
      this.selectedExcludingIds = [];
      this.selectedExceptionType = INCLUDING;
      this.emitChanged();
    },
    selectIncludingIds(ids) {
      this.selectedIncludingIds = ids;
      this.emitChanged();
    },
    selectExcludingIds(ids) {
      this.selectedExcludingIds = ids;
      this.emitChanged();
    },
    selectExceptionType(type) {
      this.selectedExceptionType = type;
      if (type === INCLUDING) this.selectedExcludingIds = [];
      this.emitChanged();
    },
    emitChanged() {
      if (!this.selectedCategoryKey) return;
      const toIds = (list) => list.map((id) => ({ id: getIdFromGraphQLId(id) }));
      const payload = { including: toIds(this.selectedIncludingIds) };
      if (this.isExceptionsMode) payload.excluding = toIds(this.selectedExcludingIds);
      this.$emit('changed', { [this.selectedCategoryKey]: payload });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
    <gl-sprintf :message="sentenceMessage">
      <template #categorySelector>
        <gl-form-group class="gl-mb-0">
          <gl-collapsible-listbox
            data-testid="category-dropdown"
            :disabled="disabled"
            :loading="isLoading"
            :items="categoryDropdownItems"
            :header-text="$options.i18n.categoryHeader"
            :no-results-text="$options.i18n.noCategoriesText"
            :selected="selectedCategoryKey"
            :toggle-text="selectedCategoryToggleText"
            @select="selectCategory"
          >
            <template #list-item="{ item }">
              <criteria-item :item="item" />
            </template>
          </gl-collapsible-listbox>
        </gl-form-group>
      </template>

      <template #includingSelector>
        <attribute-value-selector
          data-testid="including-selector"
          :disabled="isAttributeSelectorDisabled"
          :loading="isLoading"
          :items="attributeDropdownItems"
          :selected="selectedIncludingIds"
          :is-category-empty="hasNoAttributesForCategory"
          :is-dirty="isDirty"
          @select="selectIncludingIds"
          @reset="selectIncludingIds([])"
          @select-all="selectIncludingIds"
        />
      </template>

      <template #exceptionSelector>
        <gl-form-group class="gl-mb-0">
          <gl-collapsible-listbox
            data-testid="exception-dropdown"
            :disabled="disabled"
            :items="$options.EXCEPTION_ITEMS"
            :selected="selectedExceptionType"
            :toggle-text="exceptionToggleText"
            @select="selectExceptionType"
          />
        </gl-form-group>
      </template>

      <template v-if="isExceptionsMode" #excludingSelector>
        <attribute-value-selector
          data-testid="excluding-selector"
          :disabled="isAttributeSelectorDisabled"
          :loading="isLoading"
          :items="attributeDropdownItems"
          :selected="selectedExcludingIds"
          :is-category-empty="hasNoAttributesForCategory"
          :is-dirty="isDirty"
          @select="selectExcludingIds"
          @reset="selectExcludingIds([])"
          @select-all="selectExcludingIds"
        />
      </template>
    </gl-sprintf>
  </div>
</template>
