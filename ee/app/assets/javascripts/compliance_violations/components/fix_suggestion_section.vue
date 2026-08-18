<script>
import { GlButton } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { statusesInfo } from '../../compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info';

export default {
  name: 'FixSuggestionSection',
  components: {
    CrudComponent,
    GlButton,
  },
  props: {
    controlId: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    fixSuggestions() {
      return statusesInfo[this.controlId]?.fixes || [];
    },
    newIssueUrl() {
      return `${this.projectPath}/-/issues/new`;
    },
    projectSettingsUrl() {
      return `${this.projectPath}/edit`;
    },
  },
};
</script>
<template>
  <crud-component>
    <template #title>
      {{ s__('ComplianceViolation|Fix suggestion generated for this failed control') }}
    </template>

    <template #default>
      <div v-for="(fixSuggestion, index) in fixSuggestions" :key="`fix-suggestion-${index}`">
        <div :data-testId="`fix-suggestion-description-${index}`">
          {{ fixSuggestion.description }}
          <a :href="fixSuggestion.link" :data-testId="`fix-suggestion-learn-more-${index}`">
            {{ __('Learn more') }}
          </a>
        </div>
        <div class="gl-mt-3">
          <gl-button
            :href="projectSettingsUrl"
            category="secondary"
            variant="confirm"
            size="small"
            :data-testId="`fix-suggestion-project-settings-${index}`"
          >
            {{ s__('ComplianceViolation|Go to project settings') }}
          </gl-button>

          <gl-button
            :href="newIssueUrl"
            category="secondary"
            variant="confirm"
            size="small"
            :data-testId="`fix-suggestion-create-issue-${index}`"
          >
            {{ __('Create issue') }}
          </gl-button>
        </div>
      </div>
    </template>
  </crud-component>
</template>
