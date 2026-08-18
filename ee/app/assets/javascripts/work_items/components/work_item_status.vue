<script>
import { GlIcon, GlButton } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { s__, __, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { I18N_WORK_ITEM_ERROR_UPDATING, WIDGET_TYPE_STATUS } from '~/work_items/constants';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import groupWorkspacePermissionsQuery from '~/work_items/graphql/group_workspace_permissions.query.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { findStatusWidget, newWorkItemId, newWorkItemFullPath } from '~/work_items/utils';
import WorkItemStatusBadge from './shared/work_item_status_badge.vue';

export default {
  name: 'WorkItemStatus',
  i18n: {
    status: __('Status'),
    statusPlaceholder: __('No status'),
    none: __('None'),
  },
  components: {
    GlIcon,
    WorkItemStatusBadge,
    WorkItemSidebarDropdownWidget,
    GlButton,
  },
  mixins: [InternalEvents.mixin(), glFeatureFlagsMixin()],
  inject: ['issuesSettings'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['error', 'statusUpdated', 'update-widget-draft'],
  data() {
    return {
      workItem: {},
      workItemTypes: [],
      searchTerm: '',
      shouldFetch: false,
      updateInProgress: false,
      localStatus: {},
      workspacePermissions: {},
    };
  },
  computed: {
    workItemStatus() {
      return findStatusWidget(this.workItem);
    },
    workItemFullPath() {
      return this.createFlow
        ? newWorkItemFullPath(this.fullPath, this.workItemType)
        : this.fullPath;
    },
    hasStatus() {
      return Boolean(this.localStatus?.id);
    },
    noStatusDefaultText() {
      return this.canUpdate ? this.$options.i18n.statusPlaceholder : this.$options.i18n.none;
    },
    dropdownText() {
      return this.localStatus?.id ? this.localStatus?.name : this.noStatusDefaultText;
    },
    isLoading() {
      return this.$apollo.queries.workItem.loading || this.$apollo.queries.workItemTypes.loading;
    },
    localStatusId() {
      return this.localStatus?.id;
    },
    createFlow() {
      return this.workItemId === newWorkItemId(this.workItemType);
    },
    filteredWidgetDefinitions() {
      return (
        this.workItemTypes?.find((type) => type.name === this.workItemType)?.widgetDefinitions || []
      );
    },
    statusDefinition() {
      return this.filteredWidgetDefinitions.find((item) => {
        return item.type === WIDGET_TYPE_STATUS;
      });
    },
    filteredStatuses() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.statusDefinition?.allowedStatuses, this.searchTerm, {
          key: ['name'],
        });
      }
      return this.statusDefinition?.allowedStatuses;
    },
    allowedStatuses() {
      return (
        this.filteredStatuses?.map((item) => ({
          ...item,
          text: item.name,
          value: item.id,
        })) || []
      );
    },
    adminWorkItemLifecycle() {
      return this.workspacePermissions?.adminWorkItemLifecycle;
    },
    issuesSettingsLink() {
      // null handling in case of old backend node
      return this.issuesSettings ? `${this.issuesSettings}/#js-custom-status-settings` : null;
    },
  },
  apollo: {
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
        return data?.namespace?.workItem ?? {};
      },
      result({ data }) {
        this.localStatus = findStatusWidget(data?.namespace?.workItem)?.status || {};
      },
      skip() {
        return !this.workItemIid || !this.fullPath;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
    workItemTypes: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.workItemTypes?.nodes || [];
      },
      skip() {
        return !this.shouldFetch;
      },
      error(error) {
        Sentry.captureException(error);
        this.$emit(
          'error',
          s__('WorkItem|Something went wrong when fetching status. Please try again.'),
        );
      },
    },
    workspacePermissions: {
      query: groupWorkspacePermissionsQuery,
      variables() {
        return {
          fullPath: this.fullPath.split('/')[0], // get group full path
        };
      },
      skip() {
        return this.isLoading || !this.fullPath;
      },
      update(data) {
        return data.namespace?.userPermissions ?? {};
      },
      error(error) {
        Sentry.captureException(error);
        this.$emit('error', s__('WorkItem|Something went wrong when fetching user permissions'));
      },
    },
  },
  methods: {
    getAdaptiveStatusColor,
    search(searchTerm) {
      this.searchTerm = searchTerm;
    },
    async updateWorkItemStatus(statusId) {
      this.updateInProgress = true;

      this.localStatus =
        this.statusDefinition?.allowedStatuses.find((item) => {
          return item.id === statusId;
        }) ?? {};

      try {
        if (this.createFlow) {
          this.$emit('update-widget-draft', {
            status: this.localStatus ? { ...this.localStatus } : null,
          });
          this.updateInProgress = true;
          return;
        }

        const {
          data: {
            workItemUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              statusWidget: {
                status: this.localStatus?.id || null,
              },
            },
            useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
          },
        });

        this.trackEvent('work_item_status_updated');
        this.$emit('statusUpdated', this.localStatus?.id);
        if (errors.length > 0) {
          throw new Error(errors.join('\n'));
        }
      } catch (error) {
        const msg =
          error.message ||
          sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
            workItemType: this.workItemType,
          });
        this.localStatus = this.workItemStatus.status || {};
        this.$emit('error', msg);
        Sentry.captureException(error);
      } finally {
        this.updateInProgress = false;
        this.searchTerm = '';
        this.shouldFetch = false;
      }
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    :dropdown-label="$options.i18n.status"
    :can-update="canUpdate"
    dropdown-name="status"
    :loading="isLoading"
    :list-items="allowedStatuses"
    :item-value="localStatusId"
    :update-in-progress="updateInProgress"
    :toggle-dropdown-text="dropdownText"
    :header-text="__('Select status')"
    data-testid="work-item-status"
    no-reset-button
    :show-footer="adminWorkItemLifecycle"
    @search-started="search"
    @dropdown-shown="shouldFetch = true"
    @dropdown-hidden="search('')"
    @update-value="updateWorkItemStatus"
  >
    <template #list-item="{ item }">
      <div class="gl-truncate">
        <gl-icon
          :name="item.iconName"
          :size="12"
          class="gl-mr-2"
          :style="{ color: getAdaptiveStatusColor(item.color) }"
        />
        <span>{{ item.text }}</span>
      </div>
    </template>
    <template #readonly>
      <work-item-status-badge v-if="hasStatus" :item="localStatus" class="gl-mt-2" />
    </template>
    <template #footer>
      <gl-button
        class="!gl-mt-2 !gl-justify-start"
        block
        category="tertiary"
        :href="issuesSettingsLink"
        data-testid="manage-statuses"
      >
        {{ __('Manage statuses') }}
      </gl-button>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
