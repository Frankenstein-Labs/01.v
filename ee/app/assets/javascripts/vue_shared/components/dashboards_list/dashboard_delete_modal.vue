<script>
import { GlModal, GlAlert } from '@gitlab/ui';
import { __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import deleteCustomDashboardMutation from './delete_custom_dashboard.mutation.graphql';

export default {
  name: 'DashboardDeleteModal',
  components: {
    GlModal,
    GlAlert,
  },
  props: {
    dashboardId: {
      type: String,
      required: true,
    },
  },
  emits: ['delete'],
  data() {
    return {
      isDeleting: false,
      errorMessage: '',
    };
  },
  computed: {
    actionPrimary() {
      return {
        text: __('Delete'),
        attributes: {
          variant: 'danger',
          loading: this.isDeleting,
        },
      };
    },
    actionCancel() {
      return {
        text: __('Cancel'),
        attributes: {
          disabled: this.isDeleting,
        },
      };
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Used externally to show the modal
    show() {
      this.$refs.modal.show();
      this.errorMessage = '';
      this.isDeleting = false;
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used externally to hide the modal
    hide() {
      this.$refs.modal.hide();
    },
    async deleteDashboard() {
      this.isDeleting = true;
      this.errorMessage = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteCustomDashboardMutation,
          variables: {
            id: this.dashboardId,
          },
          update: (cache) => {
            const cacheId = cache.identify({
              id: this.dashboardId,
              __typename: 'CustomDashboard',
            });
            cache.evict({ id: cacheId });
          },
        });

        const { errors } = data?.deleteCustomDashboard || {};
        if (errors?.length) {
          this.isDeleting = false;
          [this.errorMessage] = errors;
          return;
        }

        this.$emit('delete');
      } catch (error) {
        this.isDeleting = false;
        this.errorMessage = error.message;
        Sentry.captureException(error);
      }
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    size="sm"
    modal-id="dashboard-delete-modal"
    :title="s__('AnalyticsDashboards|Delete dashboard')"
    :action-primary="actionPrimary"
    :action-cancel="actionCancel"
    @primary.prevent="deleteDashboard"
  >
    <gl-alert v-if="errorMessage" class="gl-mb-4" variant="danger" @dismiss="errorMessage = ''">
      {{ errorMessage }}
    </gl-alert>
    <p>
      {{ s__('AnalyticsDashboards|Are you sure you want to permanently delete this dashboard?') }}
    </p>
  </gl-modal>
</template>
