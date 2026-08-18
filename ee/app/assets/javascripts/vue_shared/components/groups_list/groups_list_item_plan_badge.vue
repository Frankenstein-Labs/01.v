<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'GroupsListItemPlanBadge',
  components: { GlIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
  },
  computed: {
    shouldShowIcon() {
      return window.gon?.saas_features?.gitlabComSubscriptions && this.group.plan?.isPaid;
    },
    tooltipTitle() {
      if (!this.shouldShowIcon) {
        return '';
      }

      return sprintf(s__('AdminGroups|%{planTitle} Plan'), { planTitle: this.group.plan.title });
    },
  },
};
</script>

<template>
  <gl-icon
    v-if="shouldShowIcon"
    v-gl-tooltip="tooltipTitle"
    name="license"
    class="plan-badge-vue"
    :data-plan="group.plan.name"
    data-testid="plan-badge"
  />
</template>
