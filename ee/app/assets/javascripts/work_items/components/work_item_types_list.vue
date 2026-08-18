<script>
import {
  GlDisclosureDropdown,
  GlButton,
  GlLoadingIcon,
  GlDisclosureDropdownItem,
  GlBadge,
  GlTooltipDirective,
  GlButtonGroup,
  GlAlert,
  GlIcon,
  GlDropdownDivider,
  GlToastMixin,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import CreateEditWorkItemTypeForm from 'ee/work_items/components/create_edit_work_item_type_form.vue';
import organisationWorkItemTypesQuery from 'ee/work_items/graphql/organization_work_item_types.query.graphql';
import ArchiveWorkItemTypeModal from 'ee/work_items/components/archive_work_item_type_modal.vue';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import workItemTypeIconDefinitionsQuery from 'ee/work_items/graphql/work_item_type_icon_definitions.query.graphql';
import workItemTypeUpdateMutation from 'ee/work_items/graphql/update_work_item_type.mutation.graphql';
import workItemTypeAvailabilityToggleMutation from 'ee/work_items/graphql/work_item_type_availability_toggle.graphql';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';
import { ACTIVE_TYPES_LIMIT, WARNING_THRESHOLD } from 'ee/work_items/constants';
import { s__, sprintf } from '~/locale';

export default {
  name: 'WorkItemTypesList',
  components: {
    CrudComponent,
    GlDisclosureDropdown,
    GlButton,
    WorkItemTypeIcon,
    GlLoadingIcon,
    CreateEditWorkItemTypeForm,
    GlDisclosureDropdownItem,
    GlBadge,
    GlButtonGroup,
    GlAlert,
    GlIcon,
    ArchiveWorkItemTypeModal,
    GlDropdownDivider,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  props: {
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
    config: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      workItemTypes: [],
      workItemTypeIcons: [],
      workItemSettings: null,
      errorMessage: '',
      createEditWorkItemTypeFormVisible: false,
      selectedWorkItemType: null,
      showArchived: false,
      workItemTypeToArchive: null,
    };
  },
  apollo: {
    workItemSettings: {
      query() {
        return this.fullPath ? namespaceWorkItemSettingsQuery : orgWorkItemSettingsQuery;
      },
      variables() {
        return this.fullPath ? { fullPath: this.fullPath } : {};
      },
      update(data) {
        if (!data) return this.workItemSettings;
        const settings = this.fullPath
          ? data?.namespace?.workItemSettings
          : data?.organization?.workItemSettings;
        return settings || this.workItemSettings;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
    workItemTypes: {
      query() {
        return this.fullPath ? workItemTypesConfigurationQuery : organisationWorkItemTypesQuery;
      },
      variables() {
        if (!this.fullPath) {
          return {};
        }
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return this.fullPath
          ? data.namespace?.workItemTypes?.nodes
          : data.organization?.workItemTypes?.nodes;
      },
      error(error) {
        this.errorMessage = s__('WorkItem|Failed to fetch work item types.');
        Sentry.captureException(error);
      },
    },
    workItemTypeIcons: {
      query: workItemTypeIconDefinitionsQuery,
      update(data) {
        return data.workItemTypeIconDefinitions;
      },
      error(error) {
        this.errorMessage = s__('WorkItem|Failed to fetch work item type icons.');
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      // We're doing an explicit length check to prevent re-render
      // of entire types table element when archive/unarchive action
      // is performed and refetch is done from toggleArchiveStatus method.
      return this.workItemTypes.length > 0 ? false : this.$apollo.queries.workItemTypes.loading;
    },
    isWorkItemTypeIconsLoading() {
      return this.$apollo.queries.workItemTypeIcons.loading;
    },
    canCreate() {
      return this.config?.workItemTypeSettingsPermissions?.includes('create');
    },
    canEdit() {
      return this.config?.workItemTypeSettingsPermissions?.includes('edit');
    },
    canArchive() {
      return this.config?.workItemTypeSettingsPermissions?.includes('archive');
    },
    canEnable() {
      return this.config?.workItemTypeSettingsPermissions?.includes('enable');
    },
    canDisable() {
      return this.config?.workItemTypeSettingsPermissions?.includes('disable');
    },
    customizableTypeVisibility() {
      return this.workItemSettings?.customizableTypeVisibility ?? false;
    },
    hasArchivedTypes() {
      return this.workItemTypes?.some((type) => type.archived);
    },
    filteredWorkItemTypes() {
      return (this.workItemTypes || []).filter(
        (type) => Boolean(type.archived) === this.showArchived,
      );
    },
    listTitle() {
      if (this.showArchived) {
        return s__('WorkItem|Archived types');
      }

      return s__('WorkItem|Active types');
    },
    listDescription() {
      if (this.showArchived) {
        return s__(
          'WorkItem|Disabled in all groups and projects. Items created prior to archiving may remain in this type.',
        );
      }

      return '';
    },
    archiveButtonText() {
      return this.showArchived ? s__('WorkItem|Unarchive') : s__('WorkItem|Archive');
    },
    activeTypesCount() {
      return (this.workItemTypes || []).filter((type) => !type.archived).length;
    },
    isAtLimit() {
      return this.activeTypesCount >= ACTIVE_TYPES_LIMIT;
    },
    isNearLimit() {
      return this.activeTypesCount >= ACTIVE_TYPES_LIMIT * WARNING_THRESHOLD && !this.isAtLimit;
    },
    isAtLimitText() {
      return sprintf(
        s__(
          'WorkItem|Active types are limited to %{limit}. Archive one or more types to add active types.',
        ),
        { limit: ACTIVE_TYPES_LIMIT },
      );
    },
    limitTooltipText() {
      if (this.isAtLimit) {
        return '';
      }

      return sprintf(s__('WorkItem|Active types are limited to %{limit}.'), {
        limit: ACTIVE_TYPES_LIMIT,
      });
    },
    limitBadgeVariant() {
      if (this.isAtLimit) {
        return 'danger';
      }
      if (this.isNearLimit) {
        return 'warning';
      }
      return 'neutral';
    },
    isUnarchiveBlocked() {
      return this.isAtLimit;
    },
    unarchiveLimitText() {
      return sprintf(
        s__(
          "WorkItem|Cannot unarchive type. You've reached the limit of %{limit} active work item types. Archive an existing type to unarchive this one.",
        ),
        { limit: ACTIVE_TYPES_LIMIT },
      );
    },
    canCreateNewType() {
      return this.canCreate && !this.isAtLimit;
    },
    isEditMode() {
      return Boolean(this.selectedWorkItemType);
    },
  },
  methods: {
    editWorkItemType(workItemType) {
      this.selectedWorkItemType = workItemType;
      this.createEditWorkItemTypeFormVisible = true;
    },
    closeModal() {
      this.createEditWorkItemTypeFormVisible = false;
      this.selectedWorkItemType = null;
    },
    getTooltipText(item) {
      const baseMessage = s__(
        'WorkItem|This is a system type that cannot be renamed, disabled, or deleted.',
      );

      let additionalText = '';

      if (item.isServiceDesk) {
        additionalText = s__('WorkItem|Usage is controlled by the Service Desk feature.');
      } else if (item.isGroupWorkItemType) {
        additionalText = s__('WorkItem|Usage is limited to groups.');
      } else if (item.isIncidentManagement) {
        additionalText = s__('WorkItem|Usage is controlled by the Monitor feature.');
      }

      return additionalText ? `${baseMessage} ${additionalText}` : baseMessage;
    },
    showEditAction(item) {
      return this.canEdit && !item.archived;
    },
    showEnableForAllProjectsAction(item) {
      return this.customizableTypeVisibility && this.canEnable && !item.archived;
    },
    showDisableForAllProjectsAction(item) {
      return this.customizableTypeVisibility && this.canDisable && !item.archived;
    },
    showActionsDropdown(item) {
      return (
        this.showEditAction(item) ||
        this.showEnableForAllProjectsAction(item) ||
        this.showDisableForAllProjectsAction(item) ||
        this.canArchive
      );
    },
    handleFormSuccess() {
      this.$apollo.queries.workItemTypes.refetch();
      const toastMessage = this.isEditMode
        ? s__('WorkItem|Work item type updated.')
        : s__('WorkItem|Work item type created.');
      this.$toast.show(toastMessage);
      this.closeModal();
    },
    handleFormError({ message }) {
      this.errorMessage = message || s__('WorkItem|Failed to update work item type.');
    },
    handleArchiveAction(workItemType) {
      if (workItemType.archived) {
        if (this.isUnarchiveBlocked) {
          this.errorMessage = this.unarchiveLimitText;
          return;
        }
        this.toggleArchiveStatus(workItemType, false);
      } else {
        this.workItemTypeToArchive = workItemType;
      }
    },
    async toggleArchiveStatus(workItemType, archive) {
      const input = {
        id: workItemType.id,
        archive,
      };

      if (this.fullPath) {
        input.fullPath = this.fullPath;
      }

      try {
        const { data } = await this.$apollo.mutate({
          mutation: workItemTypeUpdateMutation,
          variables: { input },
        });

        const { errors } = data?.workItemTypeUpdate || {};

        if (errors?.length) {
          throw new Error(errors.join(', '));
        }

        await this.$apollo.queries.workItemTypes.refetch();
        this.showArchived = this.hasArchivedTypes;
        this.showUndoToast(workItemType, archive);
      } catch (error) {
        this.errorMessage = error.message || s__('WorkItem|Failed to update work item type.');
        Sentry.captureException(error);
      }
    },
    showUndoToast(workItemType, archived) {
      const message = archived ? s__('WorkItem|Type archived.') : s__('WorkItem|Type unarchived.');

      const { hide } = this.$toast.show(message, {
        action: {
          text: s__('WorkItem|Undo'),
          onClick: () => {
            hide();
            this.toggleArchiveStatus(workItemType, !archived);
          },
        },
      });
    },
    closeArchiveConfirmation() {
      this.workItemTypeToArchive = null;
    },
    handleArchiveSuccess({ archived, workItemType }) {
      this.$apollo.queries.workItemTypes.refetch();
      this.showUndoToast(workItemType, archived);
    },
    handleArchiveError({ message }) {
      this.errorMessage = message || s__('WorkItem|Failed to update work item type.');
    },
    async toggleWorkItemTypeAvailability(workItemType, enabled) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: workItemTypeAvailabilityToggleMutation,
          variables: {
            input: {
              workItemTypeId: workItemType.id,
              action: enabled ? 'ENABLE' : 'DISABLE',
              scope: 'ALL_CHILDREN',
              fullPath: this.fullPath,
            },
          },
        });

        const { errors } = data?.workItemAvailabilityToggle || {};

        if (errors?.length) {
          throw new Error(errors.join(', '));
        }

        await this.$apollo.queries.workItemTypes.refetch();
        const toastMessage = enabled
          ? sprintf(s__('WorkItem|%{workItemType} enabled for all projects.'), {
              workItemType: workItemType.name,
            })
          : sprintf(s__('WorkItem|%{workItemType} disabled for all projects.'), {
              workItemType: workItemType.name,
            });
        this.$toast.show(toastMessage);
      } catch (error) {
        this.errorMessage =
          error.message || s__('WorkItem|Failed to update work item type availability.');
        Sentry.captureException(error);
      }
    },
  },
  ACTIVE_TYPES_LIMIT,
};
</script>

