<script>
import { s__ } from '~/locale';
import ConfirmDangerModal from '~/vue_shared/components/confirm_danger/confirm_danger_modal.vue';

const MODAL_ID = 'artifact-registry-disable-modal';

export default {
  name: 'ArtifactRegistryDisableConfirmation',
  i18n: {
    // Two sentences, translated separately: each has to stay whole, and neither is
    // locked into the other's position.
    intent: s__('ArtifactRegistry|You are about to disable Artifact Registry.'),
    effect: s__('ArtifactRegistry|This will affect all projects currently using this registry.'),
  },
  components: {
    ConfirmDangerModal,
  },
  provide: {
    confirmButtonText: s__('ArtifactRegistry|Disable Artifact Registry'),
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    handle: {
      type: String,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change', 'confirm'],
  modalId: MODAL_ID,
};
</script>

<template>
  <confirm-danger-modal
    :visible="visible"
    :modal-id="$options.modalId"
    :phrase="handle"
    :confirm-loading="loading"
    @confirm="$emit('confirm')"
    @change="$emit('change', $event)"
  >
    <template #modal-body>
      <div data-testid="disable-consequences">
        <p>{{ $options.i18n.intent }}</p>
        <p>{{ $options.i18n.effect }}</p>
      </div>
    </template>
  </confirm-danger-modal>
</template>
