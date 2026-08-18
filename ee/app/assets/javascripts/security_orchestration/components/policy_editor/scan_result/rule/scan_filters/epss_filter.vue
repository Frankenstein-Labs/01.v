<script>
import { GlCollapsibleListbox, GlFormInput, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { LESS_THAN_OPERATOR } from 'ee/security_orchestration/components/policy_editor/constants';
import {
  EPSS_OPERATOR_ITEMS,
  EPSS_OPERATOR_TEXT_MAP,
  EPSS_OPERATOR_VALUE_MAP,
  EPSS_OPERATOR_VALUE_ITEMS,
} from './constants';
import { convertToPercentString, extractPercentValue, isCustomEpssValue } from './utils';

export default {
  DEFAULT_CUSTOM_VALUE: 0.2,
  EPSS_OPERATOR_ITEMS,
  EPSS_OPERATOR_VALUE_ITEMS,
  i18n: {
    label: s__('ScanResultPolicy|EPSS has a'),
    message: s__('ScanResultPolicy|%{operator} %{value} chance of exploration'),
    operatorPlaceholder: s__('ScanResultPolicy|Select operator'),
    valuePlaceholder: s__('ScanResultPolicy|Select probability'),
  },
  name: 'EpssFilter',
  components: {
    GlCollapsibleListbox,
    GlFormInput,
    GlSprintf,
    SectionLayout,
  },
  props: {
    selectedOperator: {
      type: String,
      required: false,
      default: '',
    },
    selectedValue: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: ['select'],
  data() {
    return {
      showCustomValueInput: isCustomEpssValue(this.selectedValue),
    };
  },
  computed: {
    selectedOperatorWithFallbackValue() {
      return this.selectedOperator || LESS_THAN_OPERATOR;
    },
    selectedOperatorText() {
      return (
        EPSS_OPERATOR_TEXT_MAP[this.selectedOperator] || this.$options.i18n.operatorPlaceholder
      );
    },
    selectedValueText() {
      const text = convertToPercentString(this.sanitizedSelectedValue);
      return EPSS_OPERATOR_VALUE_MAP[text] || this.$options.i18n.valuePlaceholder;
    },
    sanitizedSelectedValue() {
      const value = Number.isNaN(Number(this.selectedValue)) ? 0 : this.selectedValue;

      if (value > 1) return 1;
      if (value < 0) return 0;

      return value;
    },
  },
  methods: {
    selectValue(value) {
      const percent = extractPercentValue(value);
      if (percent) {
        this.showCustomValueInput = false;

        this.$emit('select', {
          operator: this.selectedOperatorWithFallbackValue,
          value: percent,
        });
        return;
      }

      this.showCustomValueInput = true;
      this.$emit('select', {
        operator: this.selectedOperatorWithFallbackValue,
        value: this.$options.DEFAULT_CUSTOM_VALUE,
      });
    },
    selectOperator(value) {
      this.$emit('select', {
        operator: value,
        value: this.sanitizedSelectedValue,
      });
    },
    selectCustomValue(value) {
      this.$emit('select', {
        operator: this.selectedOperatorWithFallbackValue,
        value: Number(value),
      });
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-bg-default gl-pr-1 @md/panel:gl-items-center"
    :rule-label="$options.i18n.label"
    :show-remove-button="false"
    label-classes="!gl-text-base !gl-w-10 @md/panel:!gl-w-12 !gl-pl-0 !gl-font-bold gl-mr-4"
  >
    <template #content>
      <gl-sprintf :message="$options.i18n.message">
        <template #operator>
          <gl-collapsible-listbox
            data-testid="operator-list"
            :selected="selectedOperator"
            :toggle-text="selectedOperatorText"
            :items="$options.EPSS_OPERATOR_ITEMS"
            @select="selectOperator"
          />
        </template>
        <template #value>
          <div class="gl-flex gl-gap-3">
            <gl-collapsible-listbox
              data-testid="value-list"
              :selected="selectedValueText"
              :toggle-text="selectedValueText"
              :items="$options.EPSS_OPERATOR_VALUE_ITEMS"
              @select="selectValue"
            />

            <gl-form-input
              v-if="showCustomValueInput"
              :value="sanitizedSelectedValue"
              type="number"
              class="gl-w-12"
              max="1"
              min="0"
              step="0.1"
              @input="selectCustomValue"
            />
          </div>
        </template>
      </gl-sprintf>
    </template>
  </section-layout>
</template>
