<script>
import { GlBadge, GlPopover } from '@gitlab/ui';

export default {
  components: {
    GlPopover,
    GlBadge,
  },
};
</script>

<template>
  <div ref="popover">
    <gl-badge
      variant="neutral"
      icon="flag"
      :aria-label="s__('Vulnerability|Policy violation detected')"
    />
    <gl-popover
      :target="() => $refs.popover"
      placement="top"
      :title="s__('Vulnerability|Detected by a security policy')"
      :content="
        s__(
          'Vulnerability|This vulnerability was bypassed by a user in a merge request. The user accepted the risk in a security policy configured to use warn mode.',
        )
      "
    />
  </div>
</template>
