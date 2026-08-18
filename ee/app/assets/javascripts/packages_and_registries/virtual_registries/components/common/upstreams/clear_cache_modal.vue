<script>
import { GlModal } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'UpstreamClearCacheModal',
  components: {
    GlModal,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
    upstreamName: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['primary', 'change', 'canceled'],
  computed: {
    clearUpstreamCacheModalTitle() {
      return this.upstreamName
        ? sprintf(s__('VirtualRegistry|Clear cache for %{upstreamName}?'), {
            upstreamName: this.upstreamName,
          })
        : '';
    },
  },
  modal: {
    primaryAction: {
      text: s__('VirtualRegistry|Clear cache'),
      attributes: {
        variant: 'danger',
        category: 'primary',
      },
    },
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="clear-upstream-cache-modal"
    modal-class="gl-break-words"
    size="sm"
    :title="clearUpstreamCacheModalTitle"
    :action-primary="$options.modal.primaryAction"
    :action-cancel="$options.modal.cancelAction"
    @canceled="$emit('canceled')"
    @primary="$emit('primary')"
    @change="$emit('change', $event)"
  >
    {{
      s__(
        'VirtualRegistry|Clearing the cache deletes all cached packages for this upstream and re-fetch them from the source. If the upstream is unavailable or misconfigured, jobs might fail. Are you sure you want to continue?',
      )
    }}
  </gl-modal>
</template>
