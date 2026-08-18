<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import IssueHealthStatus from 'ee/issues/components/issue_health_status.vue';
import {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS,
  healthStatusDropdownOptions,
} from 'ee/sidebar/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  i18n,
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
  VIEW_CONTEXT,
} from '~/work_items/constants';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { newWorkItemId, newWorkItemFullPath, findHealthStatusWidget } from '~/work_items/utils';
import Tracking from '~/tracking';
import { sprintf } from '~/locale';

export default {
  name: 'WorkItemHealthStatus',
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS,
  healthStatusDropdownOptions,
  components: {
    IssueHealthStatus,
    WorkItemSidebarDropdownWidget,
  },
  mixins: [Tracking.mixin(), glFeatureFlagsMixin()],
  inject: {
    viewContext: { default: VIEW_CONTEXT.fullScreen },
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    isWorkItemClosed: {
      type: Boolean,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  emits: ['error', 'update-widget-draft'],
  data() {
    return {
      updateInProgress: false,
    };
  },
  computed: {
    // eslint-disable-next-line vue/no-unused-properties
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: `type_${this.workItemType}`,
        extra: { viewContext: this.viewContext },
      };
    },
    selectedHealthStatus() {
      return this.healthStatus || null;
    },
    healthStatus() {
      return findHealthStatusWidget(this.workItem)?.healthStatus;
    },
    createFlow() {
      return this.workItemId === newWorkItemId(this.workItemType);
    },
    workItemFullPath() {
      return this.createFlow
        ? newWorkItemFullPath(this.fullPath, this.workItemType)
        : this.fullPath;
    },
    canUpdateMetadata() {
      return this.workItem?.userPermissions?.setWorkItemMetadata && !this.isWorkItemClosed;
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    workItem: {
      query: workItemByIidQuery,
      variables() {
        return {
          fullPath: this.workItemFullPath,
          iid: this.workItemIid,
          useWorkItemFeatures: Boolean(this.glFeatures.workItemFeaturesField),
        };
      },
      update(data) {
        return data.namespace?.workItem || {};
      },
      skip() {
        return !this.workItemIid;
      },
      error() {
        this.$emit('error', i18n.fetchError);
      },
    },
  },
  methods: {
    updateHealthStatus(healthStatus) {
      if (!this.canUpdateMetadata) {
        return;
      }

      this.track('updated_health_status');

      this.updateInProgress = true;

      if (this.createFlow) {
        this.$emit('update-widget-draft', { healthStatus });
        this.updateInProgress = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              healthStatusWidget: {
                healthStatus,
              },
            },
            useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          const msg = sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
            workItemType: this.workItemType,
          });
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    :dropdown-label="$options.HEALTH_STATUS_I18N_HEALTH_STATUS"
    :can-update="canUpdateMetadata"
    dropdown-name="health-status"
    :list-items="$options.healthStatusDropdownOptions"
    :item-value="selectedHealthStatus"
    :header-text="$options.HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS"
    :update-in-progress="updateInProgress"
    :reset-button-label="__('Clear')"
    :searchable="false"
    data-testid="work-item-health-status"
    @update-value="updateHealthStatus"
  >
    <template #readonly>
      <issue-health-status
        v-if="selectedHealthStatus"
        data-testid="work-item-health-status-value"
        display-as-text
        disable-tooltip
        :health-status="selectedHealthStatus"
      />
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
