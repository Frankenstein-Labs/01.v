<script>
import { GlButton, GlAnimatedChevronRightDownIcon } from '@gitlab/ui';
import PermissionCheckbox from './permission_checkbox.vue';

export default {
  name: 'PermissionCategory',
  components: { GlButton, PermissionCheckbox, GlAnimatedChevronRightDownIcon },
  props: {
    category: {
      type: Object,
      required: true,
    },
    baseAccessLevel: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['change'],
  data() {
    return {
      isExpanded: true,
    };
  },
};
</script>

<template>
  <div class="gl-mb-4 last:gl-mb-5">
    <gl-button
      button-text-classes="gl-text-size-h4 gl-flex gl-text-black gl-font-bold"
      variant="link"
      :aria-expanded="isExpanded"
      @click="isExpanded = !isExpanded"
    >
      <gl-animated-chevron-right-down-icon :is-on="isExpanded" class="gl-mr-2" />
      {{ category.name }}
    </gl-button>

    <ul v-if="isExpanded" class="gl-mb-6 gl-mt-5 gl-list-none gl-pl-0">
      <permission-checkbox
        v-for="permission in category.permissions"
        :key="permission.value"
        :permission="permission"
        :base-access-level="baseAccessLevel"
        @change="$emit('change', $event)"
      />
    </ul>
  </div>
</template>
