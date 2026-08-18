<script>
import { GlAlert, GlBadge, GlButton, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import cdApplicationDeploymentFlowQuery from '../graphql/cd_application_deployment_flow.query.graphql';
import cdRolloutFlowQuery from '../graphql/cd_rollout_flow.query.graphql';
import cdRolloutStepUpdatedSubscription from '../graphql/cd_rollout_step_updated.subscription.graphql';
import { isStage, withNodeIds, buildFlowEdges } from '../flow_graph';
import { flowFromRolloutSteps, rolloutProgress } from '../flow_from_rollout';
import { rolloutStateDotClass, rolloutStateLabel } from '../utils';
import { FLOW_TRIGGER, STAGE_RUNNING_STATE } from '../constants';
import FlowStep from './flow_step.vue';
import FlowStage from './flow_stage.vue';
import FlowConnectors from './flow_connectors.vue';

export default {
  name: 'ApplicationFlow',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlLoadingIcon,
    FlowStep,
    FlowStage,
    FlowConnectors,
  },
  directives: { GlTooltip: GlTooltipDirective },
  props: {
    applicationId: {
      type: String,
      required: true,
    },
    selectedDeploymentId: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['rollout-selected'],
  data() {
    return {
      flowData: {
        active: null,
        latestFinished: null,
        applicationFlow: null,
      },
      selectedDeployment: null,
      flowDataError: false,
      selectedDeploymentError: false,
      stageOverrides: {},
    };
  },
  apollo: {
    flowData: {
      query: cdApplicationDeploymentFlowQuery,
      variables() {
        return { applicationId: this.applicationId };
      },
      update(data) {
        const application = data?.organization?.cdApplication;

        return {
          active: application?.activeRollout?.nodes?.[0] ?? null,
          latestFinished: application?.latestFinishedRollout?.nodes?.[0] ?? null,
          applicationFlow: application?.applicationFlowDefinitions?.nodes?.[0] ?? null,
        };
      },
      error() {
        this.flowDataError = true;
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.flowDataError = false;
        }
      },
    },
    selectedDeployment: {
      query: cdRolloutFlowQuery,
      variables() {
        return { id: this.selectedDeploymentId };
      },
      skip() {
        return !this.selectedDeploymentId;
      },
      update(data) {
        return data?.organization?.cdRollout ?? null;
      },
      error() {
        this.selectedDeploymentError = true;
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.selectedDeploymentError = false;
        }
      },
      subscribeToMore: {
        document: cdRolloutStepUpdatedSubscription,
        variables() {
          return { rolloutId: this.selectedDeploymentId };
        },
        skip() {
          return !this.selectedDeploymentId;
        },
      },
    },
  },
  computed: {
    isLoading() {
      return (
        this.$apollo.queries.flowData.loading || this.$apollo.queries.selectedDeployment.loading
      );
    },
    hasError() {
      return this.selectedDeploymentId ? this.selectedDeploymentError : this.flowDataError;
    },
    selectedRollout() {
      if (this.selectedDeploymentId) {
        return this.selectedDeployment?.id === this.selectedDeploymentId
          ? this.selectedDeployment
          : null;
      }

      return (
        [this.flowData.active, this.flowData.latestFinished].find(
          (rollout) => rollout?.applicationFlowDefinition,
        ) ?? null
      );
    },
    flowDefinition() {
      if (this.selectedRollout) {
        return this.selectedRollout.applicationFlowDefinition ?? null;
      }

      return this.selectedDeploymentId ? null : this.flowData.applicationFlow;
    },
    hasFlow() {
      return Boolean(this.flowDefinition);
    },
    version() {
      return this.flowDefinition?.version;
    },
    versionLabel() {
      return sprintf(s__('FlowEditor|Version %{version}'), { version: this.version });
    },
    latestDefinition() {
      return this.flowDefinition?.definition ?? '';
    },
    flowEditorRoute() {
      return {
        name: 'flow_editor_route',
        params: { id: String(getIdFromGraphQLId(this.applicationId)) },
      };
    },
    rolloutSteps() {
      return this.selectedRollout?.rolloutSteps ?? [];
    },
    hasRolloutSteps() {
      return this.rolloutSteps.length > 0;
    },
    rolloutMeta() {
      const rollout = this.selectedRollout;
      if (!rollout) return null;

      const { completed, total } = rolloutProgress(this.rolloutSteps);

      return {
        reference: `#${rollout.iid}`,
        releaseName: rollout.versionSet?.name ?? '',
        progress: `(${completed}/${total})`,
        stateLabel: rolloutStateLabel(rollout.state),
        stateDotClass: rolloutStateDotClass(rollout.state),
      };
    },
    flowItems() {
      return withNodeIds([FLOW_TRIGGER, ...flowFromRolloutSteps(this.rolloutSteps)]);
    },
    stages() {
      return this.flowItems.filter(isStage);
    },
    allStagesExpanded() {
      return this.stages.every((stage) => this.isExpanded(stage));
    },
    expandedItems() {
      return this.flowItems.map((item) => this.isExpanded(item));
    },
    flowEdges() {
      return buildFlowEdges(this.flowItems, this.expandedItems);
    },
  },
  watch: {
    selectedRollout: {
      immediate: true,
      handler(rollout) {
        this.$emit('rollout-selected', {
          id: rollout?.id ?? null,
          versionSetId: rollout?.versionSet?.id ?? null,
        });
      },
    },
  },
  methods: {
    isExpanded(item) {
      return this.stageOverrides[item.id] ?? (isStage(item) && item.state === STAGE_RUNNING_STATE);
    },
    toggleStage(item) {
      this.stageOverrides = { ...this.stageOverrides, [item.id]: !this.isExpanded(item) };
    },
    toggleAllStages() {
      const expanded = !this.allStagesExpanded;

      this.stageOverrides = {
        ...this.stageOverrides,
        ...Object.fromEntries(this.stages.map((stage) => [stage.id, expanded])),
      };
    },
    isStage,
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" />

    <gl-alert v-else-if="hasError" variant="danger" :dismissible="false">
      {{ s__('FlowEditor|Failed to load the application flow. Refresh to try again.') }}
    </gl-alert>

    <div
      v-else
      class="gl-overflow-hidden gl-rounded-2xl gl-border-1 gl-border-solid gl-border-default gl-bg-subtle"
    >
      <template v-if="hasFlow">
        <div class="gl-border-b gl-flex gl-items-center gl-justify-between gl-p-3">
          <div class="gl-flex gl-w-full gl-items-center gl-gap-3 gl-px-3 @lg:gl-justify-between">
            <div
              v-if="rolloutMeta"
              v-gl-tooltip
              :title="rolloutMeta.stateLabel"
              class="gl-flex gl-items-center gl-gap-3 gl-text-sm"
              data-testid="rollout-meta"
            >
              <span
                :class="rolloutMeta.stateDotClass"
                class="gl-inline-block gl-h-2 gl-w-2 gl-shrink-0 gl-rounded-full"
              ></span>
              <span class="gl-sr-only">{{ rolloutMeta.stateLabel }}</span>
              <span class="gl-font-bold">{{ rolloutMeta.reference }}</span>
              <span class="gl-text-subtle" aria-hidden="true">&middot;</span>
              <span>{{ rolloutMeta.releaseName }}</span>
              <span class="gl-text-subtle">{{ rolloutMeta.progress }}</span>
            </div>

            <gl-badge variant="neutral">{{ versionLabel }}</gl-badge>
          </div>

          <gl-button
            v-if="!hasRolloutSteps"
            size="small"
            category="secondary"
            variant="default"
            icon="pencil"
            :to="flowEditorRoute"
            data-testid="edit-flow-button"
          >
            {{ s__('FlowEditor|Edit flow') }}
          </gl-button>
        </div>

        <div
          v-if="hasRolloutSteps"
          class="flow-canvas gl-bg-subtle gl-pt-5"
          data-testid="flow-canvas"
        >
          <div class="gl-flex gl-justify-end gl-gap-3 gl-px-5">
            <gl-button
              v-if="stages.length"
              size="small"
              category="secondary"
              variant="default"
              data-testid="toggle-all-stages-button"
              @click="toggleAllStages"
            >
              {{ allStagesExpanded ? __('Collapse all') : __('Expand all') }}
            </gl-button>

            <gl-button
              size="small"
              category="secondary"
              variant="default"
              :to="flowEditorRoute"
              data-testid="edit-flow-button"
            >
              {{ s__('FlowEditor|Edit flow') }}
            </gl-button>
          </div>
          <div class="gl-flex gl-min-h-30 gl-overflow-auto gl-pt-5">
            <div class="gl-relative gl-flex gl-items-center gl-gap-7 gl-px-5 gl-pb-5">
              <flow-connectors :edges="flowEdges" />

              <template v-for="(item, itemIndex) in flowItems">
                <flow-stage
                  v-if="isStage(item)"
                  :key="item.nodeId"
                  :node-id="item.nodeId"
                  :expanded="expandedItems[itemIndex]"
                  :title="item.title"
                  :state="item.state"
                  :environments-count="item.environmentsCount"
                  :steps="item.steps"
                  @toggle="toggleStage(item)"
                >
                  <div class="gl-flex gl-items-center gl-gap-7">
                    <flow-step
                      v-for="step in item.steps"
                      :key="step.nodeId"
                      :node-id="step.nodeId"
                      :category="step.category"
                      :state="step.state"
                      :title="step.title"
                      :subtitle="step.subtitle"
                    />
                  </div>
                </flow-stage>

                <flow-step
                  v-else
                  :key="item.nodeId"
                  :node-id="item.nodeId"
                  :category="item.category"
                  :state="item.state"
                  :title="item.title"
                  :subtitle="item.subtitle"
                  class="gl-mt-8"
                />
              </template>
            </div>
          </div>
        </div>

        <pre
          v-else
          class="gl-mb-0 gl-max-h-31 gl-overflow-auto gl-border-none gl-p-3 gl-text-sm"
          data-testid="flow-definition"
          >{{ latestDefinition }}</pre>
      </template>

      <div
        v-else
        class="gl-flex gl-flex-col gl-items-center gl-justify-center gl-gap-3 gl-py-6 gl-text-center"
      >
        <p class="gl-mb-0 gl-text-subtle">
          {{ s__('FlowEditor|No flow is defined for this application yet.') }}
        </p>
        <gl-button
          size="small"
          category="primary"
          variant="confirm"
          icon="plus"
          :to="flowEditorRoute"
          data-testid="create-flow-button"
        >
          {{ s__('FlowEditor|Create flow') }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
