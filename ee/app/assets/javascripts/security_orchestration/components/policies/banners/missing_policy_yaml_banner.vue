<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    bannerTitle: s__('SecurityOrchestration|No policy.yml file found'),
    bannerDescription: s__(
      'SecurityOrchestration|The linked security policy project does not contain a %{linkStart}policy.yml%{linkEnd} file. Merge the policy changes to create the file, or add it manually.',
    ),
  },
  name: 'MissingPolicyYamlBanner',
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
