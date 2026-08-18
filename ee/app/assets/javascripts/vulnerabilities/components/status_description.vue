<script>
import {
  GlLink,
  GlSprintf,
  GlSkeletonLoader,
  GlLoadingIcon,
  GlAvatarLink,
  GlAvatarLabeled,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { DISMISSAL_REASONS } from '../constants';

export default {
  name: 'StatusDescription',
  components: {
    GlLink,
    GlSprintf,
    TimeAgoTooltip,
    GlSkeletonLoader,
    GlLoadingIcon,
    GlAvatarLink,
    GlAvatarLabeled,
  },
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
    user: {
      type: Object,
      required: false,
      default: undefined,
    },
    isLoadingVulnerability: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoadingUser: {
      type: Boolean,
      required: false,
      default: false,
    },
    isStatusBolded: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  computed: {
    state() {
      return this.vulnerability.state;
    },

    representationInformation() {
      return this.vulnerability.representationInformation;
    },

    representationInformationAvailable() {
      const { resolvedOnDefaultBranch } = this.vulnerability;
      return resolvedOnDefaultBranch && this.representationInformation?.resolvedInCommitShaLink;
    },

    time() {
      if (this.representationInformationAvailable) {
        return this.representationInformation.createdAt;
      }

      return this.state === 'detected' && !this.isVulnerabilityScanner
        ? this.vulnerability.pipeline?.createdAt
        : this.vulnerability[`${this.state}At`];
    },

    statusText() {
      if (this.representationInformationAvailable) {
        return s__(
          'VulnerabilityManagement|No longer detected %{timeago} as of commit %{commitShaLink}',
        );
      }

      switch (this.state) {
        case 'detected':
          if (this.isVulnerabilityScanner) {
            return s__('VulnerabilityManagement|%{statusStart}Detected%{statusEnd} · %{timeago}');
          }
          return s__(
            'VulnerabilityManagement|%{statusStart}Detected%{statusEnd} · %{timeago} in pipeline %{pipelineLink}',
          );
        case 'confirmed':
          return s__(
            'VulnerabilityManagement|%{statusStart}Confirmed%{statusEnd} · %{timeago} by %{user}',
          );
        case 'dismissed':
          if (this.hasDismissalReason) {
            return s__(
              'VulnerabilityManagement|%{statusStart}Dismissed%{statusEnd}: %{dismissalReason} · %{timeago} by %{user}',
            );
          }
          return s__(
            'VulnerabilityManagement|%{statusStart}Dismissed%{statusEnd} · %{timeago} by %{user}',
          );
        case 'resolved':
          return s__(
            'VulnerabilityManagement|%{statusStart}Resolved%{statusEnd} · %{timeago} by %{user}',
          );
        default:
          return '%timeago';
      }
    },

    dismissalReason() {
      return this.vulnerability.stateTransitions?.at(-1)?.dismissalReason;
    },

    hasDismissalReason() {
      return this.state === 'dismissed' && Boolean(this.dismissalReason);
    },

    dismissalReasonText() {
      return DISMISSAL_REASONS[this.dismissalReason];
    },
    isVulnerabilityScanner() {
      return this.vulnerability.scanner?.isVulnerabilityScanner;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-items-center gl-whitespace-pre-wrap">
    <gl-skeleton-loader v-if="isLoadingVulnerability" :lines="1" />
    <!-- there are cases in which `time` is undefined (e.g.: manually submitted vulnerabilities in "needs triage" state) -->
    <gl-sprintf v-else-if="time" :message="statusText">
      <template #status="{ content }">
        <span :class="{ 'gl-font-bold': isStatusBolded }" data-testid="status">{{ content }}</span>
      </template>
      <template #dismissalReason>
        <span :class="{ 'gl-font-bold': isStatusBolded }" data-testid="dismissal-reason">{{
          dismissalReasonText
        }}</span>
      </template>
      <template #timeago>
        <time-ago-tooltip ref="timeAgo" :time="time" />
      </template>
      <template #user>
        <gl-loading-icon v-if="isLoadingUser" class="gl-ml-2 gl-inline" size="sm" />
        <gl-avatar-link
          v-else-if="user"
          :href="user.web_url"
          :data-user-id="user.id"
          :data-username="user.username"
          class="js-user-link gl-ml-2 gl-font-bold"
        >
          <gl-avatar-labeled :src="user.avatar_url" :label="user.name" :size="24" />
        </gl-avatar-link>
      </template>
      <template v-if="vulnerability.pipeline" #pipelineLink>
        <gl-link :href="vulnerability.pipeline.url" target="_blank" class="link">{{
          vulnerability.pipeline.id
        }}</gl-link>
      </template>
      <template #commitShaLink>
        <gl-link
          :href="representationInformation.resolvedInCommitShaLink"
          target="_blank"
          class="link gl-str-truncated gl-whitespace-nowrap"
        >
          {{ representationInformation.resolvedInCommitSha }}
        </gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>
