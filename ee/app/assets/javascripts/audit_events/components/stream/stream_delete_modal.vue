<script>
import { GlModal, GlSprintf } from '@gitlab/ui';

import { __, s__ } from '~/locale';
import deleteGroupStreamingDestinationsQuery from '../../graphql/mutations/delete_group_streaming_destination.mutation.graphql';
import deleteInstanceStreamingDestinationsQuery from '../../graphql/mutations/delete_instance_streaming_destination.mutation.graphql';

export default {
  name: 'StreamDeleteModal',
  components: {
    GlModal,
    GlSprintf,
  },
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['delete', 'deleting', 'error'],
  computed: {
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationDestroyMutation() {
      return this.isInstance
        ? deleteInstanceStreamingDestinationsQuery
        : deleteGroupStreamingDestinationsQuery;
    },
    destinationTitle() {
      return this.item.name;
    },
  },
  methods: {
    destinationErrors(data) {
      return this.isInstance
        ? data.instanceAuditEventStreamingDestinationsDelete.errors
        : data.groupAuditEventStreamingDestinationsDelete.errors;
    },
    async deleteDestination() {
      this.reportDeleting();

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.destinationDestroyMutation,
          variables: {
            id: this.item.id,
            isInstance: this.isInstance,
          },
        });

        const errors = this.destinationErrors(data);

        if (errors.length > 0) {
          this.reportError(new Error(errors[0]));
        } else {
          this.$emit('delete');
        }
      } catch (error) {
        this.reportError(error);
      }
    },
    reportDeleting() {
      this.$emit('deleting');
    },
    reportError(error) {
      this.$emit('error', error);
    },
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the component's public API.
    show() {
      this.$refs.modal.show();
    },
  },
  i18n: {
    title: s__('AuditStreams|Are you sure about deleting this destination?'),
    message: s__(
      'AuditStreams|Deleting the streaming destination %{destination} will stop audit events being streamed',
    ),
  },
  buttonProps: {
    primary: {
      text: s__('AuditStreams|Delete destination'),
      attributes: { category: 'primary', variant: 'danger' },
    },
    cancel: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    :title="$options.i18n.title"
    modal-id="delete-destination-modal"
    :action-primary="$options.buttonProps.primary"
    :action-cancel="$options.buttonProps.cancel"
    @primary="deleteDestination"
  >
    <gl-sprintf :message="$options.i18n.message">
      <template #destination>
        <strong>{{ destinationTitle }}</strong>
      </template>
    </gl-sprintf>
  </gl-modal>
</template>
