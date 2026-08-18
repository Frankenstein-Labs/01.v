<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    bannerTitle: s__('SecurityOrchestration|policy.yml file has syntax errors'),
    bannerDescription: s__(
      "SecurityOrchestration|Security policies cannot be enforced due to invalid YAML syntax in the linked security policy project's %{linkStart}policy.yml%{linkEnd}.",
    ),
  },
  name: 'InvalidPolicyYamlBanner',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
  },
  inject: ['assignedPolicyProject'],
  computed: {
    policyYamlPath() {
      return this.assignedPolicyProject?.policyYamlPath;
    },
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
    <gl-sprintf :message="$options.i18n.bannerDescription">
      <template #link="{ content }">
        <gl-link :href="policyYamlPath" target="_blank">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
  </gl-alert>
</template>
