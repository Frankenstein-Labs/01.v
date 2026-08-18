<script>
import { GlFormInput } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import DiscussionNotesRepliesWrapper from '~/notes/components/discussion_notes_replies_wrapper.vue';
import ToggleRepliesWidget from '~/notes/components/toggle_replies_widget.vue';
import DiscussionNote from './discussion_note.vue';
import ReplyCommentForm from './reply_comment_form.vue';

export default {
  name: 'ComplianceViolationDiscussion',
  components: {
    GlFormInput,
    TimelineEntryItem,
    DiscussionNote,
    ToggleRepliesWidget,
    DiscussionNotesRepliesWrapper,
    ReplyCommentForm,
  },
  props: {
    discussion: {
      type: Object,
      required: true,
    },
    violationId: {
      type: String,
      required: true,
    },
  },
  emits: ['error'],
  data() {
    return {
      isExpanded: true,
      isReplying: false,
      replyFormKey: this.generateUniqueId(),
    };
  },
  computed: {
    notes() {
      return this.discussion.notes.nodes;
    },
    firstNote() {
      return this.notes[0];
    },
    firstNoteId() {
      return getIdFromGraphQLId(this.firstNote.id);
    },
    hasReplies() {
      return Boolean(this.replies?.length);
    },
    replies() {
      if (this.notes?.length > 1) {
        return this.notes.slice(1);
      }
      return null;
    },
    discussionId() {
      return this.discussion.id || '';
    },
  },
  methods: {
    generateUniqueId() {
      // used to rerender reply-comment-form so the text in the textarea is cleared
      return uniqueId(`compliance-violation-reply-${this.discussionId}-`);
    },
    toggleDiscussion() {
      this.isExpanded = !this.isExpanded;
    },
    threadKey(note) {
      return `${note.id}-thread`; // eslint-disable-line @gitlab/require-i18n-strings
    },
    handleError(errorMessage) {
      this.$emit('error', errorMessage);
    },
    showReplyForm() {
      this.isReplying = true;
      this.isExpanded = true;
    },
    hideReplyForm() {
      this.isReplying = false;
      this.replyFormKey = this.generateUniqueId();
    },
    handleReplied() {
      this.isReplying = false;
      this.replyFormKey = this.generateUniqueId();
    },
  },
};
</script>

<template>
  <timeline-entry-item
    :data-note-id="firstNoteId"
    :data-discussion-id="discussionId"
    class="note-discussion gl-px-0"
  >
    <div class="timeline-content">
      <div class="discussion">
        <div class="discussion-body">
          <div class="discussion-wrapper">
            <div class="discussion-notes">
              <ul class="notes" data-testid="note-container">
                <discussion-note
                  :note="firstNote"
                  :violation-id="violationId"
                  :is-first-note="true"
                  @error="handleError"
                  @start-replying="showReplyForm"
                />
                <discussion-notes-replies-wrapper>
                  <toggle-replies-widget
                    v-if="hasReplies"
                    :collapsed="!isExpanded"
                    :replies="replies"
                    @toggle="toggleDiscussion"
                  />
                  <template v-if="isExpanded">
                    <discussion-note
                      v-for="reply in replies"
                      :key="threadKey(reply)"
                      :note="reply"
                      :violation-id="violationId"
                      @error="handleError"
                      @start-replying="showReplyForm"
                    />
                    <li
                      class="note note-wrapper note-comment discussion-reply-holder gl-clearfix"
                      :class="{ 'is-replying': isReplying }"
                    >
                      <div class="timeline-content">
                        <reply-comment-form
                          v-if="isReplying"
                          :key="replyFormKey"
                          :violation-id="violationId"
                          :discussion-id="discussionId"
                          @replied="handleReplied"
                          @cancel="hideReplyForm"
                          @error="handleError"
                        />
                        <gl-form-input
                          v-else
                          class="reply-placeholder-input-field js-discussion-reply-field-placeholder"
                          data-testid="discussion-reply-tab"
                          :placeholder="__('Reply…')"
                          :aria-label="__('Reply to comment')"
                          @focus="showReplyForm"
                        />
                      </div>
                    </li>
                  </template>
                </discussion-notes-replies-wrapper>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </timeline-entry-item>
</template>
