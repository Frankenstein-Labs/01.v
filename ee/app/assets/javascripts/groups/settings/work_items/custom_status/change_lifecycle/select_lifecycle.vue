<script>
import { GlFormRadio, GlFormRadioGroup, GlButton, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

import * as Sentry from '~/sentry/sentry_browser_wrapper';
import namespaceLifecyclesQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_lifecycles.query.graphql';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import CreateLifecycleModal from 'ee/groups/settings/work_items/custom_status/create_lifecycle_modal.vue';

export default {
  name: 'SelectLifecycle',
  components: {
    LifecycleDetail,
    GlFormRadio,
    GlFormRadioGroup,
    GlButton,
    CreateLifecycleModal,
    GlLoadingIcon,
    GlAlert,
  },
  props: {
    workItemType: {
      type: String,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    stepError: {
      type: String,
      required: false,
      default: '',
    },
    selectedLifecycle: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['error-dismissed', 'lifecycle-selected'],
  data() {
    return {
      lifecycles: [],
      selectedLifecycleId: this.selectedLifecycle,
      showModal: false,
      initialLifecyclesLoaded: false,
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
      result() {
        this.initialLifecyclesLoaded = true;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load lifecycles.');
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    selectedLifecycleIntro() {
      return sprintf(
        s__(
          "WorkItem|Select the lifecycle you'd like to use for items with type: %{workItemType}. Next, you'll define how to map existing work items to the new lifecycle.",
        ),
        { workItemType: this.workItemType },
      );
    },
    currentLifecycle() {
      return this.lifecycles?.find((lifecycle) => {
        return lifecycle.workItemTypes.map((type) => type.name).includes(this.workItemType);
      });
    },
    filteredLifecyclesOfCurrentLifecycle() {
      return this.lifecycles?.filter((lifecycle) => {
        return !lifecycle.workItemTypes.map((type) => type.name).includes(this.workItemType);
      });
    },
    loadingLifecycles() {
      return !this.initialLifecyclesLoaded && this.$apollo.queries.lifecycles.loading;
    },
  },
  methods: {
    refetchLifecycles() {
      this.$apollo.queries.lifecycles.refetch();
    },
    isLifecycleSelected(lifecycle) {
      return this.selectedLifecycleId === lifecycle?.id;
    },
    closeModal() {
      this.refetchLifecycles();
      this.showModal = false;
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="loadingLifecycles" size="lg" class="gl-mt-3" />

    <template v-else>
      <p class="gl-text-subtle">
        {{ selectedLifecycleIntro }}
      </p>
      <gl-alert
        v-if="stepError"
        class="gl-my-3"
        variant="danger"
        @dismiss="$emit('error-dismissed')"
      >
        {{ stepError }}
      </gl-alert>
      <div>
        <div data-testid="current-lifecycle-container">
          <div class="gl-mb-4 gl-font-semibold gl-text-subtle">
            {{ s__('WorkItem|Current lifecycle') }}
          </div>
          <lifecycle-detail
            :lifecycle="currentLifecycle"
            :full-path="fullPath"
            :class="{
              'gl-border-blue-500': isLifecycleSelected(currentLifecycle),
            }"
            :show-usage-section="false"
            :show-not-in-use-section="false"
            :show-change-lifecycle-button="false"
            :show-rename-button="false"
          />
        </div>

        <div data-testid="existing-lifecycles-container">
          <div class="gl-mb-4 gl-mt-4 gl-font-semibold gl-text-subtle">
            {{ s__('WorkItem|Select new lifecycle') }}
          </div>

          <gl-form-radio-group
            v-if="filteredLifecyclesOfCurrentLifecycle.length"
            v-model="selectedLifecycleId"
            name="select-lifecycle-radio"
            @change="$emit('lifecycle-selected', selectedLifecycleId)"
          >
            <div v-if="lifecycles" class="gl-flex gl-flex-col gl-gap-4">
              <lifecycle-detail
                v-for="lifecycle in filteredLifecyclesOfCurrentLifecycle"
                :key="lifecycle.id"
                :full-path="fullPath"
                :lifecycle="lifecycle"
                :class="{
                  'gl-border-blue-500': isLifecycleSelected(lifecycle),
                }"
                show-radio-selection
                show-not-in-use-section
                show-usage-section
                :show-remove-lifecycle-button="false"
                :show-change-lifecycle-button="false"
              >
                <template #radio-selection>
                  <gl-form-radio :key="lifecycle.id" :value="lifecycle.id">
                    <span class="gl-font-bold">{{ lifecycle.name }}</span>
                  </gl-form-radio>
                </template>
              </lifecycle-detail>
            </div>
          </gl-form-radio-group>

          <div v-else class="gl-my-3">
            {{ s__('WorkItem|No other lifecycles exist. Create a new lifecycle to use.') }}
          </div>
        </div>

        <gl-button category="tertiary" icon="plus" class="gl-mt-4" @click="showModal = true">
          {{ s__('WorkItem|Create lifecycle') }}
        </gl-button>

        <create-lifecycle-modal
          :visible="showModal"
          :full-path="fullPath"
          @close="closeModal"
          @lifecycle-created="() => {}"
        />
      </div>
    </template>
  </div>
</template>
