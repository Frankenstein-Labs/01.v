<script>
import { defineComponent, nextTick } from 'vue';
import { GlButton, GlCollapsibleListbox, GlFormInput, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import { ENTITY_TYPE_ICONS } from '../constants';

const SEARCHABLE_DATA_TYPES = new Set(['string', 'enum']);

export default defineComponent({
  name: 'GraphFilterBar',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlFormInput,
    GlIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    searchQuery: {
      type: String,
      required: true,
    },
    legendItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    activeTypeFilters: {
      type: Set,
      required: false,
      default: () => new Set(),
    },
    schemaNodes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['update-search-query', 'update-active-type-filters', 'clear-filters', 'search-graph'],
  data() {
    return {
      selectedField: null,
    };
  },
  computed: {
    soloType() {
      if (this.activeTypeFilters.size !== 1) return null;
      return [...this.activeTypeFilters][0];
    },
    soloLegendItem() {
      if (!this.soloType) return null;
      return this.legendItems.find((i) => i.type === this.soloType) || null;
    },
    soloSchemaNode() {
      if (!this.soloType) return null;
      return this.schemaNodes.find((n) => n.name.toLowerCase() === this.soloType) || null;
    },
    searchableFields() {
      if (!this.soloSchemaNode?.properties) return [];
      return this.soloSchemaNode.properties.filter((p) =>
        SEARCHABLE_DATA_TYPES.has(p.data_type.toLowerCase()),
      );
    },
    fieldItems() {
      return this.searchableFields.map((p) => ({ value: p.name, text: p.name }));
    },
    activeField() {
      if (this.selectedField) return this.selectedField;
      return this.soloSchemaNode?.label_field || 'name';
    },
    typeItems() {
      return this.legendItems.map((item) => ({
        value: item.type,
        text: item.name,
        color: item.color,
      }));
    },
    typeToggleText() {
      return this.soloLegendItem?.name || s__('Orbit|Select entity');
    },
    typeIconName() {
      if (!this.soloType) return 'filter';
      return this.iconForType(this.soloType);
    },
  },
  watch: {
    soloType(newType) {
      if (!newType) {
        this.selectedField = null;
        return;
      }

      this.selectedField =
        this.searchableFields[0]?.name || this.soloSchemaNode?.label_field || 'name';
      nextTick(() => {
        this.$refs.searchInput?.$el?.focus?.();
      });
    },
  },
  methods: {
    iconForType(type) {
      return ENTITY_TYPE_ICONS[type] || null;
    },
    onTypeSelect(type) {
      const isSolo = this.activeTypeFilters.size === 1 && this.activeTypeFilters.has(type);
      if (isSolo) return;
      this.$emit('update-active-type-filters', new Set([type]));
    },
    onFieldSelect(field) {
      this.selectedField = field;
      nextTick(() => {
        this.$refs.searchInput?.$el?.focus?.();
      });
    },
    searchGraph() {
      const q = (this.searchQuery || '').trim();
      if (!q || !this.soloType) return;
      this.trackEvent('click_orbit_apply_filter', { label: this.soloType });
      this.$emit('search-graph', { text: q, field: this.activeField });
    },
    clearFilters() {
      this.selectedField = null;
      this.$emit('update-search-query', '');
      this.$emit('update-active-type-filters', new Set());
      this.$emit('clear-filters');
    },
  },
});
</script>

<template>
  <div
    class="gl-mt-3 gl-flex gl-flex-wrap gl-items-center gl-gap-3 gl-rounded-xl gl-bg-strong gl-p-3"
    data-testid="graph-filter-bar"
  >
    <gl-collapsible-listbox
      :items="typeItems"
      :selected="soloType"
      :toggle-text="typeToggleText"
      :icon="typeIconName"
      :header-text="s__('Orbit|Filter by type')"
      :reset-button-label="s__('Orbit|Clear')"
      data-testid="type-selector"
      @select="onTypeSelect"
      @reset="clearFilters"
    >
      <template #list-item="{ item }">
        <span class="gl-flex gl-items-center gl-gap-2">
          <gl-icon
            v-if="iconForType(item.value)"
            :name="iconForType(item.value)"
            :size="12"
            :style="{ color: item.color }"
          />
          <span
            v-else
            class="gl-inline-block gl-h-2 gl-w-2 gl-flex-shrink-0 gl-rounded-full"
            :style="{ backgroundColor: item.color }"
          ></span>
          <span>{{ item.text }}</span>
        </span>
      </template>
    </gl-collapsible-listbox>

    <template v-if="soloType">
      <gl-collapsible-listbox
        :items="fieldItems"
        :selected="activeField"
        :toggle-text="activeField"
        data-testid="field-selector"
        @select="onFieldSelect"
      />

      <div class="gl-flex gl-min-w-34 gl-flex-1 gl-items-center gl-gap-3">
        <gl-form-input
          ref="searchInput"
          :value="searchQuery"
          :placeholder="s__('Orbit|Search')"
          class="gl-flex-1"
          data-testid="graph-search-input"
          @input="$emit('update-search-query', $event)"
          @keydown.enter.prevent="searchGraph"
        />

        <gl-button
          icon="search"
          :aria-label="s__('Orbit|Search')"
          :disabled="!searchQuery.trim()"
          data-testid="search-submit"
          @click="searchGraph"
        />

        <gl-button category="tertiary" data-testid="clear-filter-x" @click="clearFilters">
          {{ s__('Orbit|Clear') }}
        </gl-button>
      </div>
    </template>
  </div>
</template>
