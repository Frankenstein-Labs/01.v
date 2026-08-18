<script>
import { GlCard, GlSprintf, GlLink } from '@gitlab/ui';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { __ } from '~/locale';

export default {
  name: 'IssueNoteGraphql',
  components: {
    EventItem,
    GlCard,
    GlSprintf,
    GlLink,
  },
  props: {
    issueLinks: {
      type: Array,
      required: true,
    },
    project: {
      type: Object,
      required: false,
      default: undefined,
    },
  },
  computed: {
    createdIssue() {
      return this.issueLinks.find(({ linkType }) => linkType === 'CREATED')?.issue;
    },
    eventText() {
      return this.project
        ? __('Created issue %{issueLink} at %{projectLink}')
        : __('Created issue %{issueLink}');
    },
  },
};
</script>

<template>
  <gl-card v-if="createdIssue">
    <event-item
      :author="createdIssue.author"
      :created-at="createdIssue.createdAt"
      icon-name="issues"
    >
      <gl-sprintf :message="eventText">
        <template #issueLink>
          <gl-link :href="createdIssue.webUrl" data-testid="issue-link">
            #{{ createdIssue.iid }}
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
