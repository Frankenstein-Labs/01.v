<script>
import { GlButton, GlToastMixin } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';

import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import changeLifecycleMutation from 'ee/groups/settings/work_items/custom_status/graphql/change_lifecycle.mutation.graphql';
import namespaceLifecyclesQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_lifecycles.query.graphql';
import { excludeSelfReferencingIds } from '../utils';
import SelectLifecycle from './select_lifecycle.vue';
import StatusMapping from './status_mapping.vue';
import ChangeLifecycleStepper from './change_lifecycle_stepper.vue';

export default {
  name: 'ChangeLifecycleSteps',
  components: {
    ChangeLifecycleStepper,
    SelectLifecycle,
    GlButton,
    LifecycleDetail,
    StatusMapping,
  },
  mixins: [GlToastMixin],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      currentStep: 0,
      lifecycles: [],
      errorText: '',
      selectedLifecycleId: null,
      isValidStep: true,
      isUpdating: false,
    };
  },
  apollo: {
    lifecycles: {
      query: namespaceLifecyclesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data?.namespace?.lifecycles?.nodes || [];
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load lifecycles.');
        Sentry.captureException(error);
      },
    },
  },
  steps: [
    {
      label: s__('WorkItem|Select lifecycle'),
      description: s__('WorkItem|Lifecycle selection'),
    },
    {
      label: s__('WorkItem|Update work items'),
      description: s__('WorkItem|Update work items'),
    },
  ],
  computed: {
    selectedWorkItemType() {
      return this.$route.params.workItemType;
    },
    title() {
      return sprintf(s__('WorkItem|Change lifecycle: %{workItemType}'), {
        workItemType: this.selectedWorkItemType,
      });
    },
    selectedLifecycle() {
      return this.lifecycles?.find((lifecycle) => {
        return lifecycle.id === this.selectedLifecycleId;
      });
    },
    currentLifecycleWorkItemTypes() {
      return this.currentLifecycle?.workItemTypes || [];
    },
    currentWorkItemTypeId() {
      return this.currentLifecycleWorkItemTypes?.find(
        (workItemType) => workItemType.name === this.selectedWorkItemType,
      )?.id;
    },
    currentLifecycle() {
      return this.lifecycles?.find((lifecycle) => {
        return lifecycle.workItemTypes.map((type) => type.name).includes(this.selectedWorkItemType);
      });
    },
  },
  methods: {
    handleStepValidation(validationContext) {
      const { stepIndex } = validationContext;

      // Clear any existing errors
      this.errorText = '';
      this.isValidStep = true;

      // Validate step 0 - lifecycle selection
      if (stepIndex === 0) {
        if (!this.selectedLifecycleId) {
          this.isValidStep = false;
          this.errorText = s__('WorkItem|Select a new lifecycle to continue.');
        }
      }

      // Validate step 1 - status mapping (this won't be the case in the current scenario)
      if (stepIndex === 1) {
        if (
          !this.statusMappings ||
          this.statusMappings.length === 0 ||
          this.statusMappings.length < this.currentLifecycle.statuses.length
        ) {
          this.isValidStep = false;
          this.errorText = s__('WorkItem|All current statuses must be mapped to a new value.');
        }
      }
    },
    goBack() {
      this.currentStep = 0;
    },
    onStepChange({ currentStep }) {
      this.currentStep = currentStep;
    },
    updateStatusMappings(updatedMappings) {
      this.statusMappings = updatedMappings ?? [];
    },
    async mapStatuses() {
      try {
        this.isUpdating = true;

        const leanMapping = excludeSelfReferencingIds(this.statusMappings);

        const { data } = await this.$apollo.mutate({
          mutation: changeLifecycleMutation,
          variables: {
            input: {
              namespacePath: this.fullPath,
              workItemTypeId: this.currentWorkItemTypeId,
              lifecycleId: this.selectedLifecycle.id,
              statusMappings: leanMapping,
            },
          },
        });

        if (data.lifecycleAttachWorkItemType.errors.length) {
          throw new Error(data.lifecycleAttachWorkItemType.errors.join(' '));
        }

        this.$toast.show(s__('WorkItem|Type lifecycle updated.'));

        // Refetch the lifecycles query here since it will update the cache here and
        // show the correct results when the home page is shown
        this.$apollo.queries.lifecycles.refetch();

        this.goToIssuesSettings();
      } catch (error) {
        this.errorText =
          error.message || s__('WorkItem|Something went wrong while updating mappings.');
        Sentry.captureException(error);
      } finally {
        this.isUpdating = false;
      }
    },
    goToIssuesSettings() {
      this.$router.push({
        name: 'workItemSettingsHome',
        hash: '#js-custom-status-settings',
      });
    },
  },
};
</script>

<template>
  <div>
    <h1 class="gl-mb-6 gl-text-size-h-display">{{ title }}</h1>
    <change-lifecycle-stepper
      :steps="$options.steps"
      :initial-step="currentStep"
      :show-back-button="false"
      :is-valid-step="isValidStep"
      :is-updating="isUpdating"
      @finish="mapStatuses"
      @cancel="goToIssuesSettings"
      @step-change="onStepChange"
      @validate-step="handleStepValidation"
    >
      <template #step-0>
        <select-lifecycle
          :work-item-type="selectedWorkItemType"
          :full-path="fullPath"
          :step-error="errorText"
          :selected-lifecycle="selectedLifecycleId"
          @error-dismissed="errorText = ''"
          @lifecycle-selected="selectedLifecycleId = $event"
        />
      </template>
      <template #complete-step-0>
        <div class="gl-mb-2 gl-flex gl-gap-3">
          <div class="gl-text-base gl-font-semibold gl-text-subtle">
            {{ s__('WorkItem|Select lifecycle') }}
          </div>
          <gl-button variant="link" class="gl-text-sm" @click="goBack">
            {{ s__('WorkItem|Change lifecycle') }}
          </gl-button>
        </div>
        <lifecycle-detail
          v-if="selectedLifecycle"
          :lifecycle="selectedLifecycle"
          :full-path="fullPath"
          :show-usage-section="false"
          :show-not-in-use-section="false"
          :show-change-lifecycle-button="false"
          :show-rename-button="false"
        />
      </template>
      <template #step-1>
        <status-mapping
          v-if="selectedLifecycle"
          :current-lifecycle="currentLifecycle"
          :selected-lifecycle="selectedLifecycle"
          :step-error="errorText"
          @error-dismissed="errorText = ''"
          @mapping-updated="updateStatusMappings"
          @initialise-mapping="updateStatusMappings"
        />
      </template>
    </change-lifecycle-stepper>
  </div>
</template>
