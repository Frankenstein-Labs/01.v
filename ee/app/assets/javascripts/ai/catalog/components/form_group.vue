<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'FormGroup',
  components: {
    GlFormGroup,
  },
  mixins: [glSlotsMixin],
  props: {
    field: {
      type: Object,
      required: true,
    },
    fieldValue: {
      type: [String, Number, Array],
      required: false,
      default: null,
    },
  },
  data() {
    return {
      state: true,
      invalidFeedback: null,
    };
  },
  computed: {
    hasLabelDescription() {
      return this.glSlots()['label-description'];
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- reset() is part of the component's public API, called via $refs by parent forms.
    reset() {
      this.state = true;
      this.invalidFeedback = null;
    },
    validate() {
      const { requiredLabel, maxLength } = this.field.validations;
      if (requiredLabel) {
        this.state = Boolean(this.fieldValue);
        this.invalidFeedback = requiredLabel;
      }
      if (maxLength && this.fieldValue?.length > maxLength) {
        this.state = this.fieldValue?.length <= maxLength;
        this.invalidFeedback = sprintf(s__('AICatalog|Input cannot exceed %{value} characters.'), {
          value: maxLength,
        });
      }
      return this.state;
    },
    onBlur() {
      this.validate();
    },
  },
};
</script>

<template>
  <gl-form-group
    v-bind="field.groupAttrs"
    :label="field.label"
    :label-for="field.id"
    :invalid-feedback="invalidFeedback"
    :state="state"
    class="gl-mb-0"
  >
    <div v-if="hasLabelDescription" data-testid="label-description" class="label-description">
      <slot name="label-description">{{ field.groupAttrs.labelDescription }}</slot>
    </div>
    <slot :state="state" :blur="onBlur"></slot>
  </gl-form-group>
</template>
