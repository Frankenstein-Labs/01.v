<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlModal,
  GlModalDirective,
  GlSprintf,
  GlToastMixin,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { slugifyWithUnderscore } from '~/lib/utils/text_utility';
import { sprintf, __, s__ } from '~/locale';
import Tracking from '~/tracking';
import { dismissGlobalAlertById } from '~/lib/utils/global_alerts';
import { VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID } from '../vsa_settings/constants';

const i18n = {
  DELETE_NAME: s__('DeleteValueStream|Delete %{name}'),
  DELETE_CONFIRMATION: s__(
    'DeleteValueStream|Are you sure you want to delete the "%{name}" Value Stream?',
  ),
  DELETED: s__("DeleteValueStream|'%{name}' Value Stream deleted"),
  DELETE: __('Delete'),
  CREATE_VALUE_STREAM: s__('CreateValueStreamForm|New value stream'),
  CANCEL: __('Cancel'),
  EDIT_VALUE_STREAM: __('Edit'),
};

export default {
  name: 'ValueStreamSelect',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlModal,
    GlSprintf,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [Tracking.mixin(), GlToastMixin],
  inject: ['newValueStreamPath', 'editValueStreamPath'],
  props: {
    canEdit: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
  computed: {
    ...mapState({
      isDeleting: 'isDeletingValueStream',
      deleteValueStreamError: 'deleteValueStreamError',
      data: 'valueStreams',
      selectedValueStream: 'selectedValueStream',
    }),
    listBoxData() {
      return (
        this.data?.map(({ id: value, name: streamName }) => ({ value, text: streamName })) || []
      );
    },
    hasValueStreams() {
      return Boolean(this.data.length);
    },
    selectedValueStreamName() {
      return this.selectedValueStream?.name || '';
    },
    selectedValueStreamId() {
      return this.selectedValueStream?.id || null;
    },
    isCustomValueStream() {
      return this.selectedValueStream?.isCustom || false;
    },
    editValueStreamButtonHref() {
      if (!this.selectedValueStreamId) return null;

      return this.editValueStreamPath.replace(':id', this.selectedValueStreamId);
    },
  },
  methods: {
    ...mapActions(['setSelectedValueStream', 'deleteValueStream']),
    onSuccess(message) {
      this.$toast.show(message);
    },
    onSelect(selectedId) {
      const selectedItem = this.data.find(({ id }) => id === selectedId);
      this.track('click_dropdown', { label: this.slugify(selectedItem?.name) });
      this.setSelectedValueStream(selectedItem);
    },
    onDelete() {
      dismissGlobalAlertById(VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID);

      const name = this.selectedValueStreamName;
      return this.deleteValueStream(this.selectedValueStreamId).then(() => {
        if (!this.deleteValueStreamError) {
          this.onSuccess(sprintf(this.$options.i18n.DELETED, { name }));
          this.track('delete_value_stream', { extra: { name } });
        }
      });
    },
    slugify(valueStreamTitle) {
      return slugifyWithUnderscore(valueStreamTitle);
    },
  },
  i18n,
};
</script>
<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <label class="gl-m-0">{{ s__('ValueStreamAnalytics|Value stream') }}</label>
    <gl-collapsible-listbox
      v-if="hasValueStreams"
      data-testid="dropdown-value-streams"
      :items="listBoxData"
      :toggle-text="selectedValueStreamName"
      :selected="selectedValueStreamId"
      @select="onSelect"
    >
      <template v-if="canEdit" #footer>
        <div class="gl-border-t gl-p-2">
          <gl-button
            class="gl-w-full !gl-justify-start"
            category="tertiary"
            :href="newValueStreamPath"
            data-testid="create-value-stream-option"
            data-track-action="click_dropdown"
            data-track-label="create_value_stream_form_open"
            >{{ $options.i18n.CREATE_VALUE_STREAM }}</gl-button
          >
          <gl-button
            v-if="isCustomValueStream"
            v-gl-modal-directive="'delete-value-stream-modal'"
            class="gl-w-full !gl-justify-start"
            category="tertiary"
            variant="danger"
            data-testid="delete-value-stream"
            data-track-action="click_dropdown"
            data-track-label="delete_value_stream_form_open"
          >
            <gl-sprintf :message="$options.i18n.DELETE_NAME">
              <template #name>{{ selectedValueStreamName }}</template>
            </gl-sprintf>
          </gl-button>
        </div>
      </template>
    </gl-collapsible-listbox>
    <gl-button
      v-if="isCustomValueStream && canEdit"
      :href="editValueStreamButtonHref"
      data-testid="edit-value-stream"
      data-track-action="click_button"
      data-track-label="edit_value_stream_form_open"
      >{{ $options.i18n.EDIT_VALUE_STREAM }}</gl-button
    >
    <gl-button
      v-if="!hasValueStreams"
      :href="newValueStreamPath"
      data-testid="create-value-stream-button"
      data-track-action="click_button"
      data-track-label="create_value_stream_form_open"
      >{{ $options.i18n.CREATE_VALUE_STREAM }}</gl-button
    >
    <gl-modal
      data-testid="delete-value-stream-modal"
      modal-id="delete-value-stream-modal"
      :title="__('Delete Value Stream')"
      :action-primary="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: $options.i18n.DELETE,
        attributes: { variant: 'danger', loading: isDeleting },
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      :action-cancel="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: $options.i18n.CANCEL,
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      @primary.prevent="onDelete"
    >
      <gl-alert v-if="deleteValueStreamError" variant="danger">{{
        deleteValueStreamError
      }}</gl-alert>
      <p>
        <gl-sprintf :message="$options.i18n.DELETE_CONFIRMATION">
          <template #name>{{ selectedValueStreamName }}</template>
        </gl-sprintf>
      </p>
    </gl-modal>
  </div>
</template>
