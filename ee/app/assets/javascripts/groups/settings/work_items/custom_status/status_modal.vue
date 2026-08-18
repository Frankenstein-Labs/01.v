<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlModal,
  GlLoadingIcon,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import VueDraggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import { createListFormat, s__, sprintf } from '~/locale';
import { getAdaptiveStatusColor, validateHexColor } from '~/lib/utils/color_utils';
import { STATUS_CATEGORIES, STATUS_CATEGORIES_MAP } from 'ee/work_items/constants';
import { getDefaultStateType } from 'ee/work_items/utils';
import { STATE_CLOSED } from '~/work_items/constants';
import WorkItemStateBadge from '~/work_items/components/work_item_state_badge.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import lifecycleUpdateMutation from './graphql/lifecycle_update.mutation.graphql';
import StatusForm from './status_form.vue';
import RemoveStatusModal from './remove_status_modal.vue';
import namespaceMetadataQuery from './graphql/namespace_metadata.query.graphql';

const CATEGORY_ORDER = Object.keys(STATUS_CATEGORIES_MAP);

const STATUS_MAX_LIMIT = 30;

export default {
  name: 'StatusModal',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlModal,
    GlLoadingIcon,
    GlSprintf,
    RemoveStatusModal,
    StatusForm,
    VueDraggable,
    GlLink,
    HelpPageLink,
    WorkItemStateBadge,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    lifecycle: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
  },
  emits: ['close', 'lifecycle-updated'],
  data() {
    return {
      loading: false,
      errorMessage: '',
      editingStatusId: null,
      addingToCategory: null,
      removingStatusName: '',
      formData: {
        name: '',
        color: '',
        description: '',
      },
      formErrors: {
        name: null,
        color: null,
      },
      namespaceMetadata: null,
      statusToRemove: null,
    };
  },
  apollo: {
    namespaceMetadata: {
      query: namespaceMetadataQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to fetch namespace metadata.');
        this.errorDetail = error.message;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    modalTitle() {
      return s__('WorkItem|Edit statuses');
    },
    statusesByCategory() {
      const grouped = {};
      CATEGORY_ORDER.forEach((category) => {
        grouped[category] = [];
      });

      this.lifecycle.statuses?.forEach((status) => {
        const category = this.getCategoryFromIconName(status.iconName);
        if (grouped[category]) {
          grouped[category].push(status);
        }
      });

      return grouped;
    },
    isEditing() {
      return Boolean(this.editingStatusId);
    },
    groupWorkItemsPath() {
      return this.namespaceMetadata?.linkPaths?.groupIssues;
    },
    groupWorkItemsPathWithStatusFilter() {
      return `${this.groupWorkItemsPath}?status=${this.removingStatusName}`;
    },
    filteredStatusesFromCurrentLifecycle() {
      const currentLifecycleStatusNames = this.lifecycle.statuses.map((status) => status.name);
      const availableStatuses = this.statuses.filter(
        (status) => !currentLifecycleStatusNames.includes(status.name),
      );

      if (this.addingToCategory) {
        const sameCategoryStatuses = availableStatuses.filter(
          (status) => this.getCategoryFromIconName(status.iconName) === this.addingToCategory,
        );
        const otherStatuses = availableStatuses.filter(
          (status) => this.getCategoryFromIconName(status.iconName) !== this.addingToCategory,
        );
        return [...sameCategoryStatuses, ...otherStatuses];
      }
      return availableStatuses;
    },
    usageText() {
      const workItemTypes = this.lifecycle.workItemTypes.map((type) => type.name);
      return sprintf(s__('WorkItem|Usage: %{workItemTypes}.'), {
        workItemTypes: createListFormat().format(workItemTypes),
      });
    },
  },
  methods: {
    canReorderStatuses(category) {
      return this.statusesByCategory[category].length >= 2;
    },
    getCategoryFromIconName(iconName) {
      return (
        Object.keys(STATUS_CATEGORIES_MAP).find(
          (category) => STATUS_CATEGORIES_MAP[category].icon === iconName,
        ) || STATUS_CATEGORIES.TO_DO
      );
    },
    getCategoryLabel(category) {
      return STATUS_CATEGORIES_MAP[category].label || category;
    },
    getCategoryDescription(category) {
      return STATUS_CATEGORIES_MAP[category].description || '';
    },
    getCategoryDefaultState(category) {
      return STATUS_CATEGORIES_MAP[category].defaultState || '';
    },
    getCategoryWorkItemState(category) {
      return STATUS_CATEGORIES_MAP[category].workItemState || '';
    },
    getColorStyle({ color }) {
      return { color: getAdaptiveStatusColor(color) };
    },
    showWorkItemStateBadge(category) {
      return this.getCategoryWorkItemState(category) === STATE_CLOSED;
    },
    startAddingStatus(category) {
      this.cancelForm();
      this.addingToCategory = category;
      this.resetForm();
    },
    startEditingStatus(status) {
      this.cancelForm();
      this.editingStatusId = status.id;
      this.formData.name = status.name;
      this.formData.color = status.color;
      this.formData.description = status.description || '';
      this.formErrors = {
        name: null,
        color: null,
      };
    },
    startRemovingStatus(status) {
      this.statusToRemove = status;
      this.removingStatusName = status.name;
    },
    async startDefaultingStatus(status, defaultState) {
      if (!status?.id || !defaultState) {
        return;
      }

      try {
        const defaultStatus = {};

        defaultStatus[defaultState] = {
          id: status.id,
          name: status.name,
          __typename: 'WorkItemStatus',
        };
        const allStatuses = [];

        this.$options.CATEGORY_ORDER.forEach((cat) => {
          const categoryStatuses = this.statusesByCategory[cat];
          allStatuses.push(...categoryStatuses);
        });

        const statusesForUpdate = allStatuses.map((statusValue) => ({
          id: statusValue.id,
          name: statusValue.name,
          color: statusValue.color,
          category: this.getCategoryFromStatus(statusValue.id),
          description: statusValue.description,
        }));

        this.$refs[status.name][0]?.close();

        await this.updateLifecycle(
          statusesForUpdate,
          s__('WorkItem|An error occurred while making status default.'),
          defaultStatus,
        );
      } catch (error) {
        this.errorMessage = s__('WorkItem|An error occurred while making status default.');
      }
    },
    cancelForm() {
      this.resetForm();
      this.editingStatusId = null;
      this.addingToCategory = null;
    },
    resetForm() {
      const color = this.addingToCategory
        ? this.$options.STATUS_CATEGORIES_MAP[this.addingToCategory].color
        : '';

      this.formData = {
        name: '',
        color,
        description: '',
      };
      this.formErrors = {
        name: null,
        color: null,
      };
      this.errorMessage = '';
    },
    validateForm() {
      if (this.formData.name?.trim() === '') {
        this.formErrors.name = s__('WorkItem|Name is required.');
      } else if (
        this.lifecycle.statuses.find(
          (status) =>
            status.name === this.formData.name?.trim() && status.id !== this.editingStatusId,
        )
      ) {
        this.formErrors.name = s__('WorkItem|Name is already taken.');
      } else {
        this.formErrors.name = null;
      }

      if (!validateHexColor(this.formData.color)) {
        this.formErrors.color = s__('WorkItem|Must be a valid hex color.');
      } else {
        this.formErrors.color = null;
      }

      return Object.values(this.formErrors).every((error) => error === null);
    },
    async updateLifecycle(
      statuses,
      errorMessage = s__('WorkItem|An error occurred while updating the status.'),
      defaultStatus = {},
    ) {
      this.errorMessage = '';
      const { open, closed, duplicate } = defaultStatus;

      const defaultOpenStatusId = open ? open.id : this.lifecycle.defaultOpenStatus?.id;
      const defaultClosedStatusId = closed ? closed.id : this.lifecycle.defaultClosedStatus?.id;
      const defaultDuplicateStatusId = duplicate
        ? duplicate.id
        : this.lifecycle.defaultDuplicateStatus?.id;

      try {
        const defaultOpenStatusIndex = statuses.findIndex((s) => s.id === defaultOpenStatusId);
        const defaultClosedStatusIndex = statuses.findIndex((s) => s.id === defaultClosedStatusId);
        const defaultDuplicateStatusIndex = statuses.findIndex(
          (s) => s.id === defaultDuplicateStatusId,
        );

        const defaultOpenStatus = open || this.lifecycle.defaultOpenStatus;
        const defaultClosedStatus = closed || this.lifecycle.defaultClosedStatus;
        const defaultDuplicateStatus = duplicate || this.lifecycle.defaultDuplicateStatus;

        const { data } = await this.$apollo.mutate({
          mutation: lifecycleUpdateMutation,
          variables: {
            input: {
              namespacePath: this.fullPath,
              id: this.lifecycle.id,
              statuses,
              defaultOpenStatusIndex: Math.max(0, defaultOpenStatusIndex),
              defaultClosedStatusIndex: Math.max(0, defaultClosedStatusIndex),
              defaultDuplicateStatusIndex: Math.max(0, defaultDuplicateStatusIndex),
            },
          },
          optimisticResponse: {
            lifecycleUpdate: {
              lifecycle: {
                id: this.lifecycle.id,
                name: this.lifecycle.name,
                statuses: statuses.map((status) => ({
                  __typename: 'WorkItemStatus',
                  id: status.id || null,
                  name: status.name,
                  iconName: status.category
                    ? STATUS_CATEGORIES_MAP[status.category].icon
                    : 'status-waiting',
                  color: status.color,
                  description: status.description,
                })),
                defaultOpenStatus,
                defaultClosedStatus,
                defaultDuplicateStatus,
                workItemTypes: this.lifecycle.workItemTypes,
                __typename: 'WorkItemLifecycle',
              },
              errors: [],
              __typename: 'LifecycleUpdatePayload',
            },
          },
        });

        if (data?.lifecycleUpdate?.errors?.length) {
          throw new Error(data.lifecycleUpdate.errors.join(', '));
        }

        this.$emit('lifecycle-updated');
        this.cancelForm();
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = error.message || errorMessage;
        if (error.message.indexOf('because it is in use') !== -1 && this.groupWorkItemsPath) {
          this.errorMessage += '. %{linkStart}View items using status.%{linkEnd}';
        }
      }
    },
    async onStatusReorder({ oldIndex, newIndex }) {
      if (oldIndex === newIndex) {
        return;
      }

      const allStatuses = [];

      this.$options.CATEGORY_ORDER.forEach((cat) => {
        const categoryStatuses = this.statusesByCategory[cat];
        allStatuses.push(...categoryStatuses);
      });

      const statusesForUpdate = allStatuses.map((status) => ({
        id: status.id,
        name: status.name,
        color: status.color,
        category: this.getCategoryFromStatus(status.id),
        description: status.description,
      }));

      await this.updateLifecycle(
        statusesForUpdate,
        s__('WorkItem|An error occurred while reordering statuses.'),
      );
    },
    async saveStatus() {
      if (!this.validateForm()) {
        return;
      }

      const currentStatuses = this.lifecycle.statuses.map((status) => ({
        id: status.id,
        name: status.name,
        color: status.color,
        category: this.getCategoryFromStatus(status.id),
        description: status.description,
      }));

      // while adding we may also add an existing status , so we need to find
      // if that exists in allStatuses of namespace

      const addingExistingStatus = this.statuses.find(
        (status) => status.name === this.formData.name.trim(),
      );

      if (currentStatuses.length >= STATUS_MAX_LIMIT) {
        this.errorMessage = sprintf(
          s__('WorkItem|Maximum %{maxLimit} statuses reached. Remove a status to add more.'),
          {
            maxLimit: STATUS_MAX_LIMIT,
          },
        );
        return;
      }

      if (addingExistingStatus) {
        // adding an existing status from other lifecycle/namespace
        currentStatuses.push({
          id: addingExistingStatus.id,
          name: this.formData?.name?.trim(),
          color: this.formData?.color,
          description: this.formData?.description?.trim() || '',
          category: addingExistingStatus.category.toUpperCase(),
        });
      } else if (this.isEditing) {
        // editing an already added status
        const statusIndex = currentStatuses.findIndex((s) => s.id === this.editingStatusId);
        if (statusIndex !== -1) {
          currentStatuses[statusIndex] = {
            ...currentStatuses[statusIndex],
            name: this.formData.name.trim(),
            color: this.formData.color,
            description: this.formData.description.trim(),
          };
        }
      } else {
        // completely new status
        currentStatuses.push({
          name: this.formData.name.trim(),
          color: this.formData.color,
          description: this.formData.description.trim(),
          category: this.addingToCategory,
        });
      }

      await this.updateLifecycle(
        currentStatuses,
        s__('WorkItem|An error occurred while saving the status.'),
      );
    },
    getCategoryFromStatus(statusId) {
      for (const [category, statuses] of Object.entries(this.statusesByCategory)) {
        if (statuses.find((status) => status.id === statusId)) {
          return category;
        }
      }
      return STATUS_CATEGORIES.TO_DO;
    },
    isDefaultStatus(status) {
      return Boolean(getDefaultStateType(this.lifecycle, status));
    },
    getDefaultStatusType(status) {
      if (status.id === this.lifecycle.defaultOpenStatus?.id) {
        return s__('WorkItem|Open default');
      }
      if (status.id === this.lifecycle.defaultClosedStatus?.id) {
        return s__('WorkItem|Closed default');
      }
      if (status.id === this.lifecycle.defaultDuplicateStatus?.id) {
        return s__('WorkItem|Duplicate default');
      }
      return null;
    },
    getDefaultDropdownTextForStatus(defaultState) {
      return sprintf(s__('WorkItem|Make default for %{defaultState} items'), {
        defaultState,
      });
    },
    closeModal() {
      this.cancelForm();
      this.$emit('close');
    },
    dismissError() {
      this.errorMessage = '';
      this.removingStatusName = '';
    },
  },
  CATEGORY_ORDER,
  STATUS_CATEGORIES_MAP,
  sprintf,
};
</script>

