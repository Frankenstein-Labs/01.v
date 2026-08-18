<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { s__ } from '~/locale';
import { DISMISSAL_REASONS } from 'ee/vulnerabilities/constants';
import { getDismissalNoteEventText } from './helpers';

export default {
  name: 'DismissalNote',
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
    project: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isEditingDismissal: {
      type: Boolean,
      required: false,
      default: false,
    },
    showDismissalActions: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['edit-dismissal'],
  computed: {
    pipeline() {
      return this.feedback?.pipeline;
    },
    dismissalReason() {
      return DISMISSAL_REASONS[this.feedback.dismissalReason?.toLowerCase()];
    },
    eventText() {
      const { project, pipeline } = this;

      const hasPipeline = Boolean(pipeline?.path && pipeline?.id);
      const hasProject = Boolean(project?.url && project?.value);
      const hasDismissalReason = Boolean(this.dismissalReason);

      return getDismissalNoteEventText({ hasProject, hasPipeline, hasDismissalReason });
    },
    commentDetails() {
      return this.feedback.comment_details;
    },
    actionButtons() {
      return [
        {
          iconName: 'pencil',
          onClick: () => this.$emit('edit-dismissal'),
          title: s__('SecurityReports|Edit dismissal'),
        },
      ];
    },
    showFeedbackActions() {
      return this.showDismissalActions && !this.commentDetails;
    },
  },
};
</script>

<template>
  <div>
    <event-item
      :action-buttons="actionButtons"
      :author="feedback.author"
      :created-at="feedback.created_at"
      :show-action-buttons="showFeedbackActions"
      icon-name="cancel"
      icon-class="ci-status-icon-pending"
    >
      <div v-if="feedback.created_at">
        <gl-sprintf :message="eventText">
          <template v-if="pipeline" #pipelineLink>
            <gl-link :href="pipeline.path" data-testid="pipeline-link">#{{ pipeline.id }}</gl-link>
          </template>
          <template v-if="project" #projectLink>
            <gl-link :href="project.url" data-testid="project-link">{{ project.value }}</gl-link>
          </template>
          <template #status="{ content }">{{ content }}</template>
          <template v-if="dismissalReason" #dismissalReason>
            {{ dismissalReason }}
          </template>
        </gl-sprintf>
      </div>
    </event-item>
    <template v-if="commentDetails && !isEditingDismissal">
      <hr class="gl-my-5" />
      <event-item
        :action-buttons="actionButtons"
        :author="commentDetails.comment_author"
        :created-at="commentDetails.comment_timestamp"
        :show-action-buttons="showDismissalActions"
        icon-name="comment"
        icon-class="ci-status-icon-pending"
      >
        {{ commentDetails.comment }}
      </event-item>
    </template>
  </div>
</template>
