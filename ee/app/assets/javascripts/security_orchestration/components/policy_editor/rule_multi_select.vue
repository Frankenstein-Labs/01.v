<script>
import { GlCollapsibleListbox, GlTruncate } from '@gitlab/ui';

import { s__, sprintf } from '~/locale';
import { renderMultiSelectText } from './utils';

export default {
  name: 'RuleMultiSelect',
  components: {
    GlCollapsibleListbox,
    GlTruncate,
  },
  props: {
    itemTypeName: {
      type: String,
      required: true,
    },
    items: {
      type: Object,
      required: true,
    },
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
    /**
     * When a non-empty string is provided, the dropdown toggle displays
     * this text verbatim instead of the computed multi-select text.
     * This intentionally bypasses the `lowercase` prop — callers are
     * responsible for casing when using the override.
     */
    toggleTextOverride: {
      type: String,
      required: false,
      default: '',
    },
    includeSelectAll: {
      type: Boolean,
      required: false,
      default: () => true,
    },
    lowercase: {
      type: Boolean,
      required: false,
      default: false,
    },
    showResetButton: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['input'],
  data() {
    return {
      selected: [...this.value],
    };
  },
  computed: {
    listBoxItems() {
      return Object.entries(this.items).map(([value, text]) => ({ value, text }));
    },
    listBoxHeader() {
      return sprintf(this.$options.i18n.selectPolicyListboxHeader, {
        itemTypeName: this.itemTypeName,
      });
    },
    resetButtonLabel() {
      return this.showResetButton ? this.$options.i18n.clearAllLabel : '';
    },
    selectAllLabel() {
      return this.includeSelectAll ? this.$options.i18n.selectAllLabel : '';
    },
    text() {
      if (this.toggleTextOverride?.trim()) return this.toggleTextOverride;

      const text = renderMultiSelectText({
        selected: this.selected,
        items: this.items,
        itemTypeName: this.itemTypeName,
      });

      if (this.lowercase) return text.toLowerCase();

      return text;
    },
    itemsKeys() {
      return Object.keys(this.items);
    },
  },
  watch: {
    value(newValue) {
      this.selected = newValue;
    },
  },
  methods: {
    setSelected(items) {
      this.selected = [...items];
      this.$emit('input', this.selected);
    },
  },
  i18n: {
    multipleSelectedLabel: s__(
      'PolicyRuleMultiSelect|%{firstLabel} +%{numberOfAdditionalLabels} more',
    ),
    clearAllLabel: s__('PolicyRuleMultiSelect|Clear all'),
    selectAllLabel: s__('PolicyRuleMultiSelect|Select all'),
    selectedItemsLabel: s__('PolicyRuleMultiSelect|Select %{itemTypeName}'),
    selectPolicyListboxHeader: s__('PolicyRuleMultiSelect|Select %{itemTypeName}'),
    allSelectedLabel: s__('PolicyRuleMultiSelect|All %{itemTypeName}'),
  },
};
</script>

<template>
  <gl-collapsible-listbox
    multiple
    :header-text="listBoxHeader"
    :items="listBoxItems"
    :selected="selected"
    :show-select-all-button-label="selectAllLabel"
    :reset-button-label="resetButtonLabel"
    :toggle-text="text"
    @reset="setSelected([])"
    @select="setSelected"
    @select-all="setSelected(itemsKeys)"
  >
    <template #list-item="{ item }">
      <gl-truncate :text="item.text" />
    </template>
  </gl-collapsible-listbox>
</template>
