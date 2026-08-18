<script>
import { GlBadge, GlPopover } from '@gitlab/ui';

export default {
  name: 'ImmutableBadge',
  components: {
    GlBadge,
    GlPopover,
  },
  props: {
    tag: {
      type: Object,
      required: true,
    },
    tagRowId: {
      type: String,
      required: true,
    },
  },
  computed: {
    isImmutable() {
      return this.tag.protection?.immutable;
    },
  },
};
</script>

<template>
  <div v-if="isImmutable">
    <gl-badge :id="tagRowId" boundary="viewport" class="gl-ml-4" data-testid="immutable-badge">
      {{ s__('ContainerRegistry|immutable') }}
    </gl-badge>
    <gl-popover :target="tagRowId" data-testid="immutable-popover">
      {{ s__('ContainerRegistry|This container image tag cannot be overwritten or deleted.') }}
    </gl-popover>
  </div>
</template>
