<script>
import {
  GlButtonGroup,
  GlButton,
  GlModal,
  GlSprintf,
  GlModalDirective,
  GlLink,
  GlIcon,
  GlDisclosureDropdown,
} from '@gitlab/ui';
import { __, sprintf } from '~/locale';

export default {
  name: 'GeoListBulkActions',
  components: {
    GlButtonGroup,
    GlButton,
    GlModal,
    GlSprintf,
    GlLink,
    GlIcon,
    GlDisclosureDropdown,
  },
  directives: {
    GlModalDirective,
  },
  inject: {
    itemTitle: {
      type: String,
    },
  },
  props: {
    bulkActions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['bulk-action'],
  data() {
    return {
      modalAction: null,
    };
  },
  computed: {
    modalTitle() {
      if (!this.modalAction) {
        return null;
      }

      return sprintf(this.modalAction.modal.title, {
        type: this.itemTitle,
      });
    },
    modalDescription() {
      return sprintf(this.modalAction.modal.description, {
        type: this.itemTitle,
      });
    },
    modalHelpLink() {
      return this.modalAction.modal.helpLink;
    },
  },
  methods: {
    setModalData(action) {
      this.modalAction = action;
    },
    formatAdditionalActions(actions) {
      return actions.map((action) => {
        return {
          text: action.text,
          extraAttrs: action,
        };
      });
    },
    handleAdditionalAction(action) {
      this.setModalData(action.extraAttrs);
      this.$refs[this.$options.GEO_BULK_ACTION_MODAL_ID].show();
    },
  },
  GEO_BULK_ACTION_MODAL_ID: 'geo-bulk-action',
  modal: {
    actionPrimary: {
      text: __('Confirm'),
      attributes: {
        variant: 'confirm',
      },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <div>
    <gl-button-group v-for="action in bulkActions" :key="action.id" class="gl-ml-3">
      <gl-button
        v-gl-modal-directive="$options.GEO_BULK_ACTION_MODAL_ID"
        :icon="action.icon"
        :data-testid="action.id"
        @click="setModalData(action)"
      >
        {{ action.text }}
      </gl-button>
      <gl-disclosure-dropdown
        v-if="action.additionalActions"
        :items="formatAdditionalActions(action.additionalActions)"
        @action="handleAdditionalAction"
      />
    </gl-button-group>
    <gl-modal
      :ref="$options.GEO_BULK_ACTION_MODAL_ID"
      :modal-id="$options.GEO_BULK_ACTION_MODAL_ID"
      :title="modalTitle"
      size="sm"
      no-focus-on-show
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="$emit('bulk-action', modalAction)"
    >
      <template v-if="modalAction">
        <gl-sprintf :message="modalDescription">
          <template #type>{{ itemTitle }}</template>
        </gl-sprintf>
        <div v-if="modalHelpLink" class="gl-mt-3">
          <gl-link :href="modalHelpLink.href"
            ><gl-icon name="question" class="gl-mr-2" />{{ modalHelpLink.text }}</gl-link
          >
        </div>
      </template>
    </gl-modal>
  </div>
</template>
