<script>
import { GlModal } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { __ } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  components: {
    GlModal,
  },
  mixins: [glSlotsMixin],
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
  },
  emits: ['change', 'save-rule'],
  computed: {
    modalProps() {
      return {
        ...this.$attrs,
        title: this.title,
        modalId: uniqueId('add-protected-environment-modal'),
        actionPrimary: { text: __('Save') },
        actionSecondary: { text: __('Cancel') },
      };
    },
  },
};
</script>
<template>
  <gl-modal
    v-bind="modalProps"
    :visible="visible"
    static
    @primary="$emit('save-rule')"
    @change="$emit('change', $event)"
  >
    <template v-if="glSlots()['add-rule-form']" #default
      ><slot name="add-rule-form"></slot
    ></template>
  </gl-modal>
</template>
