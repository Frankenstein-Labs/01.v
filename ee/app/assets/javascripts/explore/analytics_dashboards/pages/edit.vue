<script>
import { GlDashboardLayout, GlButton, GlEmptyState, GlAlert, GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import DashboardLoader from '~/explore/analytics_dashboards/components/dashboard_loader.vue';
import AnalyticsDashboardPanel from '~/analytics/shared/components/analytics_dashboard_panel.vue';
import { wrapVisualizationInPanel, serializePanelsForMutation } from '../utils';
import updateCustomDashboardMutation from '../graphql/update_custom_dashboard.mutation.graphql';
import DashboardSettingsDrawer from '../components/dashboard_settings_drawer.vue';
import AddPanelDrawer from '../components/add_panel_drawer.vue';

export default {
  name: 'ExploreAnalyticsDashboardEdit',
  components: {
    GlDashboardLayout,
    GlButton,
    GlEmptyState,
    GlAlert,
    DashboardLoader,
    AnalyticsDashboardPanel,
    DashboardSettingsDrawer,
    AddPanelDrawer,
  },
  mixins: [GlToastMixin],
  data() {
    return {
      dashboard: null,
      isSettingsDrawerOpen: false,
      isAddPanelDrawerOpen: false,
      isSaving: false,
      saveErrorMessage: '',
    };
  },
  computed: {
    config() {
      return this.dashboard?.config || {};
    },
    panels() {
      return this.config?.panels || [];
    },
    hasPanels() {
      return Boolean(this.panels?.length);
    },
  },
  methods: {
    onDashboardLoaded(dashboard) {
      this.dashboard = dashboard;
    },
    openSettingsDrawer() {
      this.isAddPanelDrawerOpen = false;
      this.isSettingsDrawerOpen = true;
    },
    closeSettingsDrawer() {
      this.isSettingsDrawerOpen = false;
    },
    openAddPanelDrawer() {
      this.isSettingsDrawerOpen = false;
      this.isAddPanelDrawerOpen = true;
    },
    closeAddPanelDrawer() {
      this.isAddPanelDrawerOpen = false;
    },
    addPanel({ title, visualization }) {
      // Make sure panels is defined
      if (!this.dashboard.config.panels) this.dashboard.config.panels = [];

      this.dashboard.config.panels.push(wrapVisualizationInPanel(visualization, title));
      this.closeAddPanelDrawer();
    },
    onLayoutChange({ panels }) {
      this.dashboard.config.panels = panels;
    },
    updateDashboardConfig(config) {
      this.dashboard.config = config;
    },
    clearSaveError() {
      this.saveErrorMessage = '';
    },
    async saveDashboard(dashboardId) {
      this.clearSaveError();

      const title = (this.config.title || '').trim();
      const description = (this.config.description || '').trim();
      if (!title) {
        this.saveErrorMessage = s__('AnalyticsDashboards|Dashboard title is required.');
        return;
      }

      this.isSaving = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateCustomDashboardMutation,
          variables: {
            input: {
              id: dashboardId,
              name: title,
              description,
              config: {
                title,
                description,
                panels: serializePanelsForMutation(this.panels),
              },
            },
          },
          update: (cache) => {
            const cacheId = cache.identify({
              id: dashboardId,
              __typename: 'CustomDashboard',
            });
            cache.evict({ id: cacheId });
          },
        });

        const { errors } = data?.updateCustomDashboard || {};
        if (errors?.length) {
          [this.saveErrorMessage] = errors;
        } else {
          this.closeSettingsDrawer();
          this.$toast.show(s__('AnalyticsDashboards|Dashboard saved.'));
        }
      } catch (error) {
        this.saveErrorMessage = s__(
          'AnalyticsDashboards|Failed to update dashboard. Please try again.',
        );
      } finally {
        this.isSaving = false;
      }
    },
  },
  i18n: {
    addPanel: s__('AnalyticsDashboards|Add panel'),
  },
};
</script>
<template>
  <dashboard-loader @loaded="onDashboardLoaded">
    <template #dashboard="{ dashboardId, cellHeight, minCellHeight }">
      <gl-alert
        v-if="saveErrorMessage"
        variant="danger"
        class="gl-mb-4"
        data-testid="dashboard-save-error"
        @dismiss="clearSaveError"
      >
        {{ saveErrorMessage }}
      </gl-alert>
      <gl-dashboard-layout
        :config="config"
        :cell-height="cellHeight"
        :min-cell-height="minCellHeight"
        :is-static-grid="false"
        @changed="onLayoutChange"
      >
        <template #actions>
          <div class="gl-mb-3 gl-text-right">
            <gl-button
              icon="settings"
              :aria-label="s__('AnalyticsDashboards|Settings')"
              data-testid="dashboard-settings-button"
              @click="openSettingsDrawer"
            />
          </div>
          <div class="gl-flex gl-gap-2">
            <gl-button
              icon="plus"
              data-testid="dashboard-add-panel-button"
              @click="openAddPanelDrawer"
              >{{ $options.i18n.addPanel }}</gl-button
            >
            <gl-button
              variant="confirm"
              :loading="isSaving"
              data-testid="dashboard-save-button"
              @click="saveDashboard(dashboardId)"
              >{{ s__('AnalyticsDashboards|Save') }}</gl-button
            >
          </div>
        </template>

        <template #panel="{ panel: { title, tooltip, visualization, queryOverrides } }">
          <analytics-dashboard-panel
            :title="title"
            :tooltip="tooltip"
            :visualization="visualization"
            :query-overrides="queryOverrides"
          />
        </template>

        <template #empty-state>
          <div
            v-if="!hasPanels"
            class="gl-border gl-w-full gl-rounded-base gl-border-dashed gl-py-13"
          >
            <gl-empty-state
              :title="s__('AnalyticsDashboards|Start building your dashboard')"
              :description="
                s__(
                  'AnalyticsDashboards|Add panels to this dashboard to visualize your analytics data.',
                )
              "
              illustration-name="empty-epic-md"
            >
              <template #actions>
                <gl-button
                  variant="confirm"
                  icon="plus"
                  data-testid="empty-state-add-panel-button"
                  @click="openAddPanelDrawer"
                  >{{ $options.i18n.addPanel }}</gl-button
                >
              </template>
            </gl-empty-state>
          </div>
        </template>
      </gl-dashboard-layout>

      <dashboard-settings-drawer
        :dashboard-id="dashboardId"
        :dashboard-config="config"
        :open="isSettingsDrawerOpen"
        :is-saving="isSaving"
        @update="updateDashboardConfig"
        @save="saveDashboard(dashboardId)"
        @close="closeSettingsDrawer"
      />

      <add-panel-drawer
        :open="isAddPanelDrawerOpen"
        @add-panel="addPanel"
        @close="closeAddPanelDrawer"
      />
    </template>
  </dashboard-loader>
</template>
