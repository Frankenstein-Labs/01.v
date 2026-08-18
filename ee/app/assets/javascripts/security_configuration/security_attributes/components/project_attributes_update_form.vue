<script>
import EMPTY_ATTRIBUTE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-labels-md.svg?url';
import { GlIcon, GlTooltipDirective, GlEmptyState, GlButton } from '@gitlab/ui';
import { DRAWER_FLASH_CONTAINER_CLASS } from '../../components/security_attributes/constants';
import AttributesCategoryDropdown from './attributes_category_dropdown.vue';

export default {
  name: 'ProjectAttributesForm',
  components: {
    GlIcon,
    GlEmptyState,
    GlButton,
    AttributesCategoryDropdown,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: {
    canManageAttributes: { default: false },
    groupManageAttributesPath: { default: false },
  },
  props: {
    categories: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedAttributes: {
      type: Array,
      required: false,
      default: () => [],
    },
    filteredCategories: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['update'],
  data() {
    return {
      selectedAttributesByCategory: {},
    };
  },
  computed: {
    flattenedAttributes() {
      return Object.values(this.selectedAttributesByCategory).flat();
    },
  },
  watch: {
    categories: {
      immediate: true,
      handler(newCategories) {
        if (!newCategories || newCategories.length === 0) {
          this.selectedAttributesByCategory = {};
          return;
        }

        this.selectedAttributesByCategory = newCategories.reduce((acc, category) => {
          acc[category.id] = this.selectedAttributes
            .filter((a) => a.securityCategory?.id === category.id)
            .map((a) => a.id);
          return acc;
        }, {});
        this.emitUpdate();
      },
    },
  },
  methods: {
    handleSelectedAttributes({ categoryId, selectedAttributes }) {
      this.selectedAttributesByCategory = {
        ...this.selectedAttributesByCategory,
        [categoryId]: selectedAttributes,
      };
      this.emitUpdate();
    },
    emitUpdate() {
      this.$emit('update', this.flattenedAttributes);
    },
    selectedAttributesInCategory(category) {
      return this.selectedAttributesByCategory[category.id] || [];
    },
  },
  EMPTY_ATTRIBUTE_SVG,
  DRAWER_FLASH_CONTAINER_CLASS,
};
</script>

<template>
  <div class="!gl-py-3">
    <div :class="$options.DRAWER_FLASH_CONTAINER_CLASS" class="!gl-py-0"></div>
    <div v-if="!filteredCategories.length">
      <gl-empty-state
        :svg-path="$options.EMPTY_ATTRIBUTE_SVG"
        :svg-height="100"
        :title="__(`There are no attributes for this project's group.`)"
        :description="__('Attributes you create will appear here.')"
      >
        <template v-if="canManageAttributes" #actions>
          <gl-button variant="confirm" :href="groupManageAttributesPath">
            {{ s__('SecurityAttributes|Manage security attributes') }}
          </gl-button>
        </template>
      </gl-empty-state>
    </div>
    <div v-for="category in filteredCategories" v-else :key="category.id" class="gl-py-2">
      <div>
        <h5 class="gl-mb-2">
          {{ category.name }}
          <gl-icon
            v-tooltip="
              category.multipleSelection
                ? 'Multiple attributes from this category can be applied per project'
                : 'Only one attribute from this category can be applied per project'
            "
            :name="category.multipleSelection ? 'labels' : 'label'"
            variant="subtle"
          />
        </h5>
      </div>
      <div class="gl-mb-2 gl-text-sm gl-text-subtle">
        {{ category.description }}
      </div>
      <attributes-category-dropdown
        :category="category"
        :attributes="category.securityAttributes"
        :selected-attributes-in-category="selectedAttributesInCategory(category)"
        @change="handleSelectedAttributes"
      />
    </div>
  </div>
</template>
