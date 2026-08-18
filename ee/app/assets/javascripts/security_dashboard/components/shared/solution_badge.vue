<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlPopover,
    GlBadge,
  },
  i18n: {
    title: s__('Vulnerability|A solution is available for this vulnerability'),
    message: s__(
      'Vulnerability|Create a merge request to implement this solution, or download and apply the patch manually.',
    ),
  },
};
</script>

<template>
  <div ref="popover">
    <gl-badge variant="neutral" icon="bulb" :aria-label="$options.i18n.title" />
    <gl-popover
      :target="() => $refs.popover"
      placement="top"
      :title="$options.i18n.title"
      :content="$options.i18n.message"
    />
  </div>
</template>
