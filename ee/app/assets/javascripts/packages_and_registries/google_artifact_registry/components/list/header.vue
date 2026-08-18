<script>
import { GlAlert, GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';

export default {
  name: 'ListHeaderEE',
  components: {
    GlAlert,
    GlButton,
    MetadataItem,
    TitleArea,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['settingsPath'],
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    showError: {
      type: Boolean,
      required: false,
      default: false,
    },
    showExternalLink: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    showMetadata() {
      return !this.showError;
    },
    showActions() {
      return !this.isLoading && !this.showError;
    },
    projectIdMetadata() {
      return sprintf(s__('GoogleArtifactRegistry|Project ID: %{projectId}'), {
        projectId: this.data.projectId,
      });
    },
    repositoryMetadata() {
      return sprintf(s__('GoogleArtifactRegistry|Repository: %{repository}'), {
        repository: this.data.repository,
      });
    },
  },
  i18n: {
    settingsText: s__('GoogleArtifactRegistry|Configure in settings'),
  },
};
</script>

<template>
  <title-area :title="__('Google Artifact Registry')" :metadata-loading="isLoading">
    <template v-if="showActions" #right-actions>
      <gl-button
        v-if="showExternalLink"
        :href="data.artifactRegistryRepositoryUrl"
        icon="external-link"
        data-testid="external-link"
        target="_blank"
        category="primary"
        variant="default"
      >
        {{ s__('GoogleArtifactRegistry|Open in Google Cloud') }}
      </gl-button>
      <gl-button
        v-if="settingsPath"
        v-gl-tooltip="$options.i18n.settingsText"
        icon="settings"
        data-testid="settings-link"
        :href="settingsPath"
        :aria-label="$options.i18n.settingsText"
      />
    </template>
    <template v-if="showMetadata" #metadata-repository>
      <metadata-item
        data-testid="repository-name"
        icon="folder"
        :text="repositoryMetadata"
        size="l"
      />
    </template>
    <template v-if="showMetadata" #metadata-project>
      <metadata-item data-testid="project-id" icon="project" :text="projectIdMetadata" size="l" />
    </template>
    <gl-alert v-if="showError" variant="danger" :dismissible="false">
      {{ s__('GoogleArtifactRegistry|An error occurred while fetching the artifacts.') }}
    </gl-alert>
  </title-area>
</template>
