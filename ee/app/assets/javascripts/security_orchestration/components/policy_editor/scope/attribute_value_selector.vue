<script>
import { GlFormGroup, GlLabel, GlPopover } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { s__ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';

export default {
  i18n: {
    header: s__('SecurityOrchestration|Select attributes'),
    noAttributesPopover: s__(
      'SecurityOrchestration|There are no attributes for the selected category',
    ),
    itemTypeName: s__('SecurityOrchestration|attributes'),
  },
  name: 'AttributeValueSelector',
  components: {
    BaseItemsDropdown,
    GlFormGroup,
    GlLabel,
    GlPopover,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    items: {
      type: Array,
      required: true,
    },
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    isCategoryEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select', 'reset', 'select-all'],
  data() {
    return {
      searchTerm: '',
      dropdownId: uniqueId('attribute-value-selector-'),
    };
  },
  computed: {
    filteredItems() {
      return searchInItemsProperties({
        items: this.items,
        properties: ['text'],
        searchQuery: this.searchTerm,
      });
    },
    allIds() {
      return this.items.map(({ value }) => value);
    },
    isValid() {
      return !this.isDirty || this.selected.length > 0;
    },
  },
  methods: {
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    onSelectAll() {
      this.$emit('select-all', this.allIds);
    },
  },
};
</script>

<template>
  <gl-form-group class="gl-mb-0" :state="isValid">
    <gl-popover
      v-if="isCategoryEmpty"
      boundary="viewport"
      placement="bottom"
      show-close-button
      :target="dropdownId"
      :show="true"
      data-testid="no-attributes-popover"
    >
      <p class="gl-m-0">{{ $options.i18n.noAttributesPopover }}</p>
    </gl-popover>
    <base-items-dropdown
      :id="dropdownId"
      data-testid="attribute-value-dropdown"
      :disabled="disabled || isCategoryEmpty"
      :loading="loading"
      :items="filteredItems"
      :selected="selected"
      :header-text="$options.i18n.header"
      :item-type-name="$options.i18n.itemTypeName"
      @search="setSearchTerm"
      @select="$emit('select', $event)"
      @reset="$emit('reset')"
      @select-all="onSelectAll"
    >
      <template #list-item="{ item }">
        <gl-label :background-color="item.color" :title="item.text" />
      </template>
    </base-items-dropdown>
  </gl-form-group>
</template>
