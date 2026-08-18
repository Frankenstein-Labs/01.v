<script>
import { GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    published: s__('IncidentManagement|Published to status page'),
  },
  components: {
    GlIcon,
  },
  props: {
    statusPagePublishedIncident: {
      type: Boolean,
      required: false,
      default: null,
    },
    unPublished: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div data-testid="published-cell">
    <gl-icon
      v-if="statusPagePublishedIncident"
      name="status_success"
      :aria-label="$options.i18n.published"
      variant="success"
    />
    <div v-else>{{ unPublished }}</div>
  </div>
</template>
