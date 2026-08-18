<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';

export default {
  name: 'CustomStageEventField',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    eventType: {
      type: String,
      required: true,
    },
    eventsList: {
      type: Array,
      required: true,
    },
    fieldLabel: {
      type: String,
      required: true,
    },
    defaultDropdownText: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    isIdentifierValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    identifierError: {
      type: String,
      required: false,
      default: '',
    },
    initialValue: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['update-identifier'],
  data() {
    return { selectedValue: this.initialValue };
  },
  computed: {
    fieldName() {
      const { eventType, index } = this;
      return `custom-stage-${eventType}-${index}`;
    },
    selectedEvent() {
      return this.eventsList.find(({ value }) => value === this.selectedValue);
    },
    toggleText() {
      return this.selectedEvent?.text || this.defaultDropdownText;
    },
  },
  watch: {
    initialValue() {
      this.selectedValue = this.initialValue;
    },
  },
  methods: {
    itemSelected(value) {
      this.selectedValue = value;
      this.$emit('update-identifier', value);
    },
  },
};
</script>
<template>
  <gl-form-group
    class="gl-mr-2 gl-w-1/2"
    :data-testid="fieldName"
    :label="fieldLabel"
    :state="isIdentifierValid"
    :invalid-feedback="identifierError"
  >
    <gl-collapsible-listbox
      :items="eventsList"
      :selected="selectedValue"
      :disabled="disabled"
      :toggle-text="toggleText"
      :state="isIdentifierValid"
      block
      @select="itemSelected"
    />
  </gl-form-group>
</template>
