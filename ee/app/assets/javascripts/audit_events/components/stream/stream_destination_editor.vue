<script>
import { GlAlert, GlForm, GlFormGroup, GlFormInput, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createDestination, updateDestination } from '../../graphql/apollo';
import { getFormattedFormItem } from '../../utils';
import {
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
} from '../../constants';
import StreamDestinationEditorHttpFields from './stream_destination_editor_http_fields.vue';
import StreamDestinationEditorAwsFields from './stream_destination_editor_aws_fields.vue';
import StreamDestinationEditorGcpFields from './stream_destination_editor_gcp_fields.vue';
import StreamEventTypeFilters from './stream_event_type_filters.vue';
import StreamNamespaceFilters from './stream_namespace_filters.vue';
import StreamDeleteModal from './stream_delete_modal.vue';

export default {
  name: 'StreamDestinationEditor',
  components: {
    GlAlert,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlButton,
    StreamDestinationEditorHttpFields,
    StreamDestinationEditorAwsFields,
    StreamDestinationEditorGcpFields,
    StreamEventTypeFilters,
    StreamNamespaceFilters,
    StreamDeleteModal,
  },
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['deleted', 'error', 'updated', 'added', 'cancel'],
  data() {
    return {
      formItem: getFormattedFormItem(this.item),
      loading: false,
      errors: [],
    };
  },
  computed: {
    isUpdatingExistingItem() {
      return Boolean(this.formItem.id);
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    isSubmitButtonDisabled() {
      if (!this.formItem.name || this.formItem.shouldDisableSubmitButton) {
        return true;
      }

      return this.hasNoChanges;
    },
    hasNoChanges() {
      return (
        JSON.stringify(this.item.config) === JSON.stringify(this.formItem.config) &&
        this.item.secretToken === this.formItem.secretToken &&
        this.item.name === this.formItem.name &&
        !this.eventTypeFiltersToAdd.length &&
        !this.eventTypeFiltersToRemove.length &&
        !this.namespacePathsToAdd.length &&
        !this.namespaceFiltersToRemove.length
      );
    },
    submitButtonName() {
      return this.isUpdatingExistingItem
        ? s__('AuditStreams|Save external stream destination')
        : s__('AuditStreams|Add external stream destination');
    },
    submitButtonText() {
      return this.isUpdatingExistingItem ? __('Save') : __('Add');
    },
    eventTypeFiltersToAdd() {
      return this.formItem.eventTypeFilters.filter((e) => !this.item.eventTypeFilters.includes(e));
    },
    eventTypeFiltersToRemove() {
      return this.item.eventTypeFilters.filter((e) => !this.formItem.eventTypeFilters.includes(e));
    },
    originalNamespaceFilters() {
      return this.item.namespaceFilters || [];
    },
    originalNamespacePaths() {
      return this.originalNamespaceFilters.map((f) => f.namespace.fullPath);
    },
    formNamespacePaths() {
      return (this.formItem.namespaceFilters || []).map((f) => f.namespace);
    },
    namespacePathsToAdd() {
      return this.formNamespacePaths.filter((p) => !this.originalNamespacePaths.includes(p));
    },
    namespaceFiltersToRemove() {
      return this.originalNamespaceFilters.filter(
        (f) => !this.formNamespacePaths.includes(f.namespace.fullPath),
      );
    },
  },
  watch: {
    item: {
      handler(newItem) {
        this.formItem = getFormattedFormItem(newItem);
      },
      deep: true,
    },
  },
  methods: {
    onDeleting() {
      this.loading = true;
    },
    onDelete() {
      this.$emit('deleted', this.item.id);
      this.loading = false;
    },
    onDeleteError(error) {
      this.loading = false;
      this.errors.push(
        s__(
          'AuditStreams|An error occurred when deleting external audit event stream destination. Please try it again.',
        ),
      );
      Sentry.captureException(error);
      this.$emit('error');
    },
    clearError(index) {
      this.errors.splice(index, 1);
    },
    deleteDestination() {
      this.$refs.deleteModal.show();
    },
    async formSubmission() {
      this.loading = true;
      this.errors = [];

      try {
        const { errors } = this.isUpdatingExistingItem
          ? await updateDestination({
              $apollo: this.$apollo,
              destination: {
                ...this.formItem,
                originalNamespaceFilters: this.originalNamespaceFilters,
              },
              isInstance: this.isInstance,
              groupPath: this.groupPath,
              eventTypeFiltersToAdd: this.eventTypeFiltersToAdd,
              eventTypeFiltersToRemove: this.eventTypeFiltersToRemove,
              namespacePathsToAdd: this.namespacePathsToAdd,
              namespaceFiltersToRemove: this.namespaceFiltersToRemove,
            })
          : await createDestination({
              $apollo: this.$apollo,
              destination: this.formItem,
              isInstance: this.isInstance,
              groupPath: this.groupPath,
              eventTypeFiltersToAdd: this.eventTypeFiltersToAdd,
              namespacePathsToAdd: this.namespacePathsToAdd,
            });

        if (errors.length) {
          this.errors.push(...errors);
          this.$emit('error');
          return;
        }
        this.$emit(this.isUpdatingExistingItem ? 'updated' : 'added');
      } catch (error) {
        const defaultErrorMessage = this.isUpdatingExistingItem
          ? s__(
              'AuditStreams|An error occurred when updating external audit event stream destination. Please try it again.',
            )
          : s__(
              'AuditStreams|An error occurred when creating external audit event stream destination. Please try it again.',
            );
        this.errors.push(defaultErrorMessage);
        Sentry.captureException(error);
        this.$emit('error');
      } finally {
        this.loading = false;
      }
    },
  },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
};
</script>

<template>
  <div class="gl-pb-5 gl-pl-6 gl-pr-0">
    <gl-alert
      v-if="!isUpdatingExistingItem"
      :title="s__('AuditStreams|Destinations receive all audit event data')"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="data-warning"
      variant="warning"
    >
      {{
        s__(
          'AuditStreams|This could include sensitive information. Make sure you trust the destination endpoint.',
        )
      }}
    </gl-alert>

    <gl-alert
      v-for="(error, index) in errors"
      :key="index"
      :dismissible="true"
      class="gl-mb-5"
      data-testid="alert-errors"
      variant="danger"
      @dismiss="clearError(index)"
    >
      {{ error }}
    </gl-alert>

    <gl-form data-testid="destination-form" @submit.prevent="formSubmission">
      <gl-form-group
        :label="s__('AuditStreams|Destination Name')"
        data-testid="destination-name-form-group"
      >
        <gl-form-input v-model="formItem.name" data-testid="destination-name" />
      </gl-form-group>

      <stream-destination-editor-http-fields
        v-if="formItem.category === $options.DESTINATION_TYPE_HTTP"
        v-model="formItem"
        :is-editing="isUpdatingExistingItem"
        :loading="loading"
      />

      <stream-destination-editor-aws-fields
        v-if="formItem.category === $options.DESTINATION_TYPE_AMAZON_S3"
        v-model="formItem"
        :is-editing="isUpdatingExistingItem"
      />

      <stream-destination-editor-gcp-fields
        v-if="formItem.category === $options.DESTINATION_TYPE_GCP_LOGGING"
        v-model="formItem"
        :is-editing="isUpdatingExistingItem"
      />

      <div class="gl-mb-5">
        <label class="gl-block gl-text-lg" data-testid="filtering-header">{{
          s__('AuditStreams|Event filtering (optional)')
        }}</label>
        <div>
          <label
            class="gl-mb-3 gl-mt-5 gl-block"
            for="audit-event-type-filter"
            data-testid="event-type-filtering-header"
            >{{ s__('AuditStreams|Filter by audit event type') }}</label
          >
          <stream-event-type-filters v-model="formItem.eventTypeFilters" />
        </div>
        <div>
          <label
            class="gl-mb-3 gl-mt-5 gl-block"
            for="audit-event-namespace-filter"
            data-testid="event-namespace-filtering-header"
            >{{ s__('AuditStreams|Filter by groups or projects') }}</label
          >
          <stream-namespace-filters v-model="formItem.namespaceFilters" />
        </div>
      </div>
      <div class="gl-flex">
        <gl-button
          :disabled="isSubmitButtonDisabled"
          :loading="loading"
          :name="submitButtonName"
          class="gl-mr-3"
          variant="confirm"
          type="submit"
          data-testid="stream-destination-submit-button"
          >{{ submitButtonText }}</gl-button
        >
        <gl-button
          :name="__('Cancel editing')"
          data-testid="stream-destination-cancel-button"
          @click="$emit('cancel')"
          >{{ __('Cancel') }}</gl-button
        >
        <gl-button
          v-if="isUpdatingExistingItem"
          :name="s__('AuditStreams|Delete destination')"
          :loading="loading"
          variant="danger"
          class="gl-ml-auto"
          data-testid="stream-destination-delete-button"
          @click="deleteDestination"
          >{{ s__('AuditStreams|Delete destination') }}</gl-button
        >
      </div>
    </gl-form>
    <stream-delete-modal
      v-if="isUpdatingExistingItem"
      ref="deleteModal"
      :item="item"
      @deleting="onDeleting"
      @delete="onDelete"
      @error="onDeleteError"
    />
  </div>
</template>
