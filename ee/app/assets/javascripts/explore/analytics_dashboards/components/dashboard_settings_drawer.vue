<script>
import { GlDrawer, GlButton } from '@gitlab/ui';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import DashboardDeleteModal from 'ee/vue_shared/components/dashboards_list/dashboard_delete_modal.vue';
import DashboardSettingsForm from './dashboard_settings_form.vue';

export default {
  name: 'DashboardSettingsDrawer',
  components: {
    GlDrawer,
    GlButton,
    DashboardDeleteModal,
    DashboardSettingsForm,
  },
  inject: ['exploreAnalyticsDashboardsPath'],
  props: {
    open: {
      type: Boolean,
      required: true,
    },
    dashboardConfig: {
      type: Object,
      required: true,
    },
    dashboardId: {
      type: String,
      required: true,
    },
    isSaving: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close', 'save', 'update'],
  computed: {
    drawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    formData: {
      get() {
        return {
          title: this.dashboardConfig?.title || '',
          description: this.dashboardConfig?.description || '',
        };
      },
      set({ title, description }) {
        this.$emit('update', {
          ...this.dashboardConfig,
          title,
          description,
        });
      },
    },
  },
  methods: {
    showDeleteModal() {
      this.$refs.deleteModal.show();
    },
    handleDeleteSuccess() {
      visitUrl(this.exploreAnalyticsDashboardsPath);
    },
  },
  DRAWER_Z_INDEX,
};
</script>
<template>
  <div>
    <gl-drawer
      :open="open"
      :header-height="drawerHeaderHeight"
      :z-index="$options.DRAWER_Z_INDEX"
      variant="sidebar"
      class="!gl-w-full !gl-max-w-xl"
      data-testid="dashboard-settings-drawer"
      @close="$emit('close')"
    >
      <template #title>
        <h4 class="gl-m-0">{{ s__('AnalyticsDashboards|Dashboard settings') }}</h4>
      </template>

      <template #default>
        <dashboard-settings-form v-model="formData" :is-loading="isSaving" />
      </template>

      <template #footer>
        <div class="gl-flex gl-w-full gl-items-center gl-gap-3">
          <gl-button
            variant="confirm"
            :loading="isSaving"
            data-testid="settings-save-button"
            @click="$emit('save')"
          >
            {{ s__('AnalyticsDashboards|Save') }}
          </gl-button>
          <gl-button
            :disabled="isSaving"
            data-testid="settings-cancel-button"
            @click="$emit('close')"
            >{{ s__('AnalyticsDashboards|Cancel') }}</gl-button
          >
          <gl-button
            class="gl-ml-auto"
            variant="danger"
            category="secondary"
            :disabled="isSaving"
            data-testid="settings-delete-button"
            @click="showDeleteModal"
          >
            {{ s__('AnalyticsDashboards|Delete dashboard') }}
          </gl-button>
        </div>
      </template>
    </gl-drawer>

    <dashboard-delete-modal
      ref="deleteModal"
      :dashboard-id="dashboardId"
      data-testid="settings-delete-modal"
      @delete="handleDeleteSuccess"
    />
  </div>
</template>
