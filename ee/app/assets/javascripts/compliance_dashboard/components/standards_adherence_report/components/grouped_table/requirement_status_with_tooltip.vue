<script>
import { GlBadge, GlTooltip, GlSprintf } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import RequirementStatus from '../requirement_status.vue';
import complianceRequirementsControls from '../../graphql/queries/compliance_requirements_controls.query.graphql';
import { EXTERNAL_CONTROL_LABEL } from '../../../../constants';

export default {
  components: {
    GlBadge,
    GlTooltip,
    GlSprintf,
    RequirementStatus,
  },
  props: {
    status: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      complianceRequirementsControls: [],
    };
  },
  apollo: {
    complianceRequirementsControls: {
      query: complianceRequirementsControls,
      update(data) {
        return data.complianceRequirementControls.controlExpressions;
      },
    },
  },
  computed: {
    totalCount() {
      return this.status.pendingCount + this.status.passCount + this.status.failCount;
    },

    relevantControls() {
      const statuses = this.status.project.complianceControlStatus.nodes;
      const knownControls = new Set(
        this.status.complianceRequirement.complianceRequirementsControls.nodes.map((n) => n.id),
      );
      return statuses.filter((status) =>
        knownControls.has(status.complianceRequirementsControl.id),
      );
    },

    pendingControls() {
      return this.relevantControls.filter((control) => control.status === 'PENDING');
    },

    passedControls() {
      return this.relevantControls.filter((control) => control.status === 'PASS');
    },

    failedControls() {
      return this.relevantControls.filter((control) => control.status === 'FAIL');
    },
  },
  methods: {
    getControlName(controlStatus) {
      if (controlStatus.complianceRequirementsControl.controlType === 'external') {
        return (
          controlStatus.complianceRequirementsControl.externalControlName ?? EXTERNAL_CONTROL_LABEL
        );
      }
      return (
        this.complianceRequirementsControls.find(
          (c) => c.id === controlStatus.complianceRequirementsControl.name,
        )?.name ?? controlStatus.complianceRequirementsControl.name
      );
    },
  },
  i18n: {
    EXTERNAL_CONTROL_LABEL,
    failedControls: s__('AdherenceReport|Failed controls'),
    pendingControls: s__('AdherenceReport|Pending controls'),
    passedControls: s__('AdherenceReport|Passed controls'),
    pendingCount: (count) =>
      n__(
        'AdherenceReport|%{pendingCount}/%{totalCount} control is pending',
        'AdherenceReport|%{pendingCount}/%{totalCount} controls are pending',
        count,
      ),
  },
};
</script>
<template>
  <div>
    <gl-tooltip
      :target="() => $refs.status"
      placement="right"
      custom-class="requirement-status-tooltip"
    >
      <div class="gl-text-left">
        <h3
          v-if="status.pendingCount > 0"
          class="gl-m-0 gl-mb-3 gl-text-sm gl-font-bold gl-text-inherit"
        >
          <gl-sprintf :message="$options.i18n.pendingCount(status.pendingCount)">
            <template #totalCount>{{ totalCount }}</template>
            <template #pendingCount>{{ status.pendingCount }}</template>
          </gl-sprintf>
        </h3>
        <template v-if="failedControls.length > 0">
          <h4 class="gl-m-0 gl-mb-3 gl-text-sm gl-font-bold gl-text-inherit">
            {{ $options.i18n.failedControls }}:
          </h4>
          <ul class="gl-mb-4 gl-pl-4">
            <li
              v-for="controlStatus in failedControls"
              :key="controlStatus.id"
              class="gl-text-nowrap"
            >
              {{ getControlName(controlStatus) }}
              <gl-badge
                v-if="controlStatus.complianceRequirementsControl.controlType === 'external'"
              >
                {{ $options.i18n.EXTERNAL_CONTROL_LABEL }}
              </gl-badge>
            </li>
          </ul>
        </template>
        <template v-if="pendingControls.length > 0">
          <h4 class="gl-m-0 gl-mb-3 gl-text-sm gl-font-bold gl-text-inherit">
            {{ $options.i18n.pendingControls }}:
          </h4>
          <ul class="gl-mb-4 gl-pl-4">
            <li v-for="controlStatus in pendingControls" :key="controlStatus.id">
              {{ getControlName(controlStatus) }}
              <gl-badge
                v-if="controlStatus.complianceRequirementsControl.controlType === 'external'"
              >
                {{ $options.i18n.EXTERNAL_CONTROL_LABEL }}
              </gl-badge>
            </li>
          </ul>
        </template>

        <!-- Passed Controls Section -->
        <template v-if="passedControls.length > 0">
          <h4 class="gl-m-0 gl-mb-3 gl-text-sm gl-font-bold gl-text-inherit">
            {{ $options.i18n.passedControls }}:
          </h4>
          <ul class="gl-pl-4">
            <li
              v-for="controlStatus in passedControls"
              :key="controlStatus.id"
              class="gl-text-nowrap"
            >
              {{ getControlName(controlStatus) }}
              <gl-badge
                v-if="controlStatus.complianceRequirementsControl.controlType === 'external'"
              >
                {{ $options.i18n.EXTERNAL_CONTROL_LABEL }}
              </gl-badge>
            </li>
          </ul>
        </template>
      </div>
    </gl-tooltip>
    <requirement-status
      ref="status"
      :pass-count="status.passCount"
      :pending-count="status.pendingCount"
      :fail-count="status.failCount"
      class="gl-inline-flex"
    />
  </div>
</template>
<style>
.requirement-status-tooltip .tooltip-inner {
  max-width: 100%;
}
</style>
