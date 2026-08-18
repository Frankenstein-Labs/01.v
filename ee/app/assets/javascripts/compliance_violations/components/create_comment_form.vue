<script>
import { s__ } from '~/locale';
import createNoteMutation from '../graphql/mutations/create_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';
import BaseCommentForm from './base_comment_form.vue';

export default {
  name: 'CreateCommentForm',
  components: {
    BaseCommentForm,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
    numericViolationId: {
      type: String,
      required: true,
    },
  },
  emits: ['comment-created', 'error'],
  data() {
    return {
      isSubmitting: false,
      submitSuccess: false,
    };
  },
  computed: {
    formFieldProps() {
      return {
        'aria-label': this.$options.i18n.addCommentText,
        placeholder: this.$options.i18n.placeholderText,
        id: 'compliance-violation-add-comment',
        name: 'compliance-violation-add-comment',
      };
    },
    autosaveKey() {
      return `compliance-violation-comment-${this.numericViolationId}`;
    },
  },
  methods: {
    async createComment(commentText) {
      this.isSubmitting = true;
      this.submitSuccess = false;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createNoteMutation,
          variables: {
            input: {
              noteableId: this.violationId,
              body: commentText,
            },
          },
          update: this.updateCache,
        });

        if (data?.createNote?.errors?.length > 0) {
          this.$emit('error', this.$options.i18n.createCommentError);
          return;
        }

        this.$emit('comment-created', data.createNote.note);

        this.submitSuccess = true;
      } catch (error) {
        this.$emit('error', this.$options.i18n.createCommentError);
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

      const newDiscussion = {
        ...newNote.discussion,
        notes: {
          __typename: 'NoteConnection',
          nodes: [newNote],
        },
      };

      const updatedData = {
        ...sourceData,
        projectComplianceViolation: {
          ...sourceData.projectComplianceViolation,
          discussions: {
            ...sourceData.projectComplianceViolation.discussions,
            nodes: [...existingDiscussions, newDiscussion],
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
    addCommentText: s__('ComplianceViolation|Add a comment'),
    placeholderText: s__('ComplianceViolation|Write a comment or drag your files here…'),
    createCommentError: s__(
      'ComplianceViolation|Something went wrong when creating the comment. Please try again.',
    ),
  },
};
</script>

<template>
  <base-comment-form
    :autosave-key="autosaveKey"
    :form-field-props="formFieldProps"
    :submit-button-text="__('Comment')"
    :is-submitting="isSubmitting"
    :submit-success="submitSuccess"
    :clear-on-success="true"
    @submit="createComment"
  />
</template>
