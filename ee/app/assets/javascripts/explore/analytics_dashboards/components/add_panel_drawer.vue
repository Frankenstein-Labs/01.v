<script>
import { GlDrawer, GlButton, GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { wrapGlqlInVisualization, parseGlqlTitle } from '../utils';
import DataExplorer from './data_explorer.vue';

export default {
  name: 'AddPanelDrawer',
  components: {
    GlDrawer,
    GlButton,
    GlModal,
    DataExplorer,
  },
  props: {
    open: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['close', 'add-panel'],
  data() {
    return {
      query: '',
      submittedQuery: '',
      showEmptyQueryModal: false,
      showPendingChangesModal: false,
    };
  },
  computed: {
    drawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    isQueryBlank() {
      return this.query.trim() === '';
    },
    hasPendingChanges() {
      return this.query !== this.submittedQuery;
    },
  },
  methods: {
    handleAddToDashboard() {
      if (this.isQueryBlank) {
        this.showEmptyQueryModal = true;
        return;
      }

      if (this.hasPendingChanges) {
        this.showPendingChangesModal = true;
        return;
      }

      this.addPanel();
    },
    addPanel() {
      const query = this.query.trim();

      this.$emit('add-panel', {
        title: parseGlqlTitle(query),
        visualization: wrapGlqlInVisualization(query),
      });
    },
    handleClose() {
      this.showEmptyQueryModal = false;
      this.showPendingChangesModal = false;
      this.$emit('close');
    },
  },
  warningModalActionPrimary: {
    text: s__('AnalyticsDashboards|Add to dashboard'),
    attributes: { variant: 'confirm' },
  },
  warningModalActionCancel: {
    text: s__('AnalyticsDashboards|Cancel'),
  },
  DRAWER_Z_INDEX,
};
</script>
<template>
  <gl-drawer
    :open="open"
    :header-height="drawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    variant="sidebar"
    class="!gl-w-full !gl-max-w-4xl"
    data-testid="add-panel-drawer"
    @close="handleClose"
  >
    <template #title>
      <h4 class="gl-m-0">{{ s__('AnalyticsDashboards|Add panel') }}</h4>
    </template>

    <template #default>
      <data-explorer v-model="query" @submit="submittedQuery = $event" />
      <gl-modal
        modal-id="empty-query-modal"
        :visible="showEmptyQueryModal"
        :title="s__('AnalyticsDashboards|Query required')"
        :action-cancel="$options.warningModalActionCancel"
        data-testid="empty-query-modal"
        @hidden="showEmptyQueryModal = false"
      >
        {{
          s__(
            'AnalyticsDashboards|Enter and run a query to see results before adding the panel to the dashboard.',
          )
        }}
      </gl-modal>
      <gl-modal
        modal-id="pending-changes-modal"
        :visible="showPendingChangesModal"
        :title="s__('AnalyticsDashboards|Add panel with unverified changes?')"
        :action-primary="$options.warningModalActionPrimary"
        :action-cancel="$options.warningModalActionCancel"
        data-testid="pending-changes-modal"
        @primary="addPanel"
        @hidden="showPendingChangesModal = false"
      >
        {{
          s__(
            "AnalyticsDashboards|You haven't run the updated query. The panel will use the current query text, which may differ from the preview.",
          )
        }}
      </gl-modal>
    </template>

    <template #footer>
      <div class="gl-flex gl-w-full gl-items-center gl-gap-3">
        <gl-button
          variant="confirm"
          data-testid="add-to-dashboard-button"
          @click="handleAddToDashboard"
        >
          {{ s__('AnalyticsDashboards|Add to dashboard') }}
        </gl-button>
        <gl-button data-testid="add-panel-cancel-button" @click="handleClose">
          {{ s__('AnalyticsDashboards|Cancel') }}
        </gl-button>
      </div>
    </template>
  </gl-drawer>
</template>
