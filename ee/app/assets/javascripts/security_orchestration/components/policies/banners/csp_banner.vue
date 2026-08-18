<script>
import { GlAlert } from '@gitlab/ui';

export default {
  name: 'CspBanner',
  components: {
    GlAlert,
  },
};
</script>

<template>
  <gl-alert
    :dismissible="false"
    class="gl-mb-5"
    :title="s__('SecurityOrchestration|New compliance and security policy group')"
    variant="warning"
  >
    <p class="gl-mb-3">
      {{
        s__(
          'SecurityOrchestration|Use this compliance and security policy group to create security policies. Do not create new projects in this group.',
        )
      }}
    </p>
  </gl-alert>
</template>
