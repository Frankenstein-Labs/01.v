<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    bannerTitle: s__('SecurityOrchestration|Policies are invalid'),
    bannerDescription: s__(
      'SecurityOrchestration|No policies in the security policy project will be enforced until the invalid policies are fixed.',
    ),
  },
  name: 'InvalidPoliciesBanner',
  components: {
    GlAlert,
  },
};
</script>

<template>
  <gl-alert
    variant="danger"
    :title="$options.i18n.bannerTitle"
    class="gl-mb-5"
    :dismissible="false"
  >
    <p>{{ $options.i18n.bannerDescription }}</p>
  </gl-alert>
</template>
