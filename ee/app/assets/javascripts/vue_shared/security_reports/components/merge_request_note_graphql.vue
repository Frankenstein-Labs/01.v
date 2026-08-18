<script>
import { GlCard, GlSprintf, GlLink } from '@gitlab/ui';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { __ } from '~/locale';

export default {
  name: 'MergeRequestNoteGraphql',
  components: {
    EventItem,
    GlCard,
    GlSprintf,
    GlLink,
  },
  props: {
    mergeRequest: {
      type: Object,
      required: false,
      default: undefined,
    },
    project: {
      type: Object,
      required: false,
      default: undefined,
    },
  },
  computed: {
    eventText() {
      return this.project
        ? __('Created merge request %{mergeRequestLink} at %{projectLink}')
        : __('Created merge request %{mergeRequestLink}');
    },
  },
};
</script>

<template>
  <gl-card v-if="mergeRequest">
    <event-item
      :author="mergeRequest.author"
      :created-at="mergeRequest.createdAt"
      icon-name="merge-request"
    >
      <gl-sprintf :message="eventText">
        <template #mergeRequestLink>
          <gl-link :href="mergeRequest.webUrl" data-testid="merge-request-link">
            #{{ mergeRequest.iid }}
          </gl-link>
        </template>
        <template v-if="project" #projectLink>
          <gl-link :href="project.webUrl" data-testid="project-link">
            {{ project.nameWithNamespace }}
          </gl-link>
        </template>
      </gl-sprintf>
    </event-item>
  </gl-card>
</template>
