<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'UsageBillingForbiddenBanner',
  components: {
    GlAlert,
  },
  i18n: {
    bannerMessage: s__(
      'DuoAgentPlatform|Usage billing is not available for this account. To continue using GitLab Duo Agent Platform, contact your administrator.',
    ),
  },
};
</script>
<template>
  <gl-alert variant="danger" :dismissible="false" class="gl-rounded-none">
    {{ $options.i18n.bannerMessage }}
  </gl-alert>
</template>
