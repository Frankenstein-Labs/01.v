<script>
import { GlAlert, GlIcon, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'MissingSelfHostedModelsAlert',
  components: {
    GlAlert,
    GlLink,
    GlIcon,
  },
  props: {
    modelSelectionPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    bodyText() {
      return s__(
        'AiPowered|No self-hosted model is configured. AI requests route to GitLab-managed models until a self-hosted model is available.',
      );
    },
    linkText() {
      return s__('AiPowered|Configure self-hosted models');
    },
    selfHostedModelsPath() {
      // eslint-disable-next-line @gitlab/no-hardcoded-urls -- appending a Vue route segment to a server-provided base path
      return `${this.modelSelectionPath}/models`;
    },
  },
};
</script>
<template>
  <gl-alert :dismissible="false" variant="warning" class="gl-mt-3">
    {{ bodyText }}
    <gl-link :href="selfHostedModelsPath" data-testid="configure-self-hosted-models-link">
      {{ linkText }}
      <gl-icon name="arrow-right" variant="current" />
    </gl-link>
  </gl-alert>
</template>
