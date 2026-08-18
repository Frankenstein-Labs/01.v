<script>
import { GlAlert, GlButton, GlFormInput, GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { s__, __, n__ } from '~/locale';
import { getTimeago, humanizeTimeInterval } from '~/lib/utils/datetime_utility';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import {
  isGroup,
  isPolicyInherited,
  createSpepTestRunSubscription,
} from 'ee/security_orchestration/components/utils';
import { TEST_RUN_STATES } from 'ee/security_orchestration/components/policies/constants';
import { getTestRunsForProject } from 'ee/security_orchestration/components/policies/utils';
import spepTestRunMutation from 'ee/security_orchestration/graphql/mutations/spep_test_run.mutation.graphql';
import projectPolicyTestRunsQuery from 'ee/security_orchestration/graphql/queries/project_policy_test_runs.query.graphql';
import groupPolicyTestRunsQuery from 'ee/security_orchestration/graphql/queries/group_policy_test_runs.query.graphql';

const SECONDS_PER_HOUR = 3600;

export default {
  name: 'TestRunsTab',
  components: {
    GlAlert,
    GlButton,
    GlFormInput,
    GlLoadingIcon,
    GlSprintf,
    GroupProjectsDropdown,
  },
  inject: ['namespaceType', 'namespacePath'],
  props: {
    policy: {
      type: Object,
      required: true,
    },
    activeTestRun: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['test-run-created'],
  data() {
    return {
      errorMessage: null,
      selectedProject: null,
      isRunningTest: false,
      matchingPolicyData: null,
      liveTestRun: null,
      testRunData: this.activeTestRun,
    };
  },
  apollo: {
    matchingPolicyData: {
      query() {
        return this.isGroupLevel ? groupPolicyTestRunsQuery : projectPolicyTestRunsQuery;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const policies = data?.namespace?.securityPolicies?.nodes || [];
        return policies.find((p) => p.name === this.policy.name) ?? null;
      },
    },
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      testRunUpdated: createSpepTestRunSubscription('testRun', 'liveTestRun'),
    },
  },
  projectSelectorId: 'test-runs-project-selector',
  computed: {
    isGroupLevel() {
      return isGroup(this.namespaceType);
    },
    isInheritedProjectPolicy() {
      return !this.isGroupLevel && isPolicyInherited(this.policy.source);
    },
    isLoadingTestRun() {
      return this.$apollo.queries.matchingPolicyData?.loading;
    },
    testRun() {
      if (this.liveTestRun) return this.liveTestRun;
      const filtered = getTestRunsForProject(this.matchingPolicyData?.testRuns, {
        isGroup: this.isGroupLevel,
        source: this.policy.source,
        namespacePath: this.namespacePath,
      });
      const fromQuery = filtered?.nodes?.[0] ?? null;
      // When ids match we return fromQuery: Apollo writes subscription
      // responses to the normalized cache by id (SpepTestRun includes id
      // + __typename), so the cached query result reactively reflects the
      // subscription's latest state — never rolling back what subscription
      // advanced. When ids differ the cache is stale relative to a run we
      // already know about via activeTestRun (typically started from the
      // policy list before the cache caught up), so keep what we have.
      if (this.testRunData && fromQuery?.id !== this.testRunData.id) {
        return this.testRunData;
      }
      return fromQuery;
    },
    testRunFailed() {
      return this.testRun?.state === TEST_RUN_STATES.FAILED;
    },
    testRunErrorMessage() {
      if (!this.testRunFailed) return null;
      return (
        this.testRun?.errorMessage ||
        s__(
          'SecurityOrchestration|The test run failed for an unspecified reason. Please try again.',
        )
      );
    },
    hasError() {
      return Boolean(this.errorMessage);
    },
    canRunTest() {
      const state = this.testRun?.state;
      const isActive = state === TEST_RUN_STATES.RUNNING || state === TEST_RUN_STATES.PENDING;
      if (this.isRunningTest || isActive) return false;
      return this.isGroupLevel ? Boolean(this.selectedProject) : true;
    },
    selectedProjectId() {
      return this.selectedProject?.id;
    },
    projectPath() {
      if (this.isGroupLevel) {
        return this.selectedProject?.fullPath;
      }
      return this.namespacePath;
    },
    policyId() {
      return this.policy?.id;
    },
    noTestRunsMessage() {
      return this.isInheritedProjectPolicy
        ? this.$options.i18n.noTestRunsOnProject
        : this.$options.i18n.noTestRuns;
    },
    linkedProjectsCount() {
      return this.matchingPolicyData?.linkedProjectsCount ?? null;
    },
    scheduleTimeWindowSeconds() {
      return this.matchingPolicyData?.policyAttributes?.scheduleTimeWindowSeconds ?? null;
    },
    estimatedTotalDuration() {
      if (this.testRun?.duration == null || !this.linkedProjectsCount) return null;
      return this.testRun.duration * this.linkedProjectsCount;
    },
    pipelinesPerHour() {
      if (!this.linkedProjectsCount || !this.scheduleTimeWindowSeconds) return null;
      return this.linkedProjectsCount / (this.scheduleTimeWindowSeconds / SECONDS_PER_HOUR);
    },
    formattedPipelinesPerHour() {
      if (this.pipelinesPerHour == null || this.testRun?.duration == null) return null;
      if (this.pipelinesPerHour < 0.1) return null;
      return this.pipelinesPerHour < 1
        ? this.pipelinesPerHour.toFixed(1)
        : String(Math.round(this.pipelinesPerHour));
    },
    pipelinesPerHourMessage() {
      return n__(
        'SecurityOrchestration|Max estimated rate: approximately %{rate} pipeline per hour',
        'SecurityOrchestration|Max estimated rate: approximately %{rate} pipelines per hour',
        this.pipelinesPerHour,
      );
    },
    description() {
      return this.isGroupLevel
        ? s__(
            'SecurityOrchestration|Run a test to understand how this policy will impact your infrastructure before enabling it across all projects. The test executes a real pipeline and projects estimates across all linked projects.',
          )
        : s__(
            'SecurityOrchestration|Run a test to understand how this policy will impact your infrastructure before enabling it on this project. The test executes a real pipeline and projects estimates across all linked projects.',
          );
    },
  },
  watch: {
    activeTestRun(newRun, oldRun) {
      // When the parent updates the active test run for this policy (eg. user
      // starts another dry run from the list while the drawer is open), pick up
      // the new run. Guard on id so subscription updates aren't clobbered when
      // the same run object is re-emitted.
      if (newRun?.id !== oldRun?.id) {
        this.testRunData = newRun;
      }
    },
  },
  methods: {
    onProjectSelect(project) {
      this.selectedProject = project;
    },
    dismissError() {
      this.errorMessage = null;
    },
    async handleTestRun() {
      if (this.isRunningTest || !this.canRunTest) return;

      this.isRunningTest = true;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: spepTestRunMutation,
          variables: {
            policyId: this.policyId,
            projectPath: this.projectPath,
          },
        });

        const { testRun, errors } = data?.pipelineExecutionSchedulePolicyTestRun ?? {};

        if (errors?.length) {
          this.errorMessage = errors.join(', ');
        } else if (testRun) {
          this.$emit('test-run-created', testRun);
          this.liveTestRun = testRun;
        }
      } catch (error) {
        this.errorMessage =
          error.message ||
          s__('SecurityOrchestration|An error occurred while starting the test run.');
      } finally {
        this.isRunningTest = false;
      }
    },
    formatTimeAgo(timestamp) {
      if (!timestamp) return '';
      return getTimeago().format(timestamp);
    },
    formatDuration(seconds) {
      if (seconds === null || seconds === undefined) return '';
      return humanizeTimeInterval(seconds);
    },
    formatState(state) {
      const stateMap = {
        [TEST_RUN_STATES.PENDING]: __('Pending'),
        [TEST_RUN_STATES.RUNNING]: __('Running'),
        [TEST_RUN_STATES.COMPLETE]: __('Complete'),
        [TEST_RUN_STATES.FAILED]: __('Failed'),
      };
      return stateMap[state] || state;
    },
  },
  i18n: {
    title: s__('SecurityOrchestration|Test runs'),
    noTestRuns: s__('SecurityOrchestration|No test runs found for this policy.'),
    noTestRunsOnProject: s__(
      'SecurityOrchestration|No test runs found for this policy on this project.',
    ),
    latestTestRun: s__('SecurityOrchestration|Results of most recent test'),
    state: s__('SecurityOrchestration|State: %{state}'),
    project: s__('SecurityOrchestration|Project: %{project}'),
    startedAt: s__('SecurityOrchestration|Started: %{time}'),
    completed: s__('SecurityOrchestration|Completed: %{time}'),
    duration: s__('SecurityOrchestration|Duration: %{duration}'),
    error: s__('SecurityOrchestration|Error: %{error}'),
    linkedProjectsCount: s__('SecurityOrchestration|Linked projects: %{count}'),
    estimatedTotalDuration: s__('SecurityOrchestration|Max estimated total run time: %{duration}'),
  },
};
</script>

