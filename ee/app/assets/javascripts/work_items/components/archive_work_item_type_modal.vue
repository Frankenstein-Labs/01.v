<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import workItemTypeUpdateMutation from 'ee/work_items/graphql/update_work_item_type.mutation.graphql';

export default {
  name: 'ArchiveWorkItemTypeModal',
  components: {
    GlModal,
    GlSprintf,
  },
  props: {
    workItemType: {
      type: Object,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['close', 'error', 'success'],
  data() {
    return {
      isArchiving: false,
    };
  },
  computed: {
    isVisible() {
      return Boolean(this.workItemType);
    },
    modalTitle() {
      return sprintf(s__('WorkItem|Archive type: %{typeName}'), {
        typeName: this.workItemType?.name || '',
      });
    },
    primaryAction() {
      return {
        text: s__('WorkItem|Archive'),
        attributes: {
          variant: 'confirm',
          loading: this.isArchiving,
        },
      };
    },
    cancelAction() {
      return {
        text: s__('WorkItem|Cancel'),
        attributes: { disabled: this.isArchiving },
      };
    },
  },
  methods: {
    async handleConfirm() {
      if (!this.workItemType) return;

      this.isArchiving = true;

      const input = {
        id: this.workItemType.id,
        archive: true,
      };

      if (this.fullPath) {
        input.fullPath = this.fullPath;
      }

      try {
        const { data } = await this.$apollo.mutate({
          mutation: workItemTypeUpdateMutation,
          variables: { input },
        });

        const { errors } = data?.workItemTypeUpdate || {};

        if (errors?.length) {
          throw new Error(errors.join(', '));
        }

        this.$emit('success', { archived: true, workItemType: this.workItemType });
      } catch (error) {
        this.$emit('error', {
          message: error.message || s__('WorkItem|Failed to update work item type.'),
        });
        Sentry.captureException(error);
      } finally {
        this.isArchiving = false;
        this.$emit('close');
      }
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="archive-work-item-type-modal"
    :visible="isVisible"
    :title="modalTitle"
    :action-primary="primaryAction"
    :action-cancel="cancelAction"
    size="md"
    @primary.prevent="handleConfirm"
    @hidden="$emit('close')"
  >
    <gl-sprintf
      :message="
        s__(
          'WorkItem|Archiving a work item type will make it unusable in all groups and projects. Items already using this type will keep this type and may be changed to other types.',
        )
      "
    />
  </gl-modal>
</template>
