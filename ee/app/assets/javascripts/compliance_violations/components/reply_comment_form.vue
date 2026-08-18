<script>
import { s__ } from '~/locale';
import { clearDraft } from '~/lib/utils/autosave';
import createNoteMutation from '../graphql/mutations/create_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';
import BaseCommentForm from './base_comment_form.vue';

export default {
  name: 'ReplyCommentForm',
  components: {
    BaseCommentForm,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
    discussionId: {
      type: String,
      required: true,
    },
  },
  emits: ['replied', 'cancel', 'error'],
  data() {
    return {
      isSubmitting: false,
      submitSuccess: false,
    };
  },
  computed: {
    formFieldProps() {
      return {
        'aria-label': this.$options.i18n.replyText,
        placeholder: this.$options.i18n.placeholderText,
        id: `compliance-violation-reply-${this.discussionId}`,
        name: `compliance-violation-reply-${this.discussionId}`,
      };
    },
    autosaveKey() {
      return `compliance-violation-reply-${this.discussionId}`;
    },
  },
  methods: {
    async createReply(commentText) {
      this.isSubmitting = true;
      this.submitSuccess = false;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createNoteMutation,
          variables: {
            input: {
              noteableId: this.violationId,
              body: commentText,
              discussionId: this.discussionId,
            },
          },
          update: this.updateCache,
        });

        if (data?.createNote?.errors?.length > 0) {
          this.$emit('error', this.$options.i18n.createReplyError);
          return;
        }

        // Normally the base_comment_form handles clearing the draft
        // but we need to clear the draft now before the component gets destroyed
        clearDraft(this.autosaveKey);

        this.submitSuccess = true;

        this.$emit('replied', data.createNote.note);
      } catch (error) {
        this.$emit('error', this.$options.i18n.createReplyError);
      } finally {
        this.isSubmitting = false;
      }
    },
    updateCache(cache, { data }) {
      const variables = { id: this.violationId };
      const sourceData = cache.readQuery({
        query: complianceViolationQuery,
        variables,
      });

      if (!sourceData?.projectComplianceViolation) {
        return;
      }

      const newNote = data.createNote.note;
      const existingDiscussions = sourceData.projectComplianceViolation.discussions?.nodes || [];

      const updatedDiscussions = existingDiscussions.map((discussion) => {
        if (discussion.id !== this.discussionId) {
          return discussion;
        }

        const existingNotes = discussion.notes?.nodes || [];

        return {
          ...discussion,
          notes: {
            __typename: 'NoteConnection',
            nodes: [...existingNotes, newNote],
          },
        };
      });

      const updatedData = {
        ...sourceData,
        projectComplianceViolation: {
          ...sourceData.projectComplianceViolation,
          discussions: {
            ...sourceData.projectComplianceViolation.discussions,
            nodes: updatedDiscussions,
          },
        },
      };

      cache.writeQuery({
        query: complianceViolationQuery,
        variables,
        data: updatedData,
      });
    },
  },
  i18n: {
    replyText: s__('ComplianceViolation|Reply to comment'),
    placeholderText: s__('ComplianceViolation|Write a comment or drag your files here…'),
    createReplyError: s__(
      'ComplianceViolation|Something went wrong when creating the reply. Please try again.',
    ),
  },
};
</script>

<template>
  <base-comment-form
    :autosave-key="autosaveKey"
    :form-field-props="formFieldProps"
    :submit-button-text="__('Reply')"
    :is-submitting="isSubmitting"
    :submit-success="submitSuccess"
    :clear-on-success="true"
    @submit="createReply"
    @cancel="$emit('cancel')"
  />
</template>
