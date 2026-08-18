<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

export default {
  name: 'DetailsHeaderEE',
  components: {
    ClipboardButton,
    GlAlert,
    GlButton,
    TitleArea,
  },
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
  },
  computed: {
    showActions() {
      return !this.isLoading && !this.showError;
    },
  },
};
</script>

<template>
  <title-area :title="data.title" :metadata-loading="isLoading">
    <template v-if="showActions" #right-actions>
      <gl-button
        :href="data.artifactRegistryImageUrl"
        icon="external-link"
        target="_blank"
        category="primary"
        variant="default"
      >
        {{ s__('GoogleArtifactRegistry|Open in Google Cloud') }}
      </gl-button>
    </template>
    <template v-if="showActions" #sub-header>
      <div class="gl-max-w-75">
        <span data-testid="uri" class="gl-break-all gl-font-bold gl-text-default">
          {{ data.uri }}
        </span>
        <clipboard-button
          :title="s__('GoogleArtifactRegistry|Copy image path')"
          :text="data.uri"
          category="tertiary"
          size="small"
        />
      </div>
    </template>
    <gl-alert v-if="showError" variant="danger" :dismissible="false">
      {{ s__('GoogleArtifactRegistry|An error occurred while fetching the artifact details.') }}
    </gl-alert>
  </title-area>
</template>
