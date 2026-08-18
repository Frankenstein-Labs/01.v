<script>
import { GlFormGroup, GlFormCheckbox, GlFormTextarea } from '@gitlab/ui';
import { mapState } from 'pinia';
import { useIntegrationForm } from '~/integrations/edit/store';

export default {
  name: 'JiraVerificationFields',
  components: {
    GlFormGroup,
    GlFormCheckbox,
    GlFormTextarea,
  },
  props: {
    showJiraIssuesIntegration: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialJiraCheckEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialJiraExistsCheckEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialJiraAssigneeCheckEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialJiraStatusCheckEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialJiraAllowedStatusesAsString: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      jiraCheckEnabled: this.initialJiraCheckEnabled, // Use the initial value
      jiraExistsCheckEnabled: this.initialJiraExistsCheckEnabled,
      jiraAssigneeCheckEnabled: this.initialJiraAssigneeCheckEnabled,
      jiraStatusCheckEnabled: this.initialJiraStatusCheckEnabled,
      jiraAllowedStatusesAsString: this.initialJiraAllowedStatusesAsString,
    };
  },
  computed: {
    ...mapState(useIntegrationForm, ['isInheriting']),

    isDisabled() {
      return this.isInheriting || !this.showJiraIssuesIntegration;
    },
  },
};
</script>

<template>
  <div>
    <!-- Use the actual jiraCheckEnabled value -->
    <input
      name="service[jira_check_enabled]"
      type="hidden"
      :value="jiraCheckEnabled ? 'true' : 'false'"
    />
    <gl-form-checkbox
      v-model="jiraCheckEnabled"
      :disabled="isDisabled"
      data-testid="jira-check-enabled-checkbox"
    >
      {{ s__('JiraService|Enable Jira verification') }}
      <template #help>
        {{
          s__(
            'JiraService|Verify Jira issues referenced in commit messages exist before allowing the push.',
          )
        }}
      </template>
    </gl-form-checkbox>

    <div v-if="jiraCheckEnabled" class="gl-mt-3 gl-pl-6">
      <input
        name="service[jira_exists_check_enabled]"
        type="hidden"
        :value="jiraExistsCheckEnabled ? 'true' : 'false'"
      />
      <gl-form-checkbox
        v-model="jiraExistsCheckEnabled"
        :disabled="isDisabled"
        data-testid="jira-exists-check-enabled-checkbox"
      >
        {{ s__('JiraService|Check issue exists') }}
        <template #help>
          {{
            s__('JiraService|Verify the Jira issues referenced in commit messages exist in Jira.')
          }}
        </template>
      </gl-form-checkbox>

      <input
        name="service[jira_assignee_check_enabled]"
        type="hidden"
        :value="jiraAssigneeCheckEnabled ? 'true' : 'false'"
      />
      <gl-form-checkbox
        v-model="jiraAssigneeCheckEnabled"
        :disabled="isDisabled"
        class="gl-mt-3"
        data-testid="jira-assignee-check-enabled-checkbox"
      >
        {{ s__('JiraService|Check assignee') }}
        <template #help>
          {{
            s__(
              'JiraService|Verify the committer is the assignee of the Jira issues referenced in commit messages.',
            )
          }}
        </template>
      </gl-form-checkbox>

      <input
        name="service[jira_status_check_enabled]"
        type="hidden"
        :value="jiraStatusCheckEnabled ? 'true' : 'false'"
      />
      <gl-form-checkbox
        v-model="jiraStatusCheckEnabled"
        :disabled="isDisabled"
        class="gl-mt-3"
        data-testid="jira-status-check-enabled-checkbox"
      >
        {{ s__('JiraService|Check issue status') }}
        <template #help>
          {{ s__('JiraService|Verify the status of Jira issues referenced in commit messages.') }}
        </template>
      </gl-form-checkbox>

      <gl-form-group
        v-if="jiraStatusCheckEnabled"
        :label="s__('JiraService|Allowed statuses')"
        label-for="service_jira_allowed_statuses_as_string"
        :description="s__('JiraService|Comma-separated list of allowed Jira issue statuses.')"
        class="gl-mt-3 gl-pl-6"
        data-testid="jira-allowed-statuses"
      >
        <gl-form-textarea
          id="service_jira_allowed_statuses_as_string"
          v-model="jiraAllowedStatusesAsString"
          name="service[jira_allowed_statuses_as_string]"
          data-testid="jira-allowed-statuses-field"
          :placeholder="s__('JiraService|Ready, In Progress, Review')"
          :readonly="isDisabled"
        />
      </gl-form-group>
    </div>
  </div>
</template>
