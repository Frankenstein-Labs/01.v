<script>
import {
  GlLoadingIcon,
  GlButton,
  GlSprintf,
  GlLink,
  GlAlert,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';

import { STATUS_OPEN, NAMESPACE_PROJECT } from '~/issues/constants';
import IssuableShow from '~/vue_shared/issuable/show/components/issuable_show_root.vue';
import IssuableEventHub from '~/vue_shared/issuable/show/event_hub';
import { s__, __ } from '~/locale';

import TestCaseGraphQL from '../mixins/test_case_graphql';
import TestCaseSidebar from './test_case_sidebar.vue';
import TestCaseSidebarTodo from './test_case_sidebar_todo.vue';

const stateEvent = {
  Close: 'CLOSE',
  Reopen: 'REOPEN',
};

export default {
  name: 'TestCaseShowRoot',
  NAMESPACE_PROJECT,
  components: {
    GlLoadingIcon,
    GlButton,
    GlSprintf,
    GlLink,
    GlAlert,
    IssuableShow,
    TestCaseSidebar,
    TestCaseSidebarTodo,
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
  },
  mixins: [TestCaseGraphQL],
  inject: [
    'projectFullPath',
    'testCaseNewPath',
    'testCaseId',
    'updatePath',
    'lockVersion',
    'canEditTestCase',
    'descriptionPreviewPath',
    'descriptionHelpPath',
  ],
  data() {
    return {
      testCase: {},
      taskCompletionStatus: {},
      editTestCaseFormVisible: false,
      testCaseSaveInProgress: false,
      testCaseStateChangeInProgress: false,
      taskListUpdateFailed: false,
    };
  },
  computed: {
    isTestCaseOpen() {
      return this.testCase.state === STATUS_OPEN;
    },
    statusIcon() {
      return this.isTestCaseOpen ? 'issue-open-m' : 'check';
    },
    statusBadgeText() {
      return this.isTestCaseOpen ? __('Open') : __('Archived');
    },
    testCaseActionTitle() {
      return this.isTestCaseOpen ? __('Archive') : __('Reopen');
    },
    editCaseActionTitle() {
      return __('Edit');
    },
    editCaseActionAriaLabel() {
      return __('Edit title and description');
    },
    todo() {
      const todos = this.testCase.currentUserTodos.nodes;

      return todos.length ? todos[0] : null;
    },
    editTestCaseItem() {
      return {
        text: this.editCaseActionTitle,
        action: this.handleEditTestCase,
        extraAttrs: {
          'data-testid': 'edit-test-case',
        },
      };
    },
    toggleTestCaseStateItem() {
      return { text: this.testCaseActionTitle, action: this.handleTestCaseStateChange };
    },
    newTestCaseItem() {
      return { text: __('New test case'), href: this.testCaseNewPath };
    },
  },
  methods: {
    handleTestCaseStateChange() {
      this.testCaseStateChangeInProgress = true;
      return this.updateTestCase({
        variables: {
          stateEvent: this.isTestCaseOpen ? stateEvent.Close : stateEvent.Reopen,
        },
        errorMessage: s__('TestCases|Something went wrong while updating the test case.'),
      })
        .then((updatedTestCase) => {
          this.testCase = updatedTestCase;
        })
        .finally(() => {
          this.testCaseStateChangeInProgress = false;
        });
    },
    handleTaskListUpdateSuccess() {
      this.$apollo.queries.taskCompletionStatus.refetch();
    },
    handleTaskListUpdateFailure() {
      this.taskListUpdateFailed = true;
    },
    handleEditTestCase() {
      this.editTestCaseFormVisible = true;
    },
    handleSaveTestCase({ issuableTitle, issuableDescription }) {
      this.testCaseSaveInProgress = true;
      return this.updateTestCase({
        variables: {
          title: issuableTitle,
          description: issuableDescription,
        },
        errorMessage: s__('TestCases|Something went wrong while updating the test case.'),
      })
        .then((updatedTestCase) => {
          this.testCase = updatedTestCase;
          this.editTestCaseFormVisible = false;
          IssuableEventHub.$emit('update.issuable');
        })
        .finally(() => {
          this.testCaseSaveInProgress = false;
        });
    },
    handleCancelClick() {
      this.editTestCaseFormVisible = false;
      IssuableEventHub.$emit('close.form');
    },
    handleTestCaseUpdated(updatedTestCase) {
      this.testCase = updatedTestCase;
    },
  },
};
</script>

<template>
  <div class="test-case-container">
    <gl-alert v-if="taskListUpdateFailed" variant="danger" @dismiss="taskListUpdateFailed = false">
      {{
        __(
          'Someone edited this test case at the same time you did. The description has been updated and you will need to make your changes again.',
        )
      }}
    </gl-alert>
    <gl-loading-icon v-if="testCaseLoading" size="lg" class="gl-mt-3" />
    <issuable-show
      v-if="!testCaseLoading && !testCaseLoadFailed"
      :issuable="testCase"
      :status-icon="statusIcon"
      :enable-edit="canEditTestCase"
      hide-edit-button
      :enable-autocomplete="true"
      :enable-task-list="true"
      :edit-form-visible="editTestCaseFormVisible"
      :description-preview-path="descriptionPreviewPath"
      :description-help-path="descriptionHelpPath"
      :task-completion-status="taskCompletionStatus"
      :task-list-update-path="updatePath"
      :task-list-lock-version="lockVersion"
      :workspace-type="$options.NAMESPACE_PROJECT"
      show-work-item-type-icon
      @task-list-update-success="handleTaskListUpdateSuccess"
      @task-list-update-failure="handleTaskListUpdateFailure"
    >
      <template #status-badge>
        <gl-sprintf
          v-if="testCase.moved"
          :message="__('Archived (%{movedToStart}moved%{movedToEnd})')"
        >
          <template #movedTo="{ content }">
            <gl-link :href="testCase.movedTo.webUrl" class="text-underline !gl-text-white">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
        <span v-else>{{ statusBadgeText }}</span>
      </template>
      <template #header-actions>
        <gl-disclosure-dropdown
          v-if="canEditTestCase"
          data-testid="actions-dropdown"
          class="gl-ml-auto @md/panel:gl-hidden"
          placement="bottom-end"
          category="secondary"
          :toggle-text="__('Options')"
        >
          <gl-disclosure-dropdown-item :item="editTestCaseItem" />
          <gl-disclosure-dropdown-item
            :item="toggleTestCaseStateItem"
            data-testid="toggle-state-dropdown-item"
          />
          <gl-disclosure-dropdown-group bordered>
            <gl-disclosure-dropdown-item :item="newTestCaseItem" />
          </gl-disclosure-dropdown-group>
        </gl-disclosure-dropdown>
        <gl-button
          v-if="canEditTestCase"
          data-testid="edit-test-case"
          class="gl-hidden @md/panel:gl-inline-flex"
          :loading="testCaseStateChangeInProgress"
          :title="editCaseActionAriaLabel"
          :aria-label="editCaseActionAriaLabel"
          @click="handleEditTestCase"
          >{{ editCaseActionTitle }}</gl-button
        >
        <gl-button
          v-if="canEditTestCase"
          data-testid="archive-test-case"
          class="gl-hidden @md/panel:gl-inline-flex"
          :loading="testCaseStateChangeInProgress"
          @click="handleTestCaseStateChange"
          >{{ testCaseActionTitle }}</gl-button
        >
        <gl-button
          data-testid="new-test-case"
          category="secondary"
          variant="confirm"
          class="@md/panel:gl-inline-flex"
          :class="{ 'gl-hidden': canEditTestCase, 'gl-grow': !canEditTestCase }"
          :href="testCaseNewPath"
          >{{ __('New test case') }}</gl-button
        >
      </template>
      <template #edit-form-actions="{ issuableMeta }">
        <gl-button
          data-testid="save-test-case"
          :disable="testCaseSaveInProgress || !issuableMeta.issuableTitle.length"
          :loading="testCaseSaveInProgress"
          category="primary"
          variant="confirm"
          class="gl-float-left"
          @click.prevent="handleSaveTestCase(issuableMeta)"
          >{{ __('Save changes') }}</gl-button
        >
        <gl-button data-testid="cancel-test-case-edit" @click="handleCancelClick">
          {{ __('Cancel') }}
        </gl-button>
      </template>
      <template #right-sidebar-top-items="{ sidebarExpanded, toggleSidebar }">
        <test-case-sidebar-todo
          :sidebar-expanded="sidebarExpanded"
          :todo="todo"
          @test-case-updated="handleTestCaseUpdated"
          @sidebar-toggle="toggleSidebar"
        />
      </template>
      <template #right-sidebar-items="{ sidebarExpanded, toggleSidebar }">
        <test-case-sidebar
          :sidebar-expanded="sidebarExpanded"
          :moved="testCase.moved"
          @test-case-updated="handleTestCaseUpdated"
          @sidebar-toggle="toggleSidebar"
        />
      </template>
    </issuable-show>
  </div>
</template>
