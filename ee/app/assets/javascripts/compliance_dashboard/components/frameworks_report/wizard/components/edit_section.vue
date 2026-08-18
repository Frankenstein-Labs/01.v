<script>
import { GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'EditSection',
  components: {
    GlBadge,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    itemsCount: {
      type: Number,
      required: false,
      default: null,
    },
    isRequired: {
      type: Boolean,
      required: false,
      default: false,
    },
    isCompleted: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    showItemsCount() {
      return this.itemsCount !== null;
    },
    isSuccessState() {
      return this.itemsCount > 0 || this.isCompleted;
    },
  },
  i18n: {
    required: s__('ComplianceFrameworks|Required'),
    optional: s__('ComplianceFrameworks|Optional'),
  },
};
</script>

<template>
  <div class="gl-mb-1">
    <div class="gl-flex gl-items-center gl-bg-strong gl-p-5">
      <div class="gl-grow">
        <div class="gl-flex gl-items-center">
          <h3 class="gl-heading-3 gl-mb-2">{{ title }}</h3>
          <gl-badge
            v-if="showItemsCount"
            class="gl-mb-2 gl-ml-3"
            variant="neutral"
            data-testid="count-badge"
            >{{ itemsCount }}</gl-badge
          >
        </div>
        <span>{{ description }}</span>
      </div>
      <gl-badge
        :variant="isSuccessState ? 'success' : 'neutral'"
        :icon="isSuccessState ? 'check-circle' : ''"
        class="gl-mx-3 gl-px-3 gl-py-2"
        data-testid="status-badge"
      >
        {{ isRequired ? $options.i18n.required : $options.i18n.optional }}
      </gl-badge>
    </div>
    <div class="gl-bg-subtle">
      <div class="gl-px-5 gl-py-6">
        <slot></slot>
      </div>
    </div>
  </div>
</template>
