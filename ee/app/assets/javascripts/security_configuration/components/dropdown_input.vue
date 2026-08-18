<script>
import { GlFormGroup, GlCollapsibleListbox, GlLink, GlSprintf } from '@gitlab/ui';
import { CUSTOM_VALUE_MESSAGE } from '../constants';

export default {
  name: 'DropdownInput',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
    GlLink,
    GlSprintf,
  },
  // The DynamicFields component v-binds the configuration entity to this
  // component. This ensures extraneous keys/values are not added as attributes
  // to the underlying GlFormGroup.
  inheritAttrs: false,
  model: {
    prop: 'value',
    event: 'input',
  },
  props: {
    value: {
      type: String,
      required: true,
    },
    defaultValue: {
      type: String,
      required: false,
      default: null,
    },
    field: {
      type: String,
      required: true,
    },
    label: {
      type: String,
      required: true,
    },
    defaultText: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    sectionHeader: {
      type: String,
      required: false,
      default: '',
    },
    options: {
      type: Array,
      required: true,
      validator: (options) =>
        options.every(({ value, text }) => ![value, text].includes(undefined)),
    },
  },
  emits: ['input'],
  data() {
    return {
      selected: null,
    };
  },
  computed: {
    showCustomValueMessage() {
      return this.defaultValue !== null && !this.disabled && this.value !== this.defaultValue;
    },
    text() {
      return this.options.find((option) => option.value === this.value)?.text || this.defaultText;
    },
  },
  methods: {
    resetToDefaultValue() {
      this.$emit('input', this.defaultValue);
    },
    handleInput(value) {
      this.$emit('input', value);
    },
  },
  i18n: {
    CUSTOM_VALUE_MESSAGE,
  },
};
</script>

<template>
  <gl-form-group :label-for="field">
    <template #label>
      {{ label }}
      <div v-if="description" class="label-description" data-testid="dropdown-input-description">
        {{ description }}
      </div>
    </template>

    <gl-collapsible-listbox
      :id="field"
      v-model="selected"
      :items="options"
      :toggle-text="text"
      :disabled="disabled"
      :header-text="sectionHeader"
      @select="handleInput"
    />

    <template v-if="showCustomValueMessage" #description>
      <gl-sprintf :message="$options.i18n.CUSTOM_VALUE_MESSAGE">
        <template #anchor="{ content }">
          <gl-link @click="resetToDefaultValue">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
  </gl-form-group>
</template>
