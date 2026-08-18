<script>
import { GlLink } from '@gitlab/ui';

export default {
  name: 'HeaderMergeTrainsLink',
  components: {
    GlLink,
  },
  inject: ['mergeTrainsAvailable', 'mergeTrainsPath', 'canReadMergeTrain'],
};
</script>

<template>
  <gl-link v-if="mergeTrainsAvailable && canReadMergeTrain" :href="mergeTrainsPath">
    {{ s__('Pipelines|View merge train details') }}
  </gl-link>
</template>
