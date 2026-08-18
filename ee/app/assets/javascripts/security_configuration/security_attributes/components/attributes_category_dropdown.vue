<script>
import { GlCollapsibleListbox, GlButton } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  name: 'AttributesCategoryDropdown',
  components: {
    GlCollapsibleListbox,
    GlButton,
  },
  inject: {
    canManageAttributes: { default: false },
    groupManageAttributesPath: { default: '' },
  },
  props: {
    category: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    attributes: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedAttributesInCategory: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['change'],
  data() {
    return {
      search: '',
      selectedIds: [],
    };
  },
  computed: {
    items() {
      const base = this.attributes.map((a) => ({
        value: a.id,
        text: a.name,
        ...a,
      }));
      return this.search
        ? base.filter((i) => i.text.toLowerCase().includes(this.search.toLowerCase()))
        : base;
    },
    isBlank() {
      return this.selectedIds.length === 0;
    },
    boundValue: {
      get() {
        return this.category.multipleSelection ? this.selectedIds : this.selectedIds[0] || null;
      },
      set(value) {
        const normalized = value ? [value] : [];
        this.selectedIds = this.category.multipleSelection ? value : normalized;
      },
    },
    toggleText() {
      if (this.isBlank) return __('None');
      if (this.category.multipleSelection) {
        const firstTwo = this.selectedIds.slice(0, 2);
        const names = firstTwo
          .map((id) => this.attributes.find((a) => a.id === id)?.name || '')
          .filter(Boolean);
        if (this.selectedIds.length > 2) {
          names.push(`+${this.selectedIds.length - 2} more`);
        }
        return names.join(', ');
      }
      return this.attributes.find((a) => a.id === this.selectedIds[0])?.name;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.handleSearch, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  mounted() {
    this.selectedIds = this.selectedAttributesInCategory.map((a) => a.id || a);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    handleSearch(term) {
      this.search = term.trim();
    },
    onSearch(term) {
      const handler = this.category.multipleSelection ? this.debouncedSearch : this.handleSearch;
      handler(term);
    },
    handleSelect(selected) {
      this.boundValue = selected;
      this.emitSelection();
    },
    handleReset() {
      this.selectedIds = [];
      this.emitSelection();
    },
    emitSelection() {
      this.$emit('change', {
        categoryId: this.category.id,
        selectedAttributes: [...this.selectedIds],
      });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="boundValue"
    :multiple="category.multipleSelection"
    :toggle-text="toggleText"
    :toggle-class="{ '!gl-text-subtle': isBlank }"
    :header-text="s__('SecurityAttributes|Select security attributes')"
    :items="items"
    :reset-button-label="__('Clear')"
    searchable
    block
    @search="onSearch"
    @select="handleSelect"
    @reset="handleReset"
  >
    <template #list-item="{ item }">
      <div class="gl-flex gl-items-center gl-gap-3 gl-break-anywhere">
        <span
          :style="{ background: item.color }"
          class="gl-border gl-h-3 gl-w-5 gl-shrink-0 gl-rounded-base gl-border-white"
        ></span>
        {{ item.text }}
      </div>
    </template>
    <template v-if="canManageAttributes" #footer>
      <div class="gl-border-t gl-p-2">
        <gl-button
          block
          class="!gl-justify-start"
          category="tertiary"
          :href="groupManageAttributesPath"
        >
          {{ s__('SecurityAttributes|Manage security attributes') }}
        </gl-button>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
