<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { __ } from '~/locale';

export default {
  name: 'MergeRequestNote',
  components: {
    EventItem,
    GlSprintf,
    GlLink,
  },
  props: {
    feedback: {
      type: Object,
      required: true,
    },
    /*
     * Aligns the icon circle and row geometry with the vulnerability details
     * activity feed's timeline spine.
     * Note: once the redesigned details page has been rolled out fully, this
     * prop and related logic can be removed.
     * See https://gitlab.com/groups/gitlab-org/-/work_items/21907 for progress.
     */
    feedAligned: {
      type: Boolean,
      required: false,
      default: false,
    },
    project: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    iconClass() {
      // `undefined` lets the event item fall back to its default icon class.
      // `gl-self-start` pins the circle to the row top so it meets the
      // timeline spine segment ending there even when the text wraps.
      return this.feedAligned
        ? 'gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-self-start gl-rounded-full gl-bg-strong gl-text-subtle'
        : undefined;
    },
    messageSlot() {
      return this.feedAligned ? 'header-message' : 'default';
    },
    hasProjectUrl() {
      return Boolean(this.project?.value && this.project?.url);
    },
    eventText() {
      if (this.feedAligned) {
        return this.hasProjectUrl
          ? __('created merge request %{mergeRequestLink} at %{projectLink}')
          : __('created merge request %{mergeRequestLink}');
      }

      return this.hasProjectUrl
        ? __('Created merge request %{mergeRequestLink} at %{projectLink}')
        : __('Created merge request %{mergeRequestLink}');
    },
    createdAt() {
      return this.feedback.created_at || this.feedback.createdAt;
    },
    mergeRequestPath() {
      return this.feedback.merge_request_path || this.feedback.mergeRequestPath;
    },
    mergeRequestIid() {
      return this.feedback.merge_request_iid || this.feedback.mergeRequestIid;
    },
  },
};
</script>

<template>
  <event-item
    :author="feedback.author"
    :created-at="createdAt"
    icon-name="merge-request"
    :icon-class="iconClass"
    :is-system-note="feedAligned"
  >
    <template #[messageSlot]>
      <gl-sprintf :message="eventText">
        <template #mergeRequestLink>
          <gl-link data-testid="mergeRequestLink" :href="mergeRequestPath">
            !{{ mergeRequestIid }}
          </gl-link>
        </template>
        <template v-if="hasProjectUrl" #projectLink>
          <gl-link data-testid="projectLink" :href="project.url">{{ project.value }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
  </event-item>
</template>
