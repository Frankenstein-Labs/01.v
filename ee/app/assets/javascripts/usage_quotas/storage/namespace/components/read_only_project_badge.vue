<script>
import { GlBadge } from '@gitlab/ui';

export default {
  name: 'ReadOnlyProjectBadge',
  components: {
    GlBadge,
  },
  inject: ['aboveSizeLimit'],
  props: {
    namespace: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isReadOnly() {
      const repositorySize = Number(this.project?.statistics?.repositorySize);
      const lfsObjectsSize = Number(this.project?.statistics?.lfsObjectsSize);
      const isProjectAboveSizeLimit =
        repositorySize + lfsObjectsSize > this.namespace?.actualRepositorySizeLimit;

      return isProjectAboveSizeLimit && this.aboveSizeLimit;
    },
  },
};
</script>
<template>
  <gl-badge v-if="isReadOnly" variant="danger">{{ __('read-only') }}</gl-badge>
</template>
