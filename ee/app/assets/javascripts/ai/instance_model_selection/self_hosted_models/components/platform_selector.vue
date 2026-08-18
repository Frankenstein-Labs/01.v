<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { SELF_HOSTED_MODEL_PLATFORMS } from '../constants';

export default {
  name: 'PlatformSelector',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    platform: {
      type: String,
      required: true,
    },
  },
  emits: ['update:platform'],
  computed: {
    toggleText() {
      return (
        this.$options.platforms.find((platform) => platform.value === this.platform)?.text || ''
      );
    },
  },
  methods: {
    onPlatformChange(newPlatform) {
      this.$emit('update:platform', newPlatform);
    },
  },
  platforms: [
    {
      text: __('API'),
      value: SELF_HOSTED_MODEL_PLATFORMS.API,
    },
    {
      text: s__('AdminSelfHostedModels|Amazon Bedrock'),
      value: SELF_HOSTED_MODEL_PLATFORMS.BEDROCK,
    },
    {
      text: s__('AdminSelfHostedModels|Google Vertex AI'),
      value: SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI,
    },
  ],
};
</script>

<template>
  <gl-collapsible-listbox
    :selected="platform"
    :items="$options.platforms"
    :toggle-text="toggleText"
    block
    @select="onPlatformChange"
  />
</template>
