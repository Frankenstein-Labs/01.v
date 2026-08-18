<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'PolicyAutoDismissedBadge',
  components: {
    GlPopover,
    GlBadge,
  },
  i18n: {
    title: s__('Vulnerability|Auto-dismissed by a security policy'),
    content: s__('Vulnerability|This vulnerability was auto-dismissed by a security policy.'),
  },
};
</script>

<template>
  <div ref="popover">
    <gl-badge variant="neutral" icon="clear-all" :aria-label="$options.i18n.title" />
    <gl-popover
      :target="() => $refs.popover"
      placement="top"
      :title="$options.i18n.title"
      :content="$options.i18n.content"
    />
  </div>
</template>
