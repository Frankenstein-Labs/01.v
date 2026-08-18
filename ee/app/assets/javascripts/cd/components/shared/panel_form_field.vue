<script>
import { GlFormGroup } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'PanelFormField',
  components: {
    GlFormGroup,
  },
  mixins: [glSlotsMixin],
  props: {
    label: {
      type: String,
      required: true,
    },
    additionalText: {
      type: String,
      required: false,
      default: '',
    },
    helpText: {
      type: String,
      required: false,
      default: '',
    },
    id: {
      type: String,
      required: false,
      default: '',
    },
    state: {
      type: Boolean,
      required: false,
      default: null,
      validator: (value) => value === null || typeof value === 'boolean',
    },
    invalidFeedback: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>

<template>
  <gl-form-group :label-for="id" :state="state" :invalid-feedback="invalidFeedback">
    <template #label>
      <div
        class="gl-flex gl-flex-wrap gl-justify-between gl-text-xs gl-text-subtle"
        data-testid="label"
      >
        <span class="gl-uppercase gl-tracking-wider">{{ label }}</span>
        <span v-if="additionalText" class="gl-font-normal">{{ additionalText }}</span>
      </div>
    </template>

    <template v-if="glSlots().default" #default><slot></slot></template>

    <template v-if="helpText" #description>
      <span data-testid="help-text" class="gl-text-sm">
        {{ helpText }}
      </span>
    </template>
  </gl-form-group>
</template>
