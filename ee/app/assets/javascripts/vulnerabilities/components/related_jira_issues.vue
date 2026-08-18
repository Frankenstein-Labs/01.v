<script>
import jiraLogo from '@gitlab/svgs/dist/illustrations/logos/jira.svg?raw';
import { GlAlert, GlCard, GlIcon, GlLink, GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import CreateJiraIssue from 'ee/vue_shared/security_reports/components/create_jira_issue.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';

export const i18n = {
  cardHeading: s__('VulnerabilityManagement|Related Jira issues'),
  fetchErrorMessage: s__(
    'VulnerabilityManagement|Something went wrong while trying to fetch related Jira issues. Please check the %{linkStart}Jira integration settings%{linkEnd} and try again.',
  ),
  helpPageLinkLabel: s__('VulnerabilityManagement|Read more about related issues'),
  loadingStateLabel: s__('VulnerabilityManagement|Fetching linked Jira issues'),
};

export default {
  name: 'RelatedJiraIssues',
  i18n,
  jiraLogo,
  components: {
    CreateJiraIssue,
    GlAlert,
    GlCard,
    GlIcon,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
    HelpIcon,
  },
  directives: {
    SafeHtml,
  },
  inject: {
    relatedJiraIssuesPath: {
      default: '',
    },
    relatedJiraIssuesHelpPath: {
      default: '',
    },
    jiraIntegrationSettingsPath: {
      default: '',
    },
    vulnerabilityId: { required: true },
  },
  data() {
    return {
      isFetchingRelatedIssues: false,
      hasFetchIssuesError: false,
      isFetchErrorDismissed: false,
      relatedIssues: [],
      showCreateJiraIssueErrorAlertMessage: '',
      isCreateJiraIssueErrorDismissed: false,
      hasCreateJiraIssueError: false,
    };
  },
  computed: {
    shouldShowIssuesBody() {
      return this.isFetchingRelatedIssues || this.relatedIssues.length > 0;
    },
    issuesCount() {
      return this.isFetchingRelatedIssues ? '...' : this.relatedIssues.length;
    },
    lastIssue() {
      const [lastIssue] = this.relatedIssues.slice(-1);
      return lastIssue;
    },
    showFetchErrorAlert() {
      return this.hasFetchIssuesError && !this.isFetchErrorDismissed;
    },
    showCreateJiraIssueErrorAlert() {
      return this.hasCreateJiraIssueError && !this.isCreateJiraIssueErrorDismissed;
    },
  },
  created() {
    this.fetchRelatedIssues();
  },
  methods: {
    createJiraIssueErrorHandler(value) {
      this.hasCreateJiraIssueError = true;
      this.showCreateJiraIssueErrorAlertMessage = value;
    },
    // note: this direct API call will be replaced when migrating the vulnerability details page to GraphQL
    // related epic: https://gitlab.com/groups/gitlab-org/-/epics/3657
    async fetchRelatedIssues() {
      this.isFetchingRelatedIssues = true;
      try {
        const { data } = await axios.get(this.relatedJiraIssuesPath);
        if (Array.isArray(data)) {
          this.relatedIssues = data;
        }
      } catch {
        this.hasFetchIssuesError = true;
      } finally {
        this.isFetchingRelatedIssues = false;
      }
    },
  },
};
</script>
<template>
  <section class="gl-group/panel">
    <gl-alert
      v-if="showFetchErrorAlert"
      variant="danger"
      class="gl-mb-4"
      @dismiss="isFetchErrorDismissed = true"
    >
      <gl-sprintf :message="$options.i18n.fetchErrorMessage">
        <template #link="{ content }">
          <gl-link :href="jiraIntegrationSettingsPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
    <gl-alert
      v-if="showCreateJiraIssueErrorAlert"
      data-testid="create-jira-issue-error-alert"
      variant="danger"
      class="gl-mb-4"
      @dismiss="isCreateJiraIssueErrorDismissed = true"
    >
      {{ showCreateJiraIssueErrorAlertMessage }}
    </gl-alert>
    <gl-card
      class="group-target/panel:gl-bg-feedback-info"
      :header-class="[
        'gl-py-3',
        'gl-flex',
        'gl-items-center',
        'group-target/panel:gl-bg-feedback-info',
        { 'gl-border-b-0': !shouldShowIssuesBody },
      ]"
      :body-class="[
        'gl-bg-subtle',
        'group-target/panel:gl-bg-feedback-info',
        { 'gl-hidden': !shouldShowIssuesBody },
      ]"
    >
      <template #header>
        <h3 class="h5 gl-m-0">{{ $options.i18n.cardHeading }}</h3>
        <gl-link
          v-if="relatedJiraIssuesHelpPath"
          :aria-label="$options.i18n.helpPageLinkLabel"
          :href="relatedJiraIssuesHelpPath"
          target="_blank"
          class="gl-ml-2 gl-flex gl-items-center"
        >
          <help-icon />
        </gl-link>
        <span
          class="gl-ml-4 gl-inline-flex gl-items-center"
          data-testid="related-jira-issues-count"
        >
          <gl-icon name="issues" class="gl-mr-2" variant="subtle" />
          {{ issuesCount }}
        </span>
        <create-jira-issue
          class="gl-ml-auto"
          size="small"
          :vulnerability-id="vulnerabilityId"
          @create-jira-issue-error="createJiraIssueErrorHandler"
          @mutated="fetchRelatedIssues"
        />
      </template>
      <section
        :hidden="!shouldShowIssuesBody"
        class="gl-m-0 gl-p-0"
        data-testid="related-jira-issues-section"
      >
        <gl-card
          class="group-target/panel:gl-bg-feedback-info"
          :body-class="['gl-p-0', 'group-target/panel:gl-bg-feedback-info']"
        >
          <gl-loading-icon
            v-if="isFetchingRelatedIssues"
            ref="loadingIcon"
            size="sm"
            :label="$options.i18n.loadingStateLabel"
            class="gl-my-3"
          />
          <ul class="gl-m-0 gl-list-none gl-p-0">
            <li
              v-for="issue in relatedIssues"
              :key="issue.created_at"
              class="gl-flex gl-items-center gl-px-3 gl-py-3"
              :class="
                issue !== lastIssue && ['gl-border-b-1', 'gl-border-b-default', 'gl-border-b-solid']
              "
            >
              <span
                v-safe-html="$options.jiraLogo"
                class="gl-mr-5 gl-inline-flex gl-min-h-6 gl-items-center"
              >
              </span>
              <gl-link
                :href="issue.web_url"
                target="_blank"
                data-testid="jira-issue-link"
                class="gl-text-default"
              >
                {{ issue.title }}
              </gl-link>
              <span class="gl-ml-3 gl-text-subtle">&num;{{ issue.references.relative }}</span>
            </li>
          </ul>
        </gl-card>
      </section>
    </gl-card>
  </section>
</template>