<template>
  <div class="gl-ml-6 gl-mr-3 gl-mt-5">
    <h5 class="gl-mt-0" data-testid="test-runs-title">{{ $options.i18n.title }}</h5>
    <p class="gl-text-secondary" data-testid="test-runs-description">
      {{ description }}
    </p>

    <gl-alert
      v-if="hasError"
      variant="danger"
      class="gl-mb-4"
      data-testid="error-alert"
      @dismiss="dismissError"
    >
      {{ errorMessage }}
    </gl-alert>

    <div class="gl-flex gl-flex-col gl-gap-4">
      <div data-testid="project-selector-section">
        <label
          :for="$options.projectSelectorId"
          class="gl-font-bold"
          data-testid="project-selector-label"
        >
          {{ s__('SecurityOrchestration|Select target project') }}
        </label>
        <group-projects-dropdown
          v-if="isGroupLevel"
          :id="$options.projectSelectorId"
          class="gl-mt-2"
          :group-full-path="namespacePath"
          :multiple="false"
          :selected="selectedProjectId"
          :state="true"
          data-testid="project-selector"
          @select="onProjectSelect"
        />
        <gl-form-input
          v-else
          :id="$options.projectSelectorId"
          class="gl-mt-2"
          :value="namespacePath"
          disabled
          data-testid="project-path-display"
        />
        <p class="gl-mt-2 gl-text-sm gl-text-secondary" data-testid="project-selector-help-text">
          {{
            s__('SecurityOrchestration|Only projects where you have owner permissions are shown')
          }}
        </p>
      </div>

      <div>
        <gl-button
          variant="confirm"
          :loading="isRunningTest"
          :disabled="!canRunTest"
          data-testid="run-test-button"
          @click="handleTestRun"
        >
          {{ s__('SecurityOrchestration|Begin test run') }}
        </gl-button>
      </div>

      <template v-if="testRun">
        <hr data-testid="results-divider" />

        <div aria-live="polite" data-testid="test-run-results">
          <h5 class="gl-mt-0">{{ $options.i18n.latestTestRun }}</h5>

          <ul class="gl-pl-4" data-testid="test-run-details">
            <li class="gl-mb-2">
              <gl-sprintf :message="$options.i18n.state">
                <template #state>{{ formatState(testRun.state) }}</template>
              </gl-sprintf>
            </li>
            <li v-if="testRun.project" class="gl-mb-2">
              <gl-sprintf :message="$options.i18n.project">
                <template #project>{{ testRun.project.fullPath }}</template>
              </gl-sprintf>
            </li>
            <li v-if="testRun.startedAt" class="gl-mb-2">
              <gl-sprintf :message="$options.i18n.startedAt">
                <template #time>{{ formatTimeAgo(testRun.startedAt) }}</template>
              </gl-sprintf>
            </li>
            <li v-if="testRun.finishedAt" class="gl-mb-2">
              <gl-sprintf :message="$options.i18n.completed">
                <template #time>{{ formatTimeAgo(testRun.finishedAt) }}</template>
              </gl-sprintf>
            </li>
            <li v-if="Number.isFinite(testRun.duration)" class="gl-mb-2">
              <gl-sprintf :message="$options.i18n.duration">
                <template #duration>{{ formatDuration(testRun.duration) }}</template>
              </gl-sprintf>
            </li>
            <li v-if="linkedProjectsCount" class="gl-mb-2" data-testid="linked-projects-count">
              <gl-sprintf :message="$options.i18n.linkedProjectsCount">
                <template #count>{{ linkedProjectsCount }}</template>
              </gl-sprintf>
            </li>
            <li
              v-if="estimatedTotalDuration != null"
              class="gl-mb-2"
              data-testid="estimated-total-duration"
            >
              <gl-sprintf :message="$options.i18n.estimatedTotalDuration">
                <template #duration>{{ formatDuration(estimatedTotalDuration) }}</template>
              </gl-sprintf>
            </li>
            <li
              v-if="formattedPipelinesPerHour !== null"
              class="gl-mb-2"
              data-testid="pipelines-per-hour"
            >
              <gl-sprintf :message="pipelinesPerHourMessage">
                <template #rate>{{ formattedPipelinesPerHour }}</template>
              </gl-sprintf>
            </li>
            <li v-if="testRunErrorMessage" class="gl-mb-2 gl-text-danger">
              <gl-sprintf :message="$options.i18n.error">
                <template #error>{{ testRunErrorMessage }}</template>
              </gl-sprintf>
            </li>
          </ul>
        </div>
      </template>

      <gl-loading-icon v-else-if="isLoadingTestRun" size="lg" data-testid="loading-icon" />

      <p v-else class="gl-text-secondary" data-testid="no-test-runs">
        {{ noTestRunsMessage }}
      </p>
    </div>
  </div>
</template>
