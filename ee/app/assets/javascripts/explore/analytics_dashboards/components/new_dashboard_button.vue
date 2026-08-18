<script>
import { GlButton, GlModal, GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import { visitUrl, joinPaths } from '~/lib/utils/url_utility';
import { getDashboardIdFromGraphQLId } from '~/explore/analytics_dashboards/utils';
import { EDIT_DASHBOARD_PATH } from 'ee/vue_shared/components/dashboards_list/constants';
import createCustomDashboardMutation from '../graphql/create_custom_dashboard.mutation.graphql';
import DashboardSettingsForm from './dashboard_settings_form.vue';

export default {
  name: 'NewDashboardButton',
  components: {
    GlButton,
    GlModal,
    GlAlert,
    DashboardSettingsForm,
  },
  inject: ['exploreAnalyticsDashboardsPath'],
  data() {
    return {
      showModal: false,
      isLoading: false,
      formData: {
        title: '',
        description: '',
      },
      errorMessage: '',
    };
  },
  computed: {
    modalActionPrimary() {
      return {
        text: s__('AnalyticsDashboards|Next'),
        attributes: { variant: 'confirm', loading: this.isLoading },
      };
    },
    modalActionCancel() {
      return {
        text: s__('AnalyticsDashboards|Cancel'),
        attributes: { disabled: this.isLoading },
      };
    },
  },
  methods: {
    openModal() {
      this.showModal = true;
      this.formData = {
        title: '',
        description: '',
      };
      this.clearError();
    },
    closeModal() {
      this.showModal = false;
    },
    clearError() {
      this.errorMessage = '';
    },
    async handlePrimary() {
      this.clearError();

      const title = this.formData.title.trim();
      const description = this.formData.description.trim();
      if (!title) {
        this.errorMessage = s__('AnalyticsDashboards|Dashboard title is required.');
        return;
      }

      this.isLoading = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createCustomDashboardMutation,
          variables: {
            input: {
              name: title,
              description,
              config: {
                title,
                description,
                panels: [],
              },
            },
          },
        });

        const { dashboard, errors } = data?.createCustomDashboard || {};
        if (errors?.length) {
          [this.errorMessage] = errors;
          this.isLoading = false;
          return;
        }

        const dashboardId = getDashboardIdFromGraphQLId(dashboard.id);

        visitUrl(
          joinPaths(this.exploreAnalyticsDashboardsPath, String(dashboardId), EDIT_DASHBOARD_PATH),
        );
      } catch (error) {
        this.errorMessage = s__(
          'AnalyticsDashboards|Failed to create dashboard. Please try again.',
        );
        this.isLoading = false;
      }
    },
  },
  buttonLabel: s__('AnalyticsDashboards|New dashboard'),
};
</script>

<template>
  <div>
    <gl-button variant="confirm" @click="openModal">
      {{ $options.buttonLabel }}
    </gl-button>
    <gl-modal
      v-model="showModal"
      modal-id="new-dashboard-modal"
      size="sm"
      :title="$options.buttonLabel"
      :action-primary="modalActionPrimary"
      :action-cancel="modalActionCancel"
      @primary.prevent="handlePrimary"
      @canceled="closeModal"
    >
      <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-4" @dismiss="clearError">
        {{ errorMessage }}
      </gl-alert>
      <dashboard-settings-form v-model="formData" :is-loading="isLoading" />
    </gl-modal>
  </div>
</template>
