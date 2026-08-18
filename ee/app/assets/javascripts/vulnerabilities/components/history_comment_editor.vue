<script>
import { GlFormTextarea, GlButton } from '@gitlab/ui';
import { sanitize } from '~/lib/dompurify';

export default {
  name: 'HistoryCommentEditor',
  components: { GlFormTextarea, GlButton },
  props: {
    initialComment: {
      type: String,
      required: false,
      default: '',
    },
    isSaving: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['cancel', 'save'],
  data() {
    return {
      comment: this.initialComment.trim(),
    };
  },
  computed: {
    isSaveButtonDisabled() {
      return this.isSaving || !this.sanitizedComment.length;
    },
    sanitizedComment() {
      return sanitize(this.comment.trim());
    },
  },
};
</script>

<template>
  <div>
    <gl-form-textarea
      v-model="comment"
      :placeholder="s__('vulnerability|Add a comment')"
      :disabled="isSaving"
      no-resize
      autofocus
    />
    <div class="gl-mt-5 gl-flex gl-gap-3">
      <gl-button
        ref="saveButton"
        variant="confirm"
        :disabled="isSaveButtonDisabled"
        :loading="isSaving"
        @click="$emit('save', sanitizedComment)"
      >
        {{ __('Save comment') }}
      </gl-button>
      <gl-button ref="cancelButton" :disabled="isSaving" @click="$emit('cancel')">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </div>
</template>
