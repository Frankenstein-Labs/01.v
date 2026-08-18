<script>
import {
  GlAlert,
  GlButton,
  GlButtonGroup,
  GlCollapsibleListbox,
  GlFormGroup,
  GlFormCheckbox,
  GlFormInput,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { mapState } from 'pinia';
import { s__ } from '~/locale';
import { useIntegrationForm } from '~/integrations/edit/store';
import { defaultJiraIssueTypeId } from '../constants';

export const i18n = {
  checkbox: {
    label: s__('JiraService|Create Jira issues for vulnerabilities'),
    description: s__(
      "JiraService|Create only Jira issues for vulnerabilities in this project even if you've enabled GitLab issues.",
    ),
  },
  issueTypeSelect: {
    description: s__('JiraService|Create Jira issues of this type.'),
    defaultText: s__('JiraService|Select issue type'),
  },
  issueTypeLabel: s__('JiraService|Jira issue type'),
  fetchIssueTypesButtonLabel: s__('JiraService|Fetch issue types for this project key'),
  fetchIssueTypesErrorMessage: s__(
    'JiraService|An error occurred while fetching the Jira issue list',
  ),
  projectKeyWarnings: {
    missing: s__('JiraService|Enter a Jira project key to generate issue types.'),
    changed: s__('JiraService|Fetch issue types again for the new project key.'),
  },
  customizeJiraIssueCheckbox: {
    label: s__('JiraService|Customize Jira issues'),
    description: s__('JiraService|Navigate to Jira issue before issue is created.'),
  },
};

export default {
  name: 'JiraIssueCreationVulnerabilities',
  i18n,
  components: {
    GlAlert,
    GlButton,
    GlButtonGroup,
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormCheckbox,
    GlFormInput,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    showFullFeature: {
      type: Boolean,
      required: false,
      default: true,
    },
    initialIssueTypeId: {
      type: String,
      required: false,
      default: defaultJiraIssueTypeId,
    },
    initialIsEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialProjectKey: {
      type: String,
      required: false,
      default: null,
    },
    initialCustomizeJiraIssueEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    isValidated: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['request-jira-issue-types'],
  data() {
    return {
      isLoadingErrorAlertDismissed: false,
      projectKeyForCurrentIssues: this.initialProjectKey,
      issueCreationProjectKey: this.initialProjectKey,
      isJiraVulnerabilitiesEnabled: this.initialIsEnabled,
      selectedJiraIssueTypeId: null,
      isCustomizeJiraIssueEnabled: this.initialCustomizeJiraIssueEnabled,
    };
  },
  computed: {
    ...mapState(useIntegrationForm, [
      'isInheriting',
      'jiraIssueTypes',
      'isLoadingJiraIssueTypes',
      'loadingJiraIssueTypesErrorMessage',
    ]),
    checkboxDisabled() {
      return !this.showFullFeature || this.isInheriting;
    },
    hasProjectKeyChanged() {
      return (
        this.projectKeyForCurrentIssues &&
        this.issueCreationProjectKey !== this.projectKeyForCurrentIssues
      );
    },
    shouldShowLoadingErrorAlert() {
      return !this.isLoadingErrorAlertDismissed && this.loadingJiraIssueTypesErrorMessage;
    },
    projectKeyWarning() {
      const {
        $options: {
          i18n: { projectKeyWarnings },
        },
      } = this;

      if (!this.issueCreationProjectKey) {
        return projectKeyWarnings.missing;
      }

      if (this.hasProjectKeyChanged) {
        return projectKeyWarnings.changed;
      }
      return '';
    },
    initialJiraIssueType() {
      return this.jiraIssueTypes?.find(({ id }) => {
        return id === this.initialIssueTypeId;
      });
    },
    jiraIssueTypesList() {
      return this.jiraIssueTypes.map((item) => {
        return {
          value: item.id,
          text: item.name,
        };
      });
    },
    jiraIssueTypesToggleText() {
      return (
        this.jiraIssueTypes.find(({ id }) => id === this.selectedJiraIssueTypeId)?.name ||
        this.$options.i18n.issueTypeSelect.defaultText
      );
    },
    validProjectKey() {
      return (
        !this.isJiraVulnerabilitiesEnabled ||
        Boolean(this.issueCreationProjectKey) ||
        !this.isValidated
      );
    },
  },
  watch: {
    jiraIssueTypes() {
      if (!this.selectedJiraIssueTypeId) {
        this.selectedJiraIssueTypeId = this.initialJiraIssueType ? this.initialIssueTypeId : null;
      }
    },
  },
  mounted() {
    if (this.initialIsEnabled) {
      this.requestJiraIssueTypes();
    }
  },
  methods: {
    requestJiraIssueTypes() {
      this.$emit('request-jira-issue-types');
    },
    handleLoadJiraIssueTypesClick() {
      this.requestJiraIssueTypes();
      this.projectKeyForCurrentIssues = this.issueCreationProjectKey;
      this.isLoadingErrorAlertDismissed = false;
    },
  },
};
</script>

<template>
  <div>
    <gl-form-checkbox
      v-model="isJiraVulnerabilitiesEnabled"
      :disabled="checkboxDisabled"
      data-testid="jira-enable-vulnerabilities-checkbox"
    >
      <span>{{ $options.i18n.checkbox.label }}</span>
      <template #help>
        {{ $options.i18n.checkbox.description }}
      </template>
    </gl-form-checkbox>

    <template v-if="showFullFeature">
      <input
        name="service[vulnerabilities_enabled]"
        type="hidden"
        :value="isJiraVulnerabilitiesEnabled"
      />
      <div
        v-if="isJiraVulnerabilitiesEnabled"
        class="gl-ml-6 gl-mt-3"
        data-testid="issue-type-section"
      >
        <gl-form-group
          :label="s__('JiraService|Jira project key')"
          label-for="service_project_key"
          :invalid-feedback="__('This field is required.')"
          :state="validProjectKey"
          data-testid="jira-project-key"
        >
          <gl-form-input
            id="service_project_key"
            v-model="issueCreationProjectKey"
            name="service[project_key]"
            width="md"
            data-testid="jira-project-key-field"
            :placeholder="s__('JiraService|AB')"
            :required="isJiraVulnerabilitiesEnabled"
            :state="validProjectKey"
            :readonly="isInheriting"
          />
        </gl-form-group>

        <label id="issue-type-label" class="gl-mb-0">{{ $options.i18n.issueTypeLabel }}</label>
        <p class="gl-mb-3">{{ $options.i18n.issueTypeSelect.description }}</p>
        <gl-alert
          v-if="shouldShowLoadingErrorAlert"
          class="gl-mb-5"
          variant="danger"
          :title="$options.i18n.fetchIssueTypesErrorMessage"
          @dismiss="isLoadingErrorAlertDismissed = true"
        >
          {{ loadingJiraIssueTypesErrorMessage }}
        </gl-alert>
        <div class="gl-mb-5 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
          <input
            name="service[vulnerabilities_issuetype]"
            type="hidden"
            :value="selectedJiraIssueTypeId || initialIssueTypeId"
          />
          <gl-button-group>
            <gl-collapsible-listbox
              v-model="selectedJiraIssueTypeId"
              :items="jiraIssueTypesList"
              :disabled="!jiraIssueTypes.length"
              :loading="isLoadingJiraIssueTypes"
              :toggle-text="jiraIssueTypesToggleText"
              class="btn-group"
              data-testid="jira-select-issue-type-dropdown"
              toggle-aria-labelled-by="issue-type-label"
            >
              <template #list-item="{ item }">
                <span data-testid="jira-type" :data-qa-service-type="item.text">{{
                  item.text
                }}</span>
              </template>
            </gl-collapsible-listbox>
            <gl-button
              v-gl-tooltip.hover
              :title="$options.i18n.fetchIssueTypesButtonLabel"
              :aria-label="$options.i18n.fetchIssueTypesButtonLabel"
              :disabled="!issueCreationProjectKey"
              icon="retry"
              data-testid="jira-issue-types-fetch-retry-button"
              @click="handleLoadJiraIssueTypesClick"
            />
          </gl-button-group>
          <p v-if="projectKeyWarning" class="gl-my-0">
            <gl-icon name="warning" variant="warning" />
            {{ projectKeyWarning }}
          </p>
        </div>

        <div class="gl-mb-5">
          <gl-form-checkbox
            v-model="isCustomizeJiraIssueEnabled"
            data-testid="customize-jira-issue-checkbox"
          >
            <span>{{ $options.i18n.customizeJiraIssueCheckbox.label }}</span>
            <template #help>
              {{ $options.i18n.customizeJiraIssueCheckbox.description }}
            </template>
          </gl-form-checkbox>

          <input
            name="service[customize_jira_issue_enabled]"
            type="hidden"
            :value="isCustomizeJiraIssueEnabled"
          />
        </div>
      </div>
    </template>
  </div>
</template>
