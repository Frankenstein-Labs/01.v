<script>
import { GlFormCheckbox } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import ApprovalSettingsLockedIcon from './approval_settings_locked_icon.vue';

export default {
  name: 'ApprovalSettingsCheckbox',
  components: {
    ApprovalSettingsLockedIcon,
    GlFormCheckbox,
  },
  mixins: [glSlotsMixin],
  props: {
    label: {
      type: String,
      required: true,
    },
    checked: {
      type: Boolean,
      required: false,
      default: false,
    },
    locked: {
      type: Boolean,
      required: false,
      default: false,
    },
    lockedText: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['change', 'input'],
  methods: {
    input(value) {
      this.$emit('input', value);
    },
    change(value) {
      this.$emit('change', value);
    },
  },
};
</script>

<template>
  <gl-form-checkbox :disabled="locked" :checked="checked" @input="input" @change="change">
    {{ label }}
    <approval-settings-locked-icon v-if="locked" :label="label" :locked-text="lockedText" />
    <template v-if="glSlots().help" #help>
      <slot name="help"></slot>
    </template>
  </gl-form-checkbox>
</template>