<template>
  <div>
    <gl-modal
      :visible="visible"
      :title="modalTitle"
      scrollable
      modal-id="status-modal"
      @hide="closeModal"
    >
      <gl-loading-icon v-if="loading" size="lg" class="gl-my-7" />

      <template v-else>
        <div
          class="gl-border gl-mb-5 gl-rounded-lg gl-border-strong gl-bg-strong gl-p-4"
          data-testid="lifecycle-info"
        >
          <div class="gl-font-[700]">{{ s__('WorkItem|Lifecycle:') }} {{ lifecycle.name }}</div>
          <div class="gl-text-sm">
            <span v-if="lifecycle.workItemTypes.length">
              {{ usageText }}
            </span>
            <span v-else class="gl-text-subtle">
              {{ s__('WorkItem|Not used on any items.') }}
            </span>
            <help-page-link
              class="gl-text-size-reset"
              data-testid="help-page-link"
              href="user/work_items/status"
              target="_blank"
            >
              {{ s__('WorkItems|How do I use statuses?') }}
            </help-page-link>
          </div>
        </div>

        <gl-alert
          v-if="errorMessage"
          variant="danger"
          class="gl-sticky gl-top-0 gl-my-5"
          data-testid="error-alert"
          @dismiss="dismissError"
        >
          <gl-sprintf :message="errorMessage">
            <template #link="{ content }">
              <gl-link :href="groupWorkItemsPathWithStatusFilter">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </gl-alert>

        <div
          v-for="category in $options.CATEGORY_ORDER"
          :key="category"
          class="gl-mb-6"
          :data-testid="`category-${category.toLowerCase()}`"
        >
          <div class="gl-mb-2 gl-flex gl-flex-col gl-gap-1">
            <div class="gl-flex gl-items-center gl-gap-3">
              <h3 class="gl-m-0 gl-text-size-reset gl-font-bold">
                {{ getCategoryLabel(category) }}
              </h3>
              <work-item-state-badge
                v-if="showWorkItemStateBadge(category)"
                :work-item-state="getCategoryWorkItemState(category)"
                :show-icon="false"
              />
            </div>

            <p data-testid="category-description" class="!gl-mb-0 gl-text-sm gl-text-subtle">
              {{ getCategoryDescription(category) }}
            </p>
          </div>

          <div>
            <vue-draggable
              v-model="statusesByCategory[category]"
              :disabled="!canReorderStatuses(category)"
              :animation="0"
              handle=".js-drag-handle"
              ghost-class="gl-opacity-5"
              item-key="id"
              @end="onStatusReorder($event)"
            >
              <div
                v-for="status in statusesByCategory[category]"
                :key="status.id"
                class="gl-border-b"
                data-testid="status-badge"
              >
                <div
                  v-if="editingStatusId !== status.id"
                  class="gl-flex gl-items-start gl-gap-2 gl-px-3 gl-py-4"
                >
                  <gl-icon
                    name="grip"
                    :size="12"
                    class="js-drag-handle gl-mt-2 gl-flex-none"
                    :class="{
                      'gl-cursor-grabbing': false,
                      'gl-cursor-grab': canReorderStatuses(category),
                    }"
                    data-testid="drag-handle"
                  />
                  <gl-icon
                    :size="12"
                    :name="status.iconName"
                    :style="getColorStyle(status)"
                    class="gl-mr-1 gl-mt-2 gl-flex-none"
                  />
                  <div>
                    <span>{{ status.name }}</span>
                    <gl-badge
                      v-if="isDefaultStatus(status)"
                      size="sm"
                      class="gl-ml-2"
                      data-testid="default-status-badge"
                    >
                      {{ getDefaultStatusType(status) }}
                    </gl-badge>
                    <div v-if="status.description" class="gl-mt-2 gl-text-subtle">
                      {{ status.description }}
                    </div>
                  </div>
                  <gl-disclosure-dropdown
                    :ref="status.name"
                    class="gl-ml-auto"
                    text-sr-only
                    :toggle-text="__('More actions')"
                    no-caret
                    category="tertiary"
                    icon="ellipsis_v"
                    placement="bottom-end"
                    size="small"
                  >
                    <gl-disclosure-dropdown-item
                      :data-testid="`edit-status-${status.id}`"
                      @action="startEditingStatus(status)"
                    >
                      <template #list-item>
                        {{ s__('WorkItem|Edit status') }}
                      </template>
                    </gl-disclosure-dropdown-item>

                    <gl-disclosure-dropdown-item
                      v-if="!isDefaultStatus(status) && getCategoryDefaultState(category)"
                      :data-testid="`make-default-${status.id}`"
                      @action="startDefaultingStatus(status, getCategoryDefaultState(category))"
                    >
                      <template #list-item>
                        {{ getDefaultDropdownTextForStatus(getCategoryDefaultState(category)) }}
                      </template>
                    </gl-disclosure-dropdown-item>

                    <gl-disclosure-dropdown-item
                      :data-testid="`remove-status-${status.id}`"
                      variant="danger"
                      @action="startRemovingStatus(status)"
                    >
                      <template #list-item>
                        {{ s__('WorkItem|Remove status') }}
                      </template>
                    </gl-disclosure-dropdown-item>
                  </gl-disclosure-dropdown>
                </div>

                <status-form
                  v-else
                  :key="status.name"
                  :category-icon="$options.STATUS_CATEGORIES_MAP[category].icon"
                  :category-name="category"
                  :form-data="formData"
                  :form-errors="formErrors"
                  :statuses="filteredStatusesFromCurrentLifecycle"
                  is-editing
                  @update="formData = $event"
                  @update-error="formErrors.name = $event"
                  @validate="validateForm"
                  @save="saveStatus"
                  @cancel="cancelForm"
                />
              </div>
            </vue-draggable>
          </div>
          <gl-button
            v-if="addingToCategory !== category"
            category="tertiary"
            class="gl-mt-3"
            icon="plus"
            data-testid="add-status-button"
            @click="startAddingStatus(category)"
          >
            {{ s__('WorkItem|Add status') }}
          </gl-button>

          <status-form
            v-if="addingToCategory === category"
            :category-icon="$options.STATUS_CATEGORIES_MAP[category].icon"
            :category-name="category"
            :form-data="formData"
            :form-errors="formErrors"
            :statuses="filteredStatusesFromCurrentLifecycle"
            @update="formData = $event"
            @update-error="formErrors.name = $event"
            @save="saveStatus"
            @cancel="cancelForm"
          />
        </div>
      </template>

      <template #modal-footer>
        <gl-button @click="closeModal">{{ __('Close') }}</gl-button>
      </template>
    </gl-modal>
    <remove-status-modal
      v-if="Boolean(statusToRemove)"
      :full-path="fullPath"
      :lifecycle="lifecycle"
      :status-to-remove="statusToRemove"
      @hidden="statusToRemove = null"
      @lifecycle-updated="$emit('lifecycle-updated')"
    />
  </div>
</template>
