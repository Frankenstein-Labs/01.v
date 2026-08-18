<script>
import { GlTooltip, GlIcon, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import { uniqueId, isEmpty } from 'lodash-es';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { __, sprintf } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { SEVERITY_TOOLTIP_TITLE_MAP } from './constants';

export default {
  name: 'SeverityBadge',
  components: {
    TimeAgoTooltip,
    GlIcon,
    GlSprintf,
    GlTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    severity: {
      type: String,
      required: true,
    },
    severityOverride: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    showSeverityOverrides: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    severityDetailsTooltip: __(
      '%{user_name} changed the severity from %{original_severity} to %{new_severity} %{changed_at}.',
    ),
  },
  data() {
    return {
      tooltipId: uniqueId('tooltip-severity-changed-'),
    };
  },
  computed: {
    shouldShowSeverityOverrides() {
      return (
        !this.glFeatures.hideVulnerabilitySeverityOverride &&
        this.showSeverityOverrides &&
        !isEmpty(this.severityOverride)
      );
    },
    hasSeverityBadge() {
      return ['critical', 'high', 'medium', 'low', 'info', 'unknown'].includes(this.severityKey);
    },
    severityKey() {
      return this.severity?.toLowerCase();
    },
    iconName() {
      return `severity-${this.severityKey}`;
    },
    severityTitle() {
      return SEVERITY_LEVELS[this.severityKey] || this.severity;
    },
    tooltipTitle() {
      return SEVERITY_TOOLTIP_TITLE_MAP[this.severityKey];
    },
    severityOverridesTooltipChangesSection() {
      return sprintf(this.$options.i18n.severityDetailsTooltip);
    },
  },
};
</script>

<template>
  <div
    v-if="hasSeverityBadge"
    class="severity-badge gl-whitespace-nowrap gl-text-default @sm/panel:gl-text-left"
  >
    <span :class="`severity-text-${severityKey}`"
      ><gl-icon
        v-gl-tooltip="tooltipTitle"
        :name="iconName"
        :size="12"
        class="gl-mr-3"
        tabindex="-1" /></span
    >{{ severityTitle
    }}<span
      v-if="shouldShowSeverityOverrides"
      class="gl-text-orange-300"
      data-testid="severity-override"
    >
      <gl-icon
        :id="tooltipId"
        v-gl-tooltip
        data-testid="severity-override-icon"
        name="file-modified"
        class="gl-ml-3"
        :size="16"
      />
      <gl-tooltip placement="top" :target="tooltipId">
        <gl-sprintf :message="severityOverridesTooltipChangesSection">
          <template #user_name>
            <strong>{{ severityOverride.author.name }}</strong>
          </template>
          <template #original_severity>
            <strong>{{ severityOverride.originalSeverity.toLowerCase() }}</strong>
          </template>
          <template #new_severity>
            <strong>{{ severityOverride.newSeverity.toLowerCase() }}</strong>
          </template>
          <template #changed_at>
            <time-ago-tooltip ref="timeAgo" :time="severityOverride.createdAt" />
          </template>
        </gl-sprintf>
        <br />
      </gl-tooltip>
    </span>
  </div>
</template>