<template>
  <div>
    <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-5" @dismiss="errorMessage = ''">
      {{ errorMessage }}
    </gl-alert>
    <archive-work-item-type-modal
      :work-item-type="workItemTypeToArchive"
      :full-path="fullPath"
      @close="closeArchiveConfirmation"
      @success="handleArchiveSuccess"
      @error="handleArchiveError"
    />
    <create-edit-work-item-type-form
      v-if="!isWorkItemTypeIconsLoading"
      :is-visible="createEditWorkItemTypeFormVisible"
      :work-item-type="selectedWorkItemType"
      :is-edit-mode="isEditMode"
      :full-path="fullPath"
      :work-item-type-icons="workItemTypeIcons"
      @close="closeModal"
      @success="handleFormSuccess"
      @error="handleFormError"
    />
    <!--
      There is a separate view for subgroup/project levels where the user cannot create/edit/archive but showing only the
      enabled and disabled types as two separate tables which will be utilising the same query response , we will require that setting here. Either we read it
      from context/ or we just add another permission or the work item settings
    -->
    <div v-if="hasArchivedTypes" class="gl-mb-3">
      <gl-button-group>
        <gl-button :selected="!showArchived" size="small" @click="showArchived = false">
          {{ s__('WorkItem|Active') }}
        </gl-button>
        <gl-button :selected="showArchived" size="small" @click="showArchived = true">
          {{ s__('WorkItem|Archived') }}
        </gl-button>
      </gl-button-group>
    </div>
    <crud-component :title="listTitle" title-tag="h3" :description="listDescription">
      <template v-if="!isLoading && !showArchived" #count>
        <gl-badge
          v-gl-tooltip
          :variant="limitBadgeVariant"
          :title="limitTooltipText"
          data-testid="active-types-limit-badge"
        >
          {{ activeTypesCount }}/{{ $options.ACTIVE_TYPES_LIMIT }}
        </gl-badge>
        <span
          v-if="isAtLimit"
          data-testid="at-limit-message"
          class="gl-text-color-subtle gl-text-base gl-font-normal"
        >
          {{ isAtLimitText }}
        </span>
      </template>
      <template v-if="!showArchived" #actions>
        <gl-button
          v-if="canCreateNewType"
          size="small"
          data-testid="new-type-button"
          @click="createEditWorkItemTypeFormVisible = true"
        >
          {{ s__('WorkItem|New type') }}
        </gl-button>
      </template>

      <gl-loading-icon v-if="isLoading" size="lg" />
      <div v-else class="-gl-my-4" data-testid="work-item-types-table">
        <!-- Table Rows -->
        <div
          v-for="item in filteredWorkItemTypes"
          :key="item.id"
          class="gl-border-b gl-flex gl-justify-between gl-gap-4 gl-border-b-subtle gl-py-4 last:gl-border-b-0"
          :data-testid="`work-item-type-row-${item.id}`"
        >
          <!-- Type Column -->
          <div class="gl-flex gl-items-center gl-gap-2">
            <work-item-type-icon
              v-if="item.name"
              :work-item-type="item.name"
              :type-icon-name="item.iconName"
              class="gl-font-semibold gl-text-default"
              icon-class="gl-flex-shrink-0 gl-mr-2"
              show-text
              icon-variant="subtle"
            />
            <gl-badge
              v-if="!item.isConfigurable"
              v-gl-tooltip
              icon="lock"
              :data-testid="`locked-icon-${item.id}`"
              :title="getTooltipText(item)"
              :aria-label="getTooltipText(item)"
              class="gl-shrink-0"
            />
          </div>

          <!-- Options Column -->

          <gl-disclosure-dropdown
            v-if="item.isConfigurable !== false && showActionsDropdown(item)"
            :toggle-id="`work-item-type-actions-${item.id}`"
            icon="ellipsis_v"
            no-caret
            text-sr-only
            :toggle-text="__('Actions')"
            category="tertiary"
          >
            <gl-disclosure-dropdown-item
              v-if="showEditAction(item)"
              @action="editWorkItemType(item)"
            >
              <template #list-item>
                <div class="gl-align-items-center gl-flex gl-gap-3">
                  <gl-icon name="pencil" />
                  <span>{{ s__('WorkItem|Edit name and icon') }}</span>
                </div>
              </template>
            </gl-disclosure-dropdown-item>

            <gl-dropdown-divider
              v-if="showEditAction(item) && showEnableForAllProjectsAction(item)"
            />

            <gl-disclosure-dropdown-item
              v-if="showEnableForAllProjectsAction(item)"
              :data-testid="`enable-for-all-projects-action-${item.id}`"
              @action="toggleWorkItemTypeAvailability(item, true)"
            >
              <template #list-item>
                {{ s__('WorkItem|Enable for all projects') }}
              </template>
            </gl-disclosure-dropdown-item>

            <gl-disclosure-dropdown-item
              v-if="showDisableForAllProjectsAction(item)"
              :data-testid="`disable-for-all-projects-action-${item.id}`"
              @action="toggleWorkItemTypeAvailability(item, false)"
            >
              <template #list-item>
                {{ s__('WorkItem|Disable for all projects') }}
              </template>
            </gl-disclosure-dropdown-item>

            <gl-dropdown-divider v-if="showDisableForAllProjectsAction(item) && canArchive" />

            <gl-disclosure-dropdown-item
              v-if="canArchive"
              variant="default"
              :data-testid="`archive-action-${item.id}`"
              @action="handleArchiveAction(item)"
            >
              <template #list-item>
                <div class="gl-align-items-center gl-flex gl-gap-3">
                  <gl-icon name="archive" />
                  <span>{{ archiveButtonText }}</span>
                </div>
              </template>
            </gl-disclosure-dropdown-item>
          </gl-disclosure-dropdown>
        </div>
      </div>
    </crud-component>
  </div>
</template>
