<script>
import { GlBadge, GlSprintf } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { n__ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { statusDescriptionMap, statusTextMap, statusVariantMap } from '../constants';

export default {
  name: 'ApplicationCard',
  components: {
    GlBadge,
    GlSprintf,
    ProjectAvatar,
    TimeAgo,
  },
  props: {
    application: {
      type: Object,
      required: true,
    },
  },
  computed: {
    badgeDescription() {
      return statusDescriptionMap[this.application.status];
    },
    badgeText() {
      return statusTextMap[this.application.status];
    },
    badgeVariant() {
      return statusVariantMap[this.application.status];
    },
    servicesText() {
      return n__(
        'ContinuousDeployment|%d service',
        'ContinuousDeployment|%d services',
        this.application.services.count,
      );
    },
    applicationRoute() {
      return {
        name: 'applications_show_route',
        params: { id: String(getIdFromGraphQLId(this.application.id)) },
      };
    },
  },
};
</script>

<template>
  <div
    class="gl-min-h-26 gl-rounded-lg gl-border-1 gl-border-solid gl-border-subtle"
    data-testid="application-card"
  >
    <div class="gl-border-b gl-flex gl-items-center gl-gap-3 gl-border-subtle gl-p-4">
      <project-avatar :project-name="application.name" :size="24" />
      <h2 class="gl-m-0 gl-truncate gl-text-base" :title="application.name">
        <router-link
          :to="applicationRoute"
          class="gl-text-default hover:gl-no-underline"
          data-testid="application-card-link"
          >{{ application.name }}</router-link
        >
      </h2>
      <gl-badge
        v-if="application.status"
        class="gl-ml-auto"
        icon="status_created_borderless"
        :variant="badgeVariant"
      >
        {{ badgeText }}
      </gl-badge>
    </div>
    <div class="gl-p-4">
      <div class="gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-purple-400">
        {{ badgeDescription }}
      </div>

      <div class="gl-text-sm gl-text-secondary">
        {{ servicesText }}
        <template v-if="application.lastDeployedAt">
          &middot;
          <gl-sprintf :message="s__('ContinuousDeployment|Last deployed %{time}')">
            <template #time><time-ago :time="application.lastDeployedAt" /></template>
          </gl-sprintf>
        </template>
      </div>
    </div>
  </div>
</template>
