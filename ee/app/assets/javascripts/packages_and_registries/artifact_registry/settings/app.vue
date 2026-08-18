<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import ActivationSection from './activation_section.vue';

export default {
  name: 'ArtifactRegistrySettingsApp',
  components: { ActivationSection, GlAlert, SettingsBlock },
  data() {
    return {
      announcement: null,
    };
  },
  methods: {
    announce(variant, message) {
      this.announcement = { variant, message };
    },
  },
  i18n: {
    activationTitle: s__('ArtifactRegistry|Activation'),
    activationDescription: s__(
      'ArtifactRegistry|Control artifact registry access for this organization. When enabled, all projects and groups have access to a unified registry.',
    ),
  },
};
</script>

<template>
  <settings-block
    :title="$options.i18n.activationTitle"
    expanded
    data-testid="artifact-registry-settings"
  >
    <template #description>{{ $options.i18n.activationDescription }}</template>
    <template #default>
      <gl-alert
        v-if="announcement"
        :variant="announcement.variant"
        class="gl-mb-5"
        data-testid="settings-alert-region"
        @dismiss="announcement = null"
      >
        {{ announcement.message }}
      </gl-alert>

      <activation-section
        @success="announce('success', $event)"
        @error="announce('danger', $event)"
      />
    </template>
  </settings-block>
</template>
