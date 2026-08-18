<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AvailabilityPopover',
  components: {
    GlIcon,
    GlPopover,
  },
  POPOVER_TEXT: s__(
    'Workspaces|Blocked agents are not deleted and existing workspaces continue running. You can delete agents in their source project.',
  ),
};
</script>
<template>
  <div>
    <gl-icon id="question-icon" name="question-o" />
    <gl-popover target="question-icon">
      {{ $options.POPOVER_TEXT }}
    </gl-popover>
  </div>
</template>
