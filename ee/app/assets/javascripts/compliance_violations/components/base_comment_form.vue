<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { getDraft, clearDraft, updateDraft } from '~/lib/utils/autosave';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { detectAndConfirmSensitiveTokens } from '~/lib/utils/secret_detection';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import { trackSavedUsingEditor } from '~/vue_shared/components/markdown/tracking';

export default {
  name: 'BaseCommentForm',
  components: {
    GlButton,
    MarkdownEditor,
  },
  inject: ['uploadsPath', 'markdownPreviewPath'],
  props: {
    initialValue: {
      type: String,
      required: false,
      default: '',
    },
    autosaveKey: {
      type: String,
      required: true,
    },
    formFieldProps: {
      type: Object,
      required: true,
    },
    submitButtonText: {
      type: String,
      required: true,
    },
    cancelButtonText: {
      type: String,
      required: false,
      default: () => __('Cancel'),
    },
    confirmCancelText: {
      type: String,
      required: false,
      default: () => __('Are you sure you want to cancel?'),
    },
    isSubmitting: {
      type: Boolean,
      required: false,
      default: false,
    },
    clearOnSuccess: {
      type: Boolean,
      required: false,
      default: false,
    },
    submitSuccess: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['cancel', 'submit'],
  data() {
    return {
      commentText: '',
    };
  },
  computed: {
    markdownDocsPath() {
      return helpPagePath('user/markdown');
    },
    canSubmit() {
      return this.commentText.trim().length > 0 && !this.isSubmitting;
    },
    hasChanges() {
      return this.commentText !== this.initialValue;
    },
  },
  watch: {
    submitSuccess(newValue) {
      if (newValue) {
        if (this.clearOnSuccess) {
          this.commentText = '';
        }
        clearDraft(this.autosaveKey);
      }
    },
  },
  created() {
    this.commentText = this.initialValue || getDraft(this.autosaveKey) || '';
  },
  methods: {
    setCommentText(newText) {
      if (!this.isSubmitting) {
        this.commentText = newText;
        updateDraft(this.autosaveKey, this.commentText);
      }
    },
    async cancelEditing() {
      if (this.hasChanges) {
        const confirmed = await confirmAction(this.confirmCancelText, {
          primaryBtnText: __('Discard changes'),
          cancelBtnText: __('Continue editing'),
          primaryBtnVariant: 'danger',
        });

        if (!confirmed) {
          return;
        }
      }

      this.commentText = this.initialValue || '';
      clearDraft(this.autosaveKey);
      this.$emit('cancel');
    },
    async submitForm() {
      if (!this.canSubmit) {
        return;
      }

      const confirmSubmit = await detectAndConfirmSensitiveTokens({ content: this.commentText });
      if (!confirmSubmit) {
        return;
      }

      this.$emit('submit', this.commentText);

      if (this.$refs.markdownEditor) {
        trackSavedUsingEditor(
          this.$refs.markdownEditor.isContentEditorActive,
          'ComplianceViolation_Comment',
        );
      }
    },
  },
};
</script>

<template>
  <form class="common-note-form gfm-form js-main-target-form new-note">
    <div class="timeline-discussion-body !gl-overflow-visible">
      <div class="note-body !gl-overflow-visible !gl-p-0">
        <markdown-editor
          ref="markdownEditor"
          :value="commentText"
          :enable-content-editor="true"
          :render-markdown-path="markdownPreviewPath"
          :uploads-path="uploadsPath"
          :markdown-docs-path="markdownDocsPath"
          :form-field-props="formFieldProps"
          :autofocus="true"
          @input="setCommentText"
          @keydown.meta.enter="submitForm"
          @keydown.ctrl.enter="submitForm"
          @keydown.esc.stop="cancelEditing"
        />
      </div>
    </div>
    <div class="note-form-actions gl-flex gl-gap-3">
      <gl-button
        category="primary"
        variant="confirm"
        data-testid="submit-button"
        :disabled="!canSubmit"
        :loading="isSubmitting"
        @click="submitForm"
      >
        {{ submitButtonText }}
      </gl-button>
      <gl-button data-testid="cancel-button" category="primary" @click="cancelEditing">
        {{ cancelButtonText }}
      </gl-button>
    </div>
  </form>
</template>
