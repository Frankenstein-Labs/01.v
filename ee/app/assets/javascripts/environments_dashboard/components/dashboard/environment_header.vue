<script>
import { GlLink, GlBadge, GlTooltipDirective, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import ReviewAppLink from '~/vue_merge_request_widget/components/review_app_link.vue';

export default {
  components: {
    GlIcon,
    ReviewAppLink,
    GlBadge,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    environment: {
      type: Object,
      required: true,
    },
    hasPipelineFailed: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasErrors: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    headerClasses() {
      return {
        'dashboard-card-header-warning': this.hasErrors,
        'dashboard-card-header-failed': this.hasPipelineFailed,
        '!gl-bg-subtle': !this.hasErrors && !this.hasPipelineFailed,
      };
    },
  },
  reviewButtonText: {
    text: s__('Review App|View app'),
    tooltip: '',
  },
  tooltips: {
    information: s__('EnvironmentDashboard|You are looking at the last updated environment'),
  },
};
</script>

<template>
  <div :class="headerClasses" class="card-header gl-flex gl-items-center !gl-border-0 gl-py-3">
    <div class="!gl-grow gl-truncate">
      <gl-link
        v-gl-tooltip
        class="js-environment-link gl-text-default"
        :href="environment.environment_path"
        :title="environment.name"
      >
        <span class="js-environment-name gl-font-bold"> {{ environment.name }}</span>
      </gl-link>
      <gl-badge v-if="environment.within_folder" variant="neutral">{{ environment.size }}</gl-badge>
    </div>
    <gl-icon
      v-if="environment.within_folder"
      v-gl-tooltip
      :title="$options.tooltips.information"
      name="information"
      variant="subtle"
    />
    <review-app-link
      v-else-if="environment.external_url"
      :link="environment.external_url"
      :display="$options.reviewButtonText"
      css-class="btn btn-default btn-sm"
    />
  </div>
</template>
