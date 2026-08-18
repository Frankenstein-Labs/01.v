<script>
import { GlPopover } from '@gitlab/ui';
import { SCAN_PROFILE_I18N } from '~/security_configuration/constants';

const i18n = {
  tooltipTitle: SCAN_PROFILE_I18N.tooltipTitle,
  accessLevelTooltipDescription: SCAN_PROFILE_I18N.accessLevelTooltipDescription,
};

export default {
  name: 'InsufficientPermissionsPopover',
  components: {
    GlPopover,
  },
  props: {
    target: {
      type: String,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'top',
    },
  },
  i18n,
};
</script>

<template>
  <gl-popover :target="target" :placement="placement" boundary="viewport">
    <template #title>
      {{ $options.i18n.tooltipTitle }}
    </template>
    {{ $options.i18n.accessLevelTooltipDescription }}
  </gl-popover>
</template>
