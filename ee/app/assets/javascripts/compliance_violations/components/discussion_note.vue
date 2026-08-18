<script>
import {
  GlAvatarLink,
  GlAvatar,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlDisclosureDropdownGroup,
  GlModal,
  GlTooltipDirective,
} from '@gitlab/ui';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { getLocationHash } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import toast from '~/vue_shared/plugins/global_toast';
import SafeHtml from '~/vue_shared/directives/safe_html';
import NoteHeader from '~/notes/components/note_header.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import EditedAt from '~/issues/show/components/edited.vue';
import EmojiPicker from '~/emoji/components/picker.vue';
import AwardsList from '~/vue_shared/components/awards_list.vue';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import destroyComplianceViolationNoteMutation from '../graphql/mutations/destroy_compliance_violation_note.mutation.graphql';
import toggleComplianceViolationNoteAwardEmojiMutation from '../graphql/mutations/toggle_compliance_violation_note_award_emoji.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';
import EditCommentForm from './edit_comment_form.vue';

export default {
  name: 'DiscussionNote',
  components: {
    AwardsList,
    EditCommentForm,
    EditedAt,
    EmojiPicker,
    GlAvatar,
    GlAvatarLink,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlDisclosureDropdownGroup,
    GlModal,
    NoteHeader,
    TimelineEntryItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    note: {
      type: Object,
      required: true,
    },
    violationId: {
      type: String,
      required: true,
    },
    isFirstNote: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['error', 'start-replying'],
  data() {
    return {
      isDeleting: false,
      isEditing: false,
    };
  },
  computed: {
    targetNoteHash() {
      return getLocationHash();
    },
    noteAnchorId() {
      return `note_${this.noteId}`;
    },
    isTargetNote() {
      return this.targetNoteHash === this.noteAnchorId;
    },
    noteId() {
      return getIdFromGraphQLId(this.note.id);
    },
    author() {
      return this.note.author || {};
    },
    authorId() {
      return getIdFromGraphQLId(this.author.id);
    },
    noteUrl() {
      return `#${this.noteAnchorId}`;
    },
    fullNoteUrl() {
      const currentUrl = window.location.href.split('#')[0];
      return `${currentUrl}${this.noteUrl}`;
    },
    entryClass() {
      return {
        'note note-wrapper note-comment': true,
        target: this.isTargetNote,
      };
    },
    awards() {
      return this.note.awardEmoji?.nodes || [];
    },
    currentUserId() {
      const numericUserId = window.gon?.current_user_id;
      return numericUserId ? convertToGraphQLId(TYPENAME_USER, numericUserId) : null;
    },
  },
  methods: {
    copyNoteLink() {
      copyToClipboard(this.fullNoteUrl);
      toast(__('Link copied to clipboard.'));
      this.$refs.dropdown.close();
    },
    showDeleteNoteModal() {
      this.$refs.deleteNoteModal.show();
      this.$refs.dropdown.close();
    },
    async deleteNote() {
      if (this.isDeleting) return;

      this.isDeleting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: destroyComplianceViolationNoteMutation,
          variables: {
            input: {
              id: this.note.id,
            },
          },
          update: this.updateCacheAfterDelete,
        });

        if (data?.destroyNote?.errors?.length > 0) {
          toast(this.$options.i18n.deleteCommentError);
          return;
        }

        toast(s__('ComplianceViolation|Comment deleted successfully.'));
      } catch (error) {
        toast(this.$options.i18n.deleteCommentError);
      } finally {
        this.isDeleting = false;
      }
    },
    editNote() {
      this.isEditing = true;
    },
    cancelEdit() {
      this.isEditing = false;
    },
    handleCommentUpdated() {
      this.isEditing = false;
    },
    handleEditError(errorMessage) {
      this.$emit('error', errorMessage);
    },
    async setAwardEmoji(awardName) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: toggleComplianceViolationNoteAwardEmojiMutation,
          variables: {
            awardableId: this.note.id,
            name: awardName,
          },
          update: (cache, mutationResult) =>
            this.updateAwardEmojiCache(cache, mutationResult, awardName),
        });

        if (data?.awardEmojiToggle?.errors?.length > 0) {
          toast(s__('ComplianceViolation|Failed to toggle emoji reaction.'));
        }
      } catch (error) {
        toast(s__('ComplianceViolation|Failed to toggle emoji reaction.'));
      }
    },
    updateCacheAfterDelete(cache) {
      const variables = { id: this.violationId };
      const sourceData = cache.readQuery({
        query: complianceViolationQuery,
        variables,
      });

      if (!sourceData?.projectComplianceViolation) {
        return;
      }

      const existingDiscussions = sourceData.projectComplianceViolation.discussions?.nodes || [];

      // Filter out the deleted note from discussions
      const updatedDiscussions = existingDiscussions
        .map((discussion) => {
          if (discussion.id !== this.note.discussion.id) {
            return discussion;
          }

          const updatedNotes = discussion.notes.nodes.filter((note) => note.id !== this.note.id);

          // If this was the only note in the discussion, we'll filter out the discussion entirely
          if (updatedNotes.length === 0) {
            return null;
          }

          return {
            ...discussion,
            notes: {
              ...discussion.notes,
              nodes: updatedNotes,
              __typename: 'NoteConnection',
            },
          };
        })
        .filter(Boolean); // Remove null discussions

      const updatedData = {
        ...sourceData,
        projectComplianceViolation: {
          ...sourceData.projectComplianceViolation,
          discussions: {
            ...sourceData.projectComplianceViolation.discussions,
            nodes: updatedDiscussions,
            __typename: 'DiscussionConnection',
          },
        },
      };

      cache.writeQuery({
        query: complianceViolationQuery,
        variables,
        data: updatedData,
      });
    },
    updateAwardEmojiCache(cache, { data }, awardName) {
      if (data?.awardEmojiToggle?.errors?.length > 0) {
        return;
      }

      const variables = { id: this.violationId };
      const sourceData = cache.readQuery({
        query: complianceViolationQuery,
        variables,
      });

      if (!sourceData?.projectComplianceViolation) {
        return;
      }

      const { toggledOn, awardEmoji } = data.awardEmojiToggle;
      const existingDiscussions = sourceData.projectComplianceViolation.discussions?.nodes || [];

      const updatedDiscussions = existingDiscussions.map((discussion) => {
        const updatedNotes = discussion.notes.nodes.map((note) => {
          if (note.id !== this.note.id) {
            return note;
          }

          const currentAwardEmojis = note.awardEmoji?.nodes || [];
          let updatedAwardEmojis;

          if (toggledOn && awardEmoji) {
            const exists = currentAwardEmojis.some(
              (emoji) => emoji.name === awardEmoji.name && emoji.user.id === awardEmoji.user.id,
            );
            updatedAwardEmojis = exists ? currentAwardEmojis : [...currentAwardEmojis, awardEmoji];
          } else {
            updatedAwardEmojis = currentAwardEmojis.filter(
              (emoji) => !(emoji.name === awardName && emoji.user.id === this.currentUserId),
            );
          }

          return {
            ...note,
            awardEmoji: {
              ...note.awardEmoji,
              nodes: updatedAwardEmojis,
            },
          };
        });

        return {
          ...discussion,
          notes: {
            ...discussion.notes,
            nodes: updatedNotes,
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
    moreActionsText: __('More actions'),
    deleteCommentError: s__(
      'ComplianceViolation|Something went wrong when deleting the comment. Please try again.',
    ),
  },
  safeHtmlConfig: {
    ADD_TAGS: ['use'], // to support icon SVGs
  },
};
</script>

<template>
  <timeline-entry-item :id="noteAnchorId" :class="entryClass">
    <div class="timeline-avatar gl-float-left">
      <gl-avatar-link
        :href="author.webUrl"
        :data-user-id="authorId"
        :data-username="author.username"
        class="js-user-link"
      >
        <gl-avatar
          :src="author.avatarUrl"
          :entity-name="author.username"
          :alt="author.name"
          :size="32"
        />
      </gl-avatar-link>
    </div>
    <div class="timeline-content">
      <div data-testid="note-wrapper">
        <div class="note-header">
          <note-header
            :author="author"
            :created-at="note.createdAt"
            :note-id="noteId"
            :note-url="noteUrl"
          />
          <div v-if="!isEditing" class="note-actions">
            <emoji-picker
              toggle-class="add-reaction-button btn-default-tertiary"
              data-testid="note-emoji-button"
              @click="setAwardEmoji"
            />
            <gl-button
              v-if="isFirstNote"
              v-gl-tooltip
              icon="reply"
              category="tertiary"
              :title="__('Reply to comment')"
              :aria-label="__('Reply to comment')"
              data-testid="reply-note-button"
              @click="$emit('start-replying')"
            />
            <gl-button
              v-gl-tooltip
              icon="pencil"
              category="tertiary"
              :title="__('Edit comment')"
              :aria-label="__('Edit comment')"
              data-testid="edit-note-button"
              @click="editNote"
            />
            <gl-disclosure-dropdown
              ref="dropdown"
              v-gl-tooltip
              icon="ellipsis_v"
              text-sr-only
              placement="bottom-end"
              :toggle-text="$options.i18n.moreActionsText"
              :title="$options.i18n.moreActionsText"
              category="tertiary"
              no-caret
              data-testid="note-actions-dropdown"
            >
              <gl-disclosure-dropdown-item data-testid="copy-link-action" @action="copyNoteLink">
                <template #list-item>
                  {{ __('Copy link') }}
                </template>
              </gl-disclosure-dropdown-item>
              <gl-disclosure-dropdown-group bordered>
                <gl-disclosure-dropdown-item
                  data-testid="delete-note-action"
                  variant="danger"
                  :disabled="isDeleting"
                  @action="showDeleteNoteModal"
                >
                  <template #list-item>
                    {{ __('Delete comment') }}
                  </template>
                </gl-disclosure-dropdown-item>
              </gl-disclosure-dropdown-group>
            </gl-disclosure-dropdown>
          </div>
        </div>
        <div class="note-body" data-testid="discussion-note-body">
          <div v-if="isEditing" class="timeline-discussion-body">
            <edit-comment-form
              :violation-id="violationId"
              :note-id="note.id"
              :numeric-note-id="noteId"
              :initial-value="note.body"
              @comment-updated="handleCommentUpdated"
              @cancel="cancelEdit"
              @error="handleEditError"
            />
          </div>
          <div v-else class="timeline-discussion-body">
            <div
              v-safe-html:[$options.safeHtmlConfig]="note.bodyHtml"
              class="note-text md"
              data-testid="discussion-note-text"
            ></div>
          </div>
          <edited-at
            v-if="note.lastEditedBy && !isEditing"
            :updated-at="note.lastEditedAt"
            :updated-by-name="note.lastEditedBy.name"
            :updated-by-path="note.lastEditedBy.webPath"
            class="gl-mt-5"
          />
          <awards-list
            v-if="awards.length && !isEditing"
            :awards="awards"
            can-award-emoji
            :current-user-id="currentUserId"
            class="gl-mt-3"
            data-testid="note-awards-list"
            @award="setAwardEmoji($event)"
          />
        </div>
      </div>
    </div>
    <gl-modal
      ref="deleteNoteModal"
      modal-id="delete-note-modal"
      :title="__('Delete comment?')"
      :ok-title="__('Delete comment')"
      ok-variant="danger"
      size="sm"
      @primary="deleteNote"
    >
      {{ __('Are you sure you want to delete this comment?') }}
    </gl-modal>
  </timeline-entry-item>
</template>
