<script>
import { GlDisclosureDropdownItem, GlModalDirective } from '@gitlab/ui';
import { __ } from '~/locale';

import DeleteModal from './self_hosted_model_delete_modal.vue';
import CannotDeleteModal from './self_hosted_model_cannot_delete_modal.vue';

export default {
  name: 'DeleteSelfHostedModelDisclosureItem',
  components: {
    DeleteModal,
    CannotDeleteModal,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlModalDirective,
  },
  props: {
    model: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    label: __('Delete'),
  },
  computed: {
    featureSettings() {
      return this.model.featureSettings?.nodes || [];
    },
    canDelete() {
      return this.featureSettings.length === 0;
    },
    modalId() {
      const baseId = `delete-${this.model.name}-model-modal`;
      return this.canDelete ? baseId : `cannot-${baseId}`;
    },
  },
};
</script>
<template>
  <div>
    <gl-disclosure-dropdown-item
      v-gl-modal-directive="modalId"
      :aria-label="$options.i18n.label"
      variant="danger"
    >
      <template #list-item>
        <span class="gl-text-danger">{{ $options.i18n.label }}</span>
      </template>
    </gl-disclosure-dropdown-item>
    <delete-modal v-if="canDelete" :id="modalId" :model="model" />
    <cannot-delete-modal v-else :id="modalId" :model="model" />
  </div>
</template>
