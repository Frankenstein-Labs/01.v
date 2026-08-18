<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'GroupByFilter',
  components: {
    GlCollapsibleListbox,
  },
  i18n: {
    noAttributesSelectedLabel: s__('ObservabilityMetrics|Select dimensions'),
    noFunctionSelectedLabel: s__('ObservabilityMetrics|Select function'),
    selectedAttributesHeader: s__('ObservabilityMetrics|Selected dimensions'),
    availableAttributesHeader: s__('ObservabilityMetrics|Dimensions'),
  },
  props: {
    supportedFunctions: {
      type: Array,
      required: true,
    },
    supportedAttributes: {
      type: Array,
      required: true,
    },
    selectedAttributes: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedFunction: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  emits: ['group-by'],
  data() {
    return {
      groupByAttributes: this.selectedAttributes,
      groupByFunction: this.selectedFunction,
    };
  },
  computed: {
    availableGroupByFunctions() {
      return this.supportedFunctions.map((func) => ({ value: func, text: func }));
    },
    attributesItems() {
      const notSelected = (option) => !this.groupByAttributes.includes(option);
      return [
        {
          text: this.$options.i18n.selectedAttributesHeader,
          options: this.groupByAttributes.map((attribute) => ({
            value: attribute,
            text: attribute,
          })),
        },
        {
          text: this.$options.i18n.availableAttributesHeader,
          options: this.supportedAttributes
            .filter(notSelected)
            .map((attribute) => ({ value: attribute, text: attribute })),
        },
      ].filter((group) => group.options.length);
    },
    groupByAttributesToggleText() {
      if (this.groupByAttributes.length > 0) {
        if (this.groupByAttributes.length > 1) {
          return `${this.groupByAttributes[0]} +${this.groupByAttributes.length - 1}`;
        }
        return this.groupByAttributes[0];
      }
      return this.$options.i18n.noAttributesSelectedLabel;
    },
    groupByFunctionToggleText() {
      if (this.groupByFunction) {
        return this.groupByFunction;
      }
      return this.$options.i18n.noFunctionSelectedLabel;
    },
  },
  methods: {
    selectFunction(value) {
      this.groupByFunction = value;

      this.$emit('group-by', {
        attributes: this.groupByAttributes,
        func: value,
      });
    },
    selectAttributes(value) {
      this.groupByAttributes = value;

      this.$emit('group-by', {
        attributes: value,
        func: this.groupByFunction,
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-items-center gl-gap-3">
    <gl-collapsible-listbox
      data-testid="group-by-function-dropdown"
      :selected="groupByFunction"
      :items="availableGroupByFunctions"
      :toggle-text="groupByFunctionToggleText"
      @select="selectFunction"
    />
    <span>{{ __('by') }}</span>
    <gl-collapsible-listbox
      data-testid="group-by-attributes-dropdown"
      :selected="groupByAttributes"
      :toggle-text="groupByAttributesToggleText"
      multiple
      :items="attributesItems"
      @select="selectAttributes"
    />
  </div>
</template>
