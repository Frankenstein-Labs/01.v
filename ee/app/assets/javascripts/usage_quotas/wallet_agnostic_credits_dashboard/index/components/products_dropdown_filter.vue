<script>
import { GlCollapsibleListbox } from '@gitlab/ui';

import { n__, s__ } from '~/locale';

export default {
  name: 'ProductsDropdownFilter',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    products: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['select'],
  data() {
    return {
      selectedProducts: [],
    };
  },
  computed: {
    productsDropdownToggleText() {
      if (this.selectedProducts.length) {
        return n__(
          'UsageBilling|%d selected',
          'UsageBilling|%d selected',
          this.selectedProducts.length,
        );
      }
      return s__('UsageBilling|Select products');
    },
    allValues() {
      return this.products.flatMap((item) =>
        Array.isArray(item.options) ? item.options.map(({ value }) => value) : [item.value],
      );
    },
  },
  methods: {
    selectAllItems() {
      this.selectedProducts = this.allValues;
    },
    onReset() {
      this.selectedProducts = [];
    },
    onBlur() {
      this.$emit('select', this.selectedProducts);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="selectedProducts"
    multiple
    :show-select-all-button-label="__('Select all')"
    :header-text="s__('UsageBilling|Filter by product')"
    :reset-button-label="__('Clear')"
    :items="products"
    :toggle-text="productsDropdownToggleText"
    fluid-width
    :loading="loading"
    @blur="onBlur"
    @reset="onReset"
    @select-all="selectAllItems"
  />
</template>
