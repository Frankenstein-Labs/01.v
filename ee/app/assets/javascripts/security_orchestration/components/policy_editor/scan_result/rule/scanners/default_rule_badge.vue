<script>
import { uniqueId } from 'lodash-es';
import { GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    recommendedLabel: s__('SecurityOrchestration|Recommended selection'),
    applyButtonText: s__('SecurityOrchestration|Apply recommended selections'),
    popoverContent: s__(
      "SecurityOrchestration|Your policy is using GitLab's recommended settings for this scanner and optimized for industry best practices.",
    ),
  },
  name: 'DefaultRuleBadge',
  components: {
    GlBadge,
    GlButton,
    GlPopover,
  },
  props: {
    isDefaultConfiguration: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['reset'],
  data() {
    return {
      popoverTargetId: uniqueId('recommended-badge-'),
    };
  },
};
</script>

<template>
  <span class="gl-flex gl-items-center">
    <gl-badge
      v-if="isDefaultConfiguration"
      :id="popoverTargetId"
      variant="success"
      icon="status_warning"
      data-testid="default-rule-badge"
    >
      {{ $options.i18n.recommendedLabel }}
    </gl-badge>
    <gl-popover
      v-if="isDefaultConfiguration"
      :target="popoverTargetId"
      triggers="hover focus"
      placement="top"
      data-testid="recommended-popover"
    >
      {{ $options.i18n.popoverContent }}
    </gl-popover>
    <gl-button
      v-else
      variant="link"
      size="small"
      data-testid="reset-to-default-button"
      @click="$emit('reset')"
    >
      {{ $options.i18n.applyButtonText }}
    </gl-button>
  </span>
</template>
