<script>
import { mapState } from 'pinia';
import { GlButton } from '@gitlab/ui';
import Configuration from '~/integrations/edit/components/sections/configuration.vue';
import Connection from '~/integrations/edit/components/sections/connection.vue';
import { useIntegrationForm } from '~/integrations/edit/store';
import ConfigurationInstructions from 'ee/integrations/edit/components/google_artifact_management/configuration_instructions.vue';
import EmptyState from 'ee/integrations/edit/components/google_artifact_management/empty_state.vue';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';

const PROJECT_ID_FIELD_NAME = 'artifact_registry_project_id';

export default {
  name: 'IntegrationSectionGoogleArtifactManagement',
  components: {
    Configuration,
    ConfigurationInstructions,
    Connection,
    EmptyState,
    GlButton,
    SettingsSection,
  },
  props: {
    isValidated: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggle-integration-active'],
  data() {
    return {
      googleCloudProjectId: null,
    };
  },
  computed: {
    ...mapState(useIntegrationForm, ['propsSource']),
    dynamicFields() {
      return this.propsSource.fields;
    },
    artifactRegistryPath() {
      return this.propsSource.googleArtifactManagementProps?.artifactRegistryPath;
    },
    operating() {
      return this.propsSource.operating;
    },
    editable() {
      return this.propsSource.editable;
    },
    workloadIdentityFederationPath() {
      return this.propsSource.googleArtifactManagementProps?.workloadIdentityFederationPath ?? '#';
    },
    propsSourceGoogleCloudProjectId() {
      return (
        this.propsSource.fields.find((field) => field.name === PROJECT_ID_FIELD_NAME)?.value ?? ''
      );
    },
    derivedGoogleCloudProjectId() {
      if (this.googleCloudProjectId === null) {
        return this.propsSourceGoogleCloudProjectId;
      }
      return this.googleCloudProjectId;
    },
  },
  methods: {
    updateGoogleCloudProjectId({ value, field }) {
      if (field.name === PROJECT_ID_FIELD_NAME) {
        this.googleCloudProjectId = value;
      }
    },
  },
};
</script>

<template>
  <div v-if="editable">
    <template v-if="operating">
      <div class="gl-border-b gl-mb-6 gl-flex gl-gap-3 gl-pb-6">
        <gl-button
          :href="artifactRegistryPath"
          icon="deployments"
          category="primary"
          variant="default"
        >
          {{ s__('GoogleArtifactRegistry|View artifacts') }}
        </gl-button>
      </div>
    </template>
    <connection @toggle-integration-active="$emit('toggle-integration-active', $event)" />
    <settings-section
      :heading="s__('GoogleArtifactRegistry|1. Repository')"
      :description="
        s__(
          'GoogleArtifactRegistry|To improve security, use a Google Cloud project for resources only, separate from CI/CD and identity management projects.',
        )
      "
    >
      <configuration
        :fields="dynamicFields"
        :is-validated="isValidated"
        @update="updateGoogleCloudProjectId"
      />
    </settings-section>
    <configuration-instructions :id="derivedGoogleCloudProjectId" />
  </div>
  <empty-state v-else :path="workloadIdentityFederationPath" />
</template>
