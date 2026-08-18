<script>
import { GlEmptyState, GlDisclosureDropdown } from '@gitlab/ui';
import {
  ADD_STREAM,
  AUDIT_STREAMS_EMPTY_STATE_I18N,
  ADD_HTTP,
  ADD_GCP_LOGGING,
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  ADD_AMAZON_S3,
  DESTINATION_TYPE_AMAZON_S3,
} from '../../constants';

export default {
  name: 'StreamEmptyState',
  components: {
    GlEmptyState,
    GlDisclosureDropdown,
  },
  inject: ['emptyStateSvgPath'],
  emits: ['add'],
  computed: {
    destinationOptions() {
      return [
        {
          text: ADD_HTTP,
          action: () => {
            this.$emit('add', DESTINATION_TYPE_HTTP);
          },
          extraAttrs: {
            'data-testid': 'add-http-destination',
          },
        },
        {
          text: ADD_GCP_LOGGING,
          action: () => {
            this.$emit('add', DESTINATION_TYPE_GCP_LOGGING);
          },
          extraAttrs: {
            'data-testid': 'add-gcp-destination',
          },
        },
        {
          text: ADD_AMAZON_S3,
          action: () => {
            this.$emit('add', DESTINATION_TYPE_AMAZON_S3);
          },
          extraAttrs: {
            'data-testid': 'add-amazon-s3-destination',
          },
        },
      ];
    },
  },
  i18n: {
    ...AUDIT_STREAMS_EMPTY_STATE_I18N,
    ADD_STREAM,
  },
};
</script>

<template>
  <gl-empty-state
    :title="$options.i18n.TITLE"
    :description="$options.i18n.DESCRIPTION"
    :svg-path="emptyStateSvgPath"
    class="gl-mt-5"
  >
    <template #actions>
      <gl-disclosure-dropdown
        :toggle-text="$options.i18n.ADD_STREAM"
        category="primary"
        variant="confirm"
        data-testid="dropdown-toggle"
        :items="destinationOptions"
      />
    </template>
  </gl-empty-state>
</template>
