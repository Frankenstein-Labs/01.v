<script>
import { GlButton } from '@gitlab/ui';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__ } from '~/locale';

export default {
  name: 'ValueStreamFormContentActions',
  components: {
    GlButton,
  },
  inject: ['vsaPath', 'valueStreamGid'],
  props: {
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['click-primary-action'],
  computed: {
    isEditing() {
      return Boolean(this.valueStreamGid);
    },
    primaryButtonText() {
      return this.isEditing
        ? s__('CreateValueStreamForm|Save value stream')
        : s__('CreateValueStreamForm|New value stream');
    },
    cancelHref() {
      return this.isEditing
        ? mergeUrlParams({ value_stream_id: getIdFromGraphQLId(this.valueStreamGid) }, this.vsaPath)
        : this.vsaPath;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-3 @sm/panel:gl-w-auto @sm/panel:gl-flex-row">
    <gl-button
      data-testid="primary-button"
      variant="confirm"
      :loading="isLoading"
      @click="$emit('click-primary-action')"
      >{{ primaryButtonText }}</gl-button
    >
    <gl-button data-testid="cancel-button" :href="cancelHref" :disabled="isLoading">{{
      __('Cancel')
    }}</gl-button>
  </div>
</template>
