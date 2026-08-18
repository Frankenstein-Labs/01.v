<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import { uniqBy } from 'lodash-es';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import StatusModal from './status_modal.vue';
import CreateLifecycleModal from './create_lifecycle_modal.vue';
import LifecycleDetail from './lifecycle_detail.vue';
import namespaceLifecyclesQuery from './graphql/namespace_lifecycles.query.graphql';

export default {
  name: 'CustomStatusSettings',
  components: {
    GlAlert,
    GlButton,
    StatusModal,
    HelpPageLink,
    CreateLifecycleModal,
    LifecycleDetail,
    SettingsBlock,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    id: {
      type: String,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggle-expand'],
  data() {
    return {
      lifecycles: [],
      errorText: '',
      errorDetail: '',
      selectedLifecycleId: null,
      showCreateLifecycleModal: false,
      statusesUpdated: false,
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
        return data.namespace?.lifecycles?.nodes || [];
      },
      result() {
        this.statusesUpdated = false;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load lifecycles.');
        this.errorDetail = error.message;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    selectedLifecycle() {
      return this.lifecycles.find((lifecycle) => lifecycle.id === this.selectedLifecycleId);
    },
    loadingLifecycles() {
      return !this.statusesUpdated && this.$apollo.queries.lifecycles.loading;
    },
    allNamespaceStatuses() {
      const allStatuses = this.lifecycles.flatMap((lifecycle) => lifecycle.statuses);
      return uniqBy(allStatuses, 'id');
    },
  },
  methods: {
    dismissAlert() {
      this.errorText = '';
      this.errorDetail = '';
    },
    openStatusModal(lifecycleId) {
      this.selectedLifecycleId = lifecycleId;
    },
    closeModal() {
      this.selectedLifecycleId = null;
    },
    handleLifecycleUpdate() {
      this.$apollo.queries.lifecycles.refetch();
    },
    handleLifecycleStatusesUpdated() {
      this.statusesUpdated = true;
      this.handleLifecycleUpdate();
    },
    closeCreateLifecycleModal() {
      this.showCreateLifecycleModal = false;
    },
    handleLifecycleCreate(newLifecycleId) {
      this.handleLifecycleUpdate();
      this.openStatusModal(newLifecycleId);
    },
  },
};
</script>

<template>
  <settings-block
    :id="id"
    :expanded="expanded"
    :title="s__('WorkItem|Statuses')"
    @toggle-expand="$emit('toggle-expand', $event)"
  >
    <template #description>
      <p>
        {{
          s__(
            'WorkItem|Statuses are used to manage workflow of planning items, helping you and your team understand how far an item has progressed.',
          )
        }}
        <help-page-link
          data-testid="settings-help-page-link"
          href="user/work_items/status"
          target="_blank"
        >
          {{ s__('WorkItems|How do I use statuses?') }}
        </help-page-link>
      </p>
    </template>
    <template #default>
      <gl-alert
        v-if="errorText"
        variant="danger"
        :dismissible="true"
        class="gl-mb-5"
        data-testid="alert"
        @dismiss="dismissAlert"
      >
        {{ errorText }}
        <details>
          {{ errorDetail }}
        </details>
      </gl-alert>

      <div
        v-if="loadingLifecycles"
        data-testid="lifecycle-loading-skeleton"
        class="gl-flex gl-flex-col gl-gap-4"
      >
        <div
          v-for="i in 4"
          :key="i"
          class="gl-border gl-rounded-lg gl-bg-white gl-px-4 gl-py-4 gl-pt-4"
        >
          <div
            class="gl-animate-skeleton-loader gl-my-3 gl-h-4 gl-max-w-[20%] gl-rounded-base"
          ></div>
          <div class="gl-mt-3 gl-flex gl-h-4 gl-gap-3">
            <div
              v-for="j in 5"
              :key="j"
              class="gl-animate-skeleton-loader gl-mb-7 gl-h-4 gl-w-[75px] gl-rounded-lg"
            ></div>
          </div>
        </div>
      </div>

      <div v-else>
        <section
          data-testid="more-lifecycle-information"
          class="gl-mb-4 gl-flex gl-flex-wrap gl-items-center gl-justify-between"
        >
          <div>
            <h3 class="gl-mb-2 gl-mt-0 gl-text-base">{{ s__('WorkItem|Lifecycles') }}</h3>
            <p class="gl-mb-0 gl-text-subtle">
              {{
                s__(
                  'WorkItem|Lifecycles contain statuses that are used together as an item is worked on. Each item type uses a single lifecycle.',
                )
              }}
            </p>
          </div>
          <gl-button data-testid="create-lifecycle" @click="showCreateLifecycleModal = true">{{
            s__('WorkItem|Create lifecycle')
          }}</gl-button>
        </section>

        <div class="gl-flex gl-flex-col gl-gap-4">
          <lifecycle-detail
            v-for="lifecycle in lifecycles"
            :key="lifecycle.id"
            :lifecycle="lifecycle"
            :full-path="fullPath"
            show-usage-section
            show-not-in-use-section
            @deleted="handleLifecycleUpdate"
          >
            <template #detail-footer>
              <gl-button data-testid="edit-statuses" @click="openStatusModal(lifecycle.id)">{{
                s__('WorkItem|Edit statuses')
              }}</gl-button>
            </template>
          </lifecycle-detail>
        </div>
      </div>

      <status-modal
        v-if="selectedLifecycle"
        :visible="Boolean(selectedLifecycleId)"
        :lifecycle="selectedLifecycle"
        :full-path="fullPath"
        :statuses="allNamespaceStatuses"
        @close="closeModal"
        @lifecycle-updated="handleLifecycleStatusesUpdated"
      />

      <create-lifecycle-modal
        :visible="showCreateLifecycleModal"
        :full-path="fullPath"
        @close="closeCreateLifecycleModal"
        @lifecycle-created="handleLifecycleCreate"
      />
    </template>
  </settings-block>
</template>
