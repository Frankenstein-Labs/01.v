<script>
import { GlButton, GlSprintf } from '@gitlab/ui';
import { __, sprintf, n__ } from '~/locale';

export default {
  name: 'PolicyExceptionsSelectedItem',
  components: {
    GlButton,
    GlSprintf,
  },
  props: {
    count: {
      type: Number,
      required: false,
      default: 1,
    },
    title: {
      type: String,
      required: true,
    },
    exceptionKey: {
      type: String,
      required: true,
    },
  },
  emits: ['remove', 'select-item'],
  computed: {
    buttonText() {
      const exceptions = n__('Exception', 'Exceptions', this.count);

      return sprintf(__('(%{count}) %{exceptions}'), {
        count: this.count,
        exceptions,
      });
    },
  },
  methods: {
    selectItem() {
      this.$emit('select-item', this.exceptionKey);
    },
    removeItem() {
      this.$emit('remove', this.exceptionKey);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-sprintf :message="__('%{title}: %{exceptions}')">
      <template #title>
        {{ title }}
      </template>
      <template #exceptions>
        <gl-button category="primary" variant="link" @click="selectItem">
          {{ buttonText }}
        </gl-button>
      </template>
    </gl-sprintf>

    <gl-button :aria-label="__('Remove')" category="tertiary" icon="remove" @click="removeItem" />
  </div>
</template>
