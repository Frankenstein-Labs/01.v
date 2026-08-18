<script>
import { GlAnimatedLoaderIcon, GlAvatar, GlAvatarLink } from '@gitlab/ui';
import { mapState } from 'pinia';
import SafeHtml from '~/vue_shared/directives/safe_html';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import NoteHeader from '~/notes/components/note_header.vue';
import { useNotes } from '~/notes/store/legacy_notes';

export default {
  name: 'DuoCodeReviewSystemNote',
  directives: {
    SafeHtml,
  },
  components: {
    GlAnimatedLoaderIcon,
    GlAvatar,
    GlAvatarLink,
    TimelineEntryItem,
    NoteHeader,
  },
  props: {
    note: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapState(useNotes, ['targetNoteHash']),
    noteAnchorId() {
      return `note_${this.note.id}`;
    },
    isTargetNote() {
      return this.targetNoteHash === this.noteAnchorId;
    },
    isInProgress() {
      // duo_session_status is a snapshot from when the note was created, when the
      // workflow is usually still `created` (enqueued), so both `created` and
      // `running` count as in-progress. A missing status keeps the spinner for
      // notes created before this field existed.
      const status = this.note.duo_session_status;
      return (
        status === undefined || status === null || status === 'running' || status === 'created'
      );
    },
  },
};
</script>

<template>
  <timeline-entry-item :id="noteAnchorId" :class="{ target: isTargetNote }" class="system-note">
    <div
      class="gl-relative gl-float-left gl-flex gl-items-center gl-justify-center gl-rounded-full gl-bg-white"
      :class="{
        'gl-mb-4 gl-ml-5': note.type,
      }"
    >
      <gl-avatar-link
        :href="note.author.path"
        :data-user-id="note.author.id"
        :data-username="note.author.username"
        class="js-user-link"
      >
        <gl-avatar
          :src="note.author.avatar_url"
          :entity-name="note.author.username"
          :alt="note.author.name"
          :size="32"
          data-testid="system-note-avatar"
        />
      </gl-avatar-link>
    </div>
    <div class="gl-ml-7 gl-h-7">
      <div class="gl-flex gl-h-full gl-items-center">
        <gl-animated-loader-icon
          v-if="isInProgress"
          is-on
          class="gl-ml-3 gl-self-center"
          data-testid="duo-loading-icon"
        />
        <note-header
          :author="note.author"
          :note-id="note.id"
          is-system-note
          :is-imported="note.imported"
          :show-spinner="false"
          class="duo-code-review-system-note"
        >
          <span ref="gfm-content" v-safe-html="note.note_html"></span>
        </note-header>
      </div>
    </div>
  </timeline-entry-item>
</template>
