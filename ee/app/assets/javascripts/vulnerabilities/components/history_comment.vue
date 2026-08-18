<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import createNoteMutation from 'ee/security_dashboard/graphql/mutations/note_create.mutation.graphql';
import destroyNoteMutation from 'ee/security_dashboard/graphql/mutations/note_destroy.mutation.graphql';
import updateNoteMutation from 'ee/security_dashboard/graphql/mutations/note_update.mutation.graphql';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { createAlert } from '~/alert';
import {
  TYPENAME_NOTE,
  TYPENAME_DISCUSSION,
  TYPENAME_VULNERABILITY,
} from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import HistoryCommentEditor from './history_comment_editor.vue';

export default {
  name: 'HistoryComment',
  components: {
    GlButton,
    GlLoadingIcon,
    EventItem,
    HistoryCommentEditor,
  },

  directives: {
    SafeHtml,
  },

  inject: ['vulnerabilityId'],

  props: {
    comment: {
      type: Object,
      required: false,
      default: undefined,
    },
    /*
     * Trims the reply holder's trailing padding so the timeline feed's row
     * rhythm comes from the entry margins alone; the legacy page keeps the
     * padded card layout.
     */
    borderless: {
      type: Boolean,
      required: false,
      default: false,
    },
    discussionId: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  emits: ['comment-updated'],

  data() {
    return {
      isEditingComment: false,
      isSavingComment: false,
      isDeletingComment: false,
      isConfirmingDeletion: false,
    };
  },

  computed: {
    actionButtons() {
      return [
        {
          iconName: 'pencil',
          onClick: this.showCommentInput,
          title: __('Edit Comment'),
        },
        {
          iconName: 'remove',
          onClick: this.showDeleteConfirmation,
          title: __('Delete Comment'),
        },
      ];
    },
    initialComment() {
      return this.comment?.body;
    },
    canEditComment() {
      return this.comment.userPermissions?.adminNote;
    },
    noteHtml() {
      return this.isSavingComment ? undefined : this.comment.bodyHtml;
    },
  },

  methods: {
    showCommentInput() {
      this.isEditingComment = true;
    },
    async insertComment(body) {
      const { data } = await this.$apollo.mutate({
        mutation: createNoteMutation,
        variables: {
          noteableId: convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerabilityId),
          discussionId: convertToGraphQLId(TYPENAME_DISCUSSION, this.discussionId),
          body,
        },
      });

      const { errors } = data.createNote;

      if (errors?.length > 0) {
        throw errors;
      }
    },
    async updateComment(body) {
      const { data } = await this.$apollo.mutate({
        mutation: updateNoteMutation,
        variables: {
          id: convertToGraphQLId(TYPENAME_NOTE, this.comment.id),
          body,
        },
      });

      const { errors } = data.updateNote;

      if (errors?.length > 0) {
        throw errors;
      }
    },
    async saveComment(body) {
      this.isSavingComment = true;
      const isUpdatingComment = Boolean(this.comment);

      try {
        if (isUpdatingComment) {
          await this.updateComment(body);
        } else {
          await this.insertComment(body);
        }

        this.$emit('comment-updated');
        this.isSavingComment = false;
        this.cancelEditingComment();
      } catch {
        this.isSavingComment = false;

        createAlert({
          message: s__(
            'VulnerabilityManagement|Something went wrong while trying to save the comment. Please try again later.',
          ),
        });
      }
    },
    async deleteComment() {
      this.isDeletingComment = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: destroyNoteMutation,
          variables: {
            id: convertToGraphQLId(TYPENAME_NOTE, this.comment.id),
          },
        });

        if (data.errors?.length > 0) {
          throw data.errors;
        }

        this.$emit('comment-updated');
        this.isDeletingComment = false;
      } catch {
        this.isDeletingComment = false;

        createAlert({
          message: s__(
            'VulnerabilityManagement|Something went wrong while trying to delete the comment. Please try again later.',
          ),
        });
      }
    },
    cancelEditingComment() {
      this.isEditingComment = false;
    },
    showDeleteConfirmation() {
      this.isConfirmingDeletion = true;
    },
    cancelDeleteConfirmation() {
      this.isConfirmingDeletion = false;
    },
  },
};
</script>

<template>
  <history-comment-editor
    v-if="isEditingComment"
    class="discussion-reply-holder"
    :class="borderless ? 'gl-pl-5' : 'gl-px-5 gl-pb-4'"
    :initial-comment="initialComment"
    :is-saving="isSavingComment"
    @save="saveComment"
    @cancel="cancelEditingComment"
  />

  <event-item
    v-else-if="comment"
    :id="comment.id"
    :author="comment.author"
    :created-at="comment.updatedAt"
    :show-action-buttons="canEditComment"
    :show-right-slot="isConfirmingDeletion"
    :action-buttons="actionButtons"
    icon-name="comment"
    icon-class="timeline-icon"
    class="gl-border-t gl-border-subtle gl-p-5"
  >
    <div v-safe-html="noteHtml" class="md">
      <gl-loading-icon size="sm" />
    </div>

    <template #right-content>
      <gl-button
        variant="danger"
        :loading="isDeletingComment"
        data-testid="confirm-delete-button"
        @click="deleteComment"
      >
        {{ __('Delete') }}
      </gl-button>
      <gl-button
        class="gl-ml-3"
        :disabled="isDeletingComment"
        data-testid="cancel-delete-button"
        @click="cancelDeleteConfirmation"
      >
        {{ __('Cancel') }}
      </gl-button>
    </template>
  </event-item>

  <div v-else class="discussion-reply-holder" :class="borderless ? 'gl-pl-5' : 'gl-px-5 gl-pb-4'">
    <!-- gl-block removes the inline textarea's baseline gap below the field. -->
    <textarea
      rows="1"
      :placeholder="s__('vulnerability|Add a comment')"
      class="reply-placeholder-text-field"
      :class="{ 'gl-block': borderless }"
      data-testid="add-comment-textarea"
      @focus="showCommentInput"
    ></textarea>
  </div>
</template>
