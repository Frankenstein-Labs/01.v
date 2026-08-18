<script>
import {
  GlFormCheckbox,
  GlButton,
  GlBadge,
  GlLink,
  GlAlert,
  GlLoadingIcon,
  GlModal,
  GlTable,
  GlSprintf,
  GlToastMixin,
} from '@gitlab/ui';

import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import InternalEvents from '~/tracking/internal_events';
import CreateForm from 'ee/groups/settings/compliance_frameworks/components/create_form.vue';
import EditForm from 'ee/groups/settings/compliance_frameworks/components/edit_form.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import FrameworkBadge from '../shared/framework_badge.vue';
import { isTopLevelGroup } from '../../utils';
import updateComplianceFrameworksMutation from '../../graphql/mutations/project_update_compliance_frameworks.graphql';
import { CREATE_FRAMEWORKS_DOCS_URL } from '../../constants';
import getComplianceFrameworksCompactQuery from './graphql/get_compliance_frameworks_compact.query.graphql';
import SelectionOperations from './selection_operations.vue';
import FrameworkSelectionBox from './framework_selection_box.vue';

export default {
  name: 'ProjectsTable',
  components: {
    CreateForm,
    EditForm,

    FrameworkBadge,
    FrameworkSelectionBox,
    SelectionOperations,

    GlButton,
    GlBadge,
    GlFormCheckbox,
    GlLink,
    GlLoadingIcon,
    GlModal,
    GlTable,
    GlAlert,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin(), GlToastMixin],
  inject: ['canAdminComplianceFrameworks'],
  props: {
    projects: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    groupPath: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
    hasFilters: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['updated'],
  apollo: {
    frameworks: {
      query: getComplianceFrameworksCompactQuery,
      variables() {
        return { fullPath: this.groupPath };
      },
      update(data) {
        return data.namespace.complianceFrameworks?.nodes || [];
      },
      error(error) {
        createAlert({
          message: __('Something went wrong on our end.'),
        });
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      frameworks: [],
      selectedRows: [],
      projectWhichInvokedModal: null,
      frameworkSelectedForEdit: null,
      preselectedFrameworkForBulkOperation: null,
      projectsPendindSingleOperation: [],
      isApplyInProgress: false,
      selectedFrameworkIds: [],
    };
  },
  computed: {
    isFrameworkEditingEnabled() {
      return (
        isTopLevelGroup(this.groupPath, this.rootAncestor.path) && this.canAdminComplianceFrameworks
      );
    },
    tableFields() {
      const selectionField = {
        key: 'selected',
        sortable: false,
        thClass: '!gl-align-middle',
        tdClass: '!gl-align-middle',
      };

      const shouldIncludeSelection = this.canAdminComplianceFrameworks && !this.projectPath;

      return [...(shouldIncludeSelection ? [selectionField] : []), ...this.$options.fields];
    },
    hasSelectedProjects() {
      return this.selectedRows.length > 0;
    },
    hasSelectedAllProjects() {
      return this.selectedRows.length === this.projects.length;
    },
    noProjectsText() {
      return this.hasFilters
        ? this.$options.i18n.noProjectsFoundMatchingFilters
        : this.$options.i18n.noProjectsFound;
    },
    showNoFrameworksAlert() {
      return (
        !this.projectPath &&
        !this.frameworks.length &&
        !this.isLoading &&
        !isTopLevelGroup(this.groupPath, this.rootAncestor.path) &&
        this.canAdminComplianceFrameworks
      );
    },
    isFrameworkSelectionAvailable() {
      return this.isFrameworkEditingEnabled || this.frameworks.length;
    },
  },
  methods: {
    updateSelectedRows(selection) {
      this.selectedRows = selection;
    },
    qaRowAttributes(project, type) {
      if (type === 'row') {
        return {
          'data-testid': 'project-frameworks-row',
          'data-qa-project-name': project.name,
        };
      }

      return {};
    },
    async applyOperations(operations) {
      const isBulkAction = operations.length > 1;
      try {
        this.isApplyInProgress = true;
        const results = await Promise.all(
          operations.map((entry) =>
            this.$apollo.mutate({
              mutation: updateComplianceFrameworksMutation,
              variables: {
                projectId: entry.projectId,
                complianceFrameworkIds: entry.frameworkIds,
              },
            }),
          ),
        );

        const errors = results.find(
          (response) => response.data.projectUpdateComplianceFrameworks.errors,
        );
        if (errors.length) {
          throw errors[0];
        }

        this.trackEvent('apply_compliance_framework', {
          property: operations.map((entry) => entry.projectId).join(','),
        });

        if (isBulkAction) {
          this.$toast.show(this.$options.i18n.successUpdateToastMessage, {
            action: {
              text: __('Undo'),
              onClick: () => {
                this.applyOperations(
                  operations.map((entry) => ({
                    projectId: entry.projectId,
                    previousFrameworkIds: entry.frameworkIds,
                    frameworkIds: entry.previousFrameworkIds,
                  })),
                );
              },
            },
          });
        }
      } catch (e) {
        const message = e?.message || __('Something went wrong on our end.');
        createAlert({
          message,
        });
      } finally {
        this.isApplyInProgress = false;
        this.$emit('updated');
      }
    },
    async applySingleItemOperation(operation) {
      try {
        this.projectsPendindSingleOperation.push(operation.projectId);
        await this.applyOperations([operation]);
      } finally {
        this.projectsPendindSingleOperation = this.projectsPendindSingleOperation.filter(
          (projectId) => projectId !== operation.projectId,
        );
      }
    },
    hasPendingSingleOperation(projectId) {
      return this.projectsPendindSingleOperation.indexOf(projectId) > -1;
    },
    createComplianceFramework(projectId, frameworks = []) {
      this.projectWhichInvokedModal = projectId;
      this.selectedFrameworkIds = frameworks.map((f) => f.id);
      this.$refs.createModal.show();
    },
    getFrameworkIdsToApply(frameworks, idsToDelete) {
      const frameworkIds = frameworks.map((f) => f.id);
      return frameworkIds.filter((id) => !idsToDelete.includes(id));
    },
    handleItemDelete(projectId, frameworkId, frameworks = []) {
      const frameworksToApply = this.getFrameworkIdsToApply(frameworks, [frameworkId]);
      this.applySingleItemOperation({
        projectId,
        frameworkIds: frameworksToApply,
      });
    },
    selectNewlyCreatedFramework({ framework }) {
      const projectId = this.projectWhichInvokedModal;
      const frameworkIds = this.selectedFrameworkIds;
      this.resetCreateModal();
      if (projectId === this.$options.BULK_FRAMEWORK_ID) {
        this.preselectedFrameworkForBulkOperation = framework;
      } else {
        this.applySingleItemOperation({
          projectId,
          frameworkIds: [...frameworkIds, framework.id],
        });
      }
    },
    resetCreateModal() {
      this.projectWhichInvokedModal = null;
      this.selectedFrameworkIds = [];
      this.$refs.createModal.hide();
    },
    resetEditModal() {
      this.frameworkSelectedForEdit = null;
      this.$refs.editModal.hide();
    },
  },
  fields: [
    {
      key: 'projectName',
      label: __('Project name'),
      thClass: '!gl-align-middle',
      tdClass: '!gl-align-middle',
      sortable: false,
    },
    {
      key: 'projectPath',
      label: __('Project path'),
      thClass: '!gl-align-middle',
      tdAttr: { 'data-testid': 'project-path-content' },
      tdClass: '!gl-align-middle',
      sortable: false,
    },
    {
      key: 'complianceFramework',
      label: __('Compliance frameworks'),
      thClass: '!gl-align-middle',
      tdClass: '!gl-align-middle',
      sortable: false,
    },
    {
      key: 'action',
      label: __('Action'),
      thAlignRight: true,
      thClass: '!gl-align-middle',
      tdClass: '!gl-text-right',
      sortable: false,
    },
  ],
  i18n: {
    archived: __('Archived'),
    addTitle: s__('ComplianceFrameworks|New compliance framework'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),

    noProjectsFound: s__('ComplianceReport|No projects found'),
    noProjectsFoundMatchingFilters: s__('ComplianceReport|No projects found that match filters'),
    selectFrameworks: s__('ComplianceReport|Select frameworks'),
    noFrameworks: s__('ComplianceReport|No frameworks'),
    successUpdateToastMessage: s__('ComplianceReport|Frameworks have been successfully updated.'),
    noFrameworksText: s__(
      'ComplianceFrameworks|No frameworks found. Create a framework in top-level group %{linkStart}namespace%{linkEnd} to assign it to a project.',
    ),
    learnMore: __('Learn more'),
  },
  BULK_FRAMEWORK_ID: '__INTERNAL_BULK_FRAMEWORK_VALUE',
  CREATE_FRAMEWORKS_DOCS_URL,
};
</script>
<template>
  <div>
    <gl-modal
      ref="createModal"
      :title="$options.i18n.addTitle"
      modal-id="create-framework-form-modal"
      hide-footer
    >
      <create-form @success="selectNewlyCreatedFramework" @cancel="resetCreateModal" />
    </gl-modal>
    <gl-modal
      ref="editModal"
      :title="$options.i18n.editTitle"
      modal-id="edit-framework-form-modal"
      hide-footer
    >
      <edit-form
        v-if="frameworkSelectedForEdit"
        :id="frameworkSelectedForEdit.id"
        :framework="frameworkSelectedForEdit"
        @success="resetEditModal"
        @cancel="resetEditModal"
      />
    </gl-modal>
    <gl-alert
      v-if="showNoFrameworksAlert"
      variant="info"
      data-testid="no-frameworks-alert"
      :dismissible="false"
    >
      <gl-sprintf :message="$options.i18n.noFrameworksText">
        <template #link>
          <gl-link :href="rootAncestor.complianceCenterPath">{{ rootAncestor.name }}</gl-link>
        </template>
      </gl-sprintf>

      <gl-link :href="$options.CREATE_FRAMEWORKS_DOCS_URL" target="blank"
        >{{ $options.i18n.learnMore }}.</gl-link
      >
    </gl-alert>
    <selection-operations
      v-if="!projectPath"
      :selection="selectedRows"
      :group-path="groupPath"
      :is-apply-in-progress="isApplyInProgress"
      :is-framework-creating-enabled="isFrameworkEditingEnabled"
      :default-framework="preselectedFrameworkForBulkOperation"
      @change="applyOperations"
      @create="createComplianceFramework($options.BULK_FRAMEWORK_ID)"
    />
    <gl-table
      :fields="tableFields"
      :busy="isLoading"
      :items="projects"
      no-local-sorting
      show-empty
      stacked="lg"
      hover
      :tbody-tr-attr="qaRowAttributes"
      :selectable="!projectPath"
      select-mode="multi"
      selected-variant="primary"
      @row-selected="updateSelectedRows"
    >
      <template #head(selected)="{ selectAllRows, clearSelected }">
        <gl-form-checkbox
          class="gl-pt-2"
          data-testid="select-all-projects-checkbox"
          :checked="hasSelectedProjects"
          :indeterminate="hasSelectedProjects && !hasSelectedAllProjects"
          @change="hasSelectedProjects ? clearSelected() : selectAllRows()"
        />
      </template>
      <template #cell(selected)="{ rowSelected, selectRow, unselectRow }">
        <div>
          <gl-form-checkbox
            class="gl-pt-2"
            data-testid="select-project-checkbox"
            :checked="rowSelected"
            @change="rowSelected ? unselectRow() : selectRow()"
          />
        </div>
      </template>
      <template #cell(projectName)="{ item }">
        <gl-link :href="item.webUrl" data-testid="project-name-link">{{ item.name }} </gl-link>
        <gl-badge v-if="item.archived" variant="info" class="gl-mr-2">{{
          $options.i18n.archived
        }}</gl-badge>
      </template>
      <template #cell(projectPath)="{ item: { fullPath } }">
        {{ fullPath }}
      </template>
      <template #cell(complianceFramework)="{ item: { id, complianceFrameworks } }">
        <div v-if="!complianceFrameworks.length && !hasPendingSingleOperation(id)">
          {{ $options.i18n.noFrameworks }}
        </div>
        <framework-badge
          v-for="framework in complianceFrameworks"
          :key="framework.id"
          :closeable="canAdminComplianceFrameworks"
          :popover-mode="isFrameworkEditingEnabled ? 'edit' : 'details'"
          class="gl-my-2 gl-mr-2 gl-inline-block"
          :framework="framework"
          @close="handleItemDelete(id, framework.id, complianceFrameworks)"
        />
        <gl-loading-icon
          v-if="hasPendingSingleOperation(id)"
          class="gl-my-2 gl-mr-2 gl-inline-block"
          size="sm"
          inline
        />
      </template>
      <template #cell(action)="{ item: { id, complianceFrameworks } }">
        <framework-selection-box
          v-if="canAdminComplianceFrameworks && isFrameworkSelectionAvailable"
          :is-framework-creating-enabled="isFrameworkEditingEnabled"
          :selected="complianceFrameworks.map((f) => f.id)"
          :group-path="groupPath"
          @update="
            applySingleItemOperation({
              projectId: id,
              frameworkIds: $event,
            })
          "
          @create="createComplianceFramework(id, complianceFrameworks)"
        >
          <template #toggle>
            <gl-button
              icon="pencil"
              category="secondary"
              size="small"
              variant="default"
              :aria-label="$options.i18n.selectFrameworks"
            />
          </template>
        </framework-selection-box>
      </template>
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #empty>
        <div class="gl-my-5 gl-text-center" data-testid="projects-table-empty-state">
          {{ noProjectsText }}
        </div>
      </template>
    </gl-table>
  </div>
</template>
