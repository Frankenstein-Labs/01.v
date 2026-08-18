<script>
import Tracking from '~/tracking';
import ComplianceStandardsAdherenceTableV2 from './standards_adherence_table_v2.vue';

export default {
  name: 'ComplianceStandardsAdherenceReport',
  components: {
    ComplianceStandardsAdherenceTableV2,
  },
  mixins: [Tracking.mixin()],
  inject: ['activeComplianceFrameworks'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  mounted() {
    const additionalProperties = this.activeComplianceFrameworks
      ? {
          with_active_compliance_frameworks: 'true',
        }
      : {};
    this.track('user_perform_visit', additionalProperties);
  },
};
</script>

<template>
  <compliance-standards-adherence-table-v2 :group-path="groupPath" :project-path="projectPath" />
</template>
