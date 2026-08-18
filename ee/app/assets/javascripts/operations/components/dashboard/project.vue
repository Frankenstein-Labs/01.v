<script>
import { isEmpty } from 'lodash-es';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { GlSprintf, GlLink, GlCard } from '@gitlab/ui';
import Alerts from 'ee/vue_shared/dashboards/components/alerts.vue';
import ProjectPipeline from 'ee/vue_shared/dashboards/components/project_pipeline.vue';
import TimeAgo from 'ee/vue_shared/dashboards/components/time_ago.vue';
import { STATUS_FAILED, STATUS_RUNNING } from 'ee/vue_shared/dashboards/constants';
import { __ } from '~/locale';
import Commit from '~/vue_shared/components/commit.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import ProjectHeader from './project_header.vue';

export default {
  name: 'DashboardProject',
  components: {
    ProjectHeader,
    UserAvatarLink,
    Commit,
    Alerts,
    ProjectPipeline,
    TimeAgo,
    GlSprintf,
    GlLink,
    GlCard,
  },
  mixins: [timeagoMixin],
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  tooltips: {
    timeAgo: __('Finished'),
    triggerer: __('Triggerer'),
  },
  unlicensedMessages: {
    canUpgrade: __(
      "To see this project's operational details, %{linkStart}upgrade its group plan to Premium%{linkEnd}. You can also remove the project from the dashboard.",
    ),
    cannotUpgrade: __(
      "To see this project's operational details, contact an owner of group %{groupName} to upgrade the plan. You can also remove the project from the dashboard.",
    ),
  },
  computed: {
    hasPipelineFailed() {
      return (
        this.lastPipeline &&
        this.lastPipeline.details &&
        this.lastPipeline.details.status &&
        this.lastPipeline.details.status.group === STATUS_FAILED
      );
    },
    hasPipelineErrors() {
      return this.project.alert_count > 0;
    },
    cardClasses() {
      return {
        'gl-border-feedback-warning': !this.hasPipelineFailed && this.hasPipelineErrors,
        'gl-border-feedback-danger': this.hasPipelineFailed,
      };
    },
    headerClasses() {
      return {
        'gl-bg-feedback-warning gl-border-feedback-warning': this.hasPipelineErrors,
        'gl-bg-feedback-danger gl-border-feedback-danger': this.hasPipelineFailed,
      };
    },
    noPipelineMessage() {
      return __('The branch for this project has no active pipeline configuration.');
    },
    user() {
      return this.lastPipeline && !isEmpty(this.lastPipeline.user) ? this.lastPipeline.user : null;
    },
    lastPipeline() {
      return !isEmpty(this.project.last_pipeline) ? this.project.last_pipeline : null;
    },
    commitRef() {
      return this.lastPipeline && !isEmpty(this.lastPipeline.ref)
        ? {
            ...this.lastPipeline.ref,
            ref_url: this.lastPipeline.ref.path,
          }
        : {};
    },
    finishedTime() {
      return (
        this.lastPipeline && this.lastPipeline.details && this.lastPipeline.details.finished_at
      );
    },
    shouldShowTimeAgo() {
      return (
        this.lastPipeline &&
        this.lastPipeline.details &&
        this.lastPipeline.details.status &&
        this.lastPipeline.details.status.group !== STATUS_RUNNING &&
        this.finishedTime
      );
    },
  },
  methods: {
    ...mapActions(['removeProject']),
  },
};
</script>
<template>
  <gl-card
    :class="[cardClasses, 'js-dashboard-project']"
    :header-class="headerClasses"
    data-testid="dashboard-project-card"
  >
    <template #header>
      <project-header
        :project="project"
        :has-pipeline-failed="hasPipelineFailed"
        :has-errors="hasPipelineErrors"
        @remove="removeProject"
      />
    </template>

    <template v-if="project.upgrade_required">
      <gl-sprintf
        v-if="project.upgrade_path"
        :message="$options.unlicensedMessages.canUpgrade"
        data-testid="dashboard-card-body"
      >
        <template #link="{ content }">
          <gl-link :href="project.upgrade_path" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>

      <gl-sprintf
        v-else
        :message="$options.unlicensedMessages.cannotUpgrade"
        data-testid="dashboard-card-body"
      >
        <template #groupName>{{ project.namespace.name }}</template>
      </gl-sprintf>
    </template>

    <template v-else>
      <template v-if="lastPipeline">
        <div class="gl-flex gl-items-center gl-gap-4">
          <user-avatar-link
            v-if="user"
            :link-href="user.path"
            :img-src="user.avatar_url"
            :tooltip-text="user.name"
            :img-size="32"
            class="-gl-ml-1"
          />
          <commit
            :tag="commitRef.tag"
            :commit-ref="commitRef"
            :short-sha="lastPipeline.commit.short_id"
            :commit-url="lastPipeline.commit.commit_url"
            :title="lastPipeline.commit.title"
            :author="lastPipeline.commit.author"
            :show-branch="true"
          />
        </div>

        <div class="gl-mt-2 gl-flex gl-flex-wrap gl-gap-5">
          <time-ago
            v-if="shouldShowTimeAgo"
            :time="finishedTime"
            :tooltip-text="$options.tooltips.timeAgo"
          />
          <alerts :count="project.alert_count" />
        </div>
        <project-pipeline :last-pipeline="lastPipeline" />
      </template>

      <div v-else class="gl-text-center gl-text-default">
        {{ noPipelineMessage }}
      </div>
    </template>
  </gl-card>
</template>
