<script>
import SafeHtml from '~/vue_shared/directives/safe_html';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import HistoryComment from './history_comment.vue';

export default {
  name: 'HistoryEntry',
  components: {
    EventItem,
    HistoryComment,
  },
  directives: {
    SafeHtml,
  },
  mixins: [glListenersMixin],
  props: {
    discussion: {
      type: Object,
      required: true,
    },
    /*
     * Displays the entry as a timeline feed item instead of a bordered card.
     */
    borderless: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    notes() {
      return this.discussion.notes;
    },
    systemNote() {
      return this.notes.find((x) => x.system === true);
    },
    comments() {
      return this.notes.filter((x) => x !== this.systemNote);
    },
    rootTag() {
      // Feed items are list items under the activity <ol>; the legacy card
      // layout stays a plain div.
      return this.borderless ? 'li' : 'div';
    },
    rootClass() {
      // `gl-group` lets the event item drop its top margin when this entry
      // leads the timeline feed, so the panel padding frames the first row;
      // the positioning context hosts the spine segments.
      return this.borderless
        ? 'gl-group system-note gl-relative gl-isolate gl-p-0'
        : 'card system-note gl-border-b gl-p-0';
    },
    // In the timeline feed the icon becomes a 24px neutral circle centered on
    // the spine, pinned to the row top (`gl-self-start`) so it meets the
    // spine segment ending there even when the text wraps; the legacy page
    // keeps the bare `timeline-icon` styled by its own page bundle.
    iconClass() {
      return this.borderless
        ? 'gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-self-start gl-rounded-full gl-bg-strong gl-text-subtle'
        : 'timeline-icon';
    },
    // The 24px circle at the panel content edge + the event item's built-in
    // 16px gap keeps the text at the feed's shared 40px offset.
    eventItemClass() {
      return this.borderless ? 'gl-my-5 group-first:gl-mt-0' : 'gl-m-5';
    },
    // In the timeline feed, indent replies so they read as belonging to the
    // entry above; the comment card's 16px inner padding (or the reply
    // holder's matching gl-pl-5) lands the comment content on the feed's
    // 40px text column.
    commentClass() {
      return this.borderless ? 'gl-ml-6' : null;
    },
  },
  // Remove paragraph tags so that markdown can be displayed inline.
  safeHtmlConfig: { FORBID_TAGS: ['p'] },
};
</script>

<template>
  <component :is="rootTag" v-if="systemNote" :class="rootClass">
    <div
      v-if="borderless"
      aria-hidden="true"
      class="gl-absolute -gl-top-5 gl-left-0 -gl-z-1 gl-flex gl-h-5 gl-w-6 gl-justify-center group-first:gl-hidden"
    >
      <div class="gl-w-1 gl-bg-strong"></div>
    </div>
    <div
      v-if="borderless"
      aria-hidden="true"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-top-0 -gl-z-1 gl-flex gl-w-6 gl-justify-center group-last:gl-hidden"
    >
      <div class="gl-w-1 gl-bg-strong"></div>
    </div>
    <event-item
      :id="systemNote.id"
      :author="systemNote.author"
      :created-at="systemNote.createdAt"
      :icon-name="systemNote.systemNoteIconName"
      is-system-note
      :icon-class="iconClass"
      :class="eventItemClass"
    >
      <template #header-message>
        <span v-safe-html:[$options.safeHtmlConfig]="systemNote.bodyHtml" class="md"></span>
      </template>
    </event-item>
    <history-comment
      v-for="comment in comments"
      :key="comment.id"
      :class="commentClass"
      :comment="comment"
      :borderless="borderless"
      :discussion-id="discussion.replyId"
      data-testid="existing-comment"
      v-on="glListeners()"
    />
    <history-comment
      v-if="!comments.length"
      :class="commentClass"
      :borderless="borderless"
      :discussion-id="discussion.replyId"
      data-testid="new-comment"
      v-on="glListeners()"
    />
  </component>
</template>
