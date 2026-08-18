<script>
import { s__ } from '~/locale';
import ProjectSelect from '~/sidebar/components/move/issuable_move_dropdown.vue';
import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import { TYPE_TEST_CASE, NAMESPACE_PROJECT } from '~/issues/constants';
import TestCaseGraphQL from '../mixins/test_case_graphql';

export default {
  name: 'TestCaseSidebar',
  TYPE_TEST_CASE,
  NAMESPACE_PROJECT,
  components: {
    ProjectSelect,
    LabelsSelectWidget,
    SidebarConfidentialityWidget,
  },
  mixins: [TestCaseGraphQL],
  inject: [
    'projectFullPath',
    'testCaseId',
    'canEditTestCase',
    'canMoveTestCase',
    'labelsFetchPath',
    'labelsManagePath',
    'projectsFetchPath',
    'testCasesPath',
  ],
  props: {
    sidebarExpanded: {
      type: Boolean,
      required: true,
    },
    moved: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['sidebar-toggle'],
  data() {
    return {
      sidebarExpandedOnClick: false,
    };
  },
  computed: {
    selectProjectDropdownButtonTitle() {
      return this.testCaseMoveInProgress
        ? s__('TestCases|Moving test case')
        : s__('TestCases|Move test case');
    },
  },
  mounted() {
    this.sidebarEl = document.querySelector('aside.right-sidebar');
  },
  methods: {
    toggleSidebar() {
      this.$emit('sidebar-toggle');
    },
    expandSidebar() {
      this.toggleSidebar();
      this.sidebarExpandedOnClick = true;
    },
    closeSidebar() {
      this.sidebarExpandedOnClick = false;
      this.toggleSidebar();
    },
    expandSidebarAndOpenDropdown(dropdownButtonSelector) {
      // Expand the sidebar if not already expanded.
      if (!this.sidebarExpanded) {
        this.expandSidebar();
      }

      this.$nextTick(() => {
        // Wait for sidebar expand animation to complete
        // before revealing the dropdown.
        this.sidebarEl.addEventListener(
          'transitionend',
          () => {
            document
              .querySelector(dropdownButtonSelector)
              .dispatchEvent(new Event('click', { bubbles: true, cancelable: false }));
          },
          { once: true },
        );
      });
    },
    handleSidebarDropdownClose() {
      if (this.sidebarExpandedOnClick) {
        this.closeSidebar();
      }
    },
    handleLabelsCollapsedButtonClick() {
      if (!this.sidebarExpanded) {
        this.expandSidebar();
      } else if (this.sidebarExpandedOnClick) {
        this.closeSidebar();
      }
    },
    handleProjectsCollapsedButtonClick() {
      this.expandSidebarAndOpenDropdown('.js-issuable-move-block .js-sidebar-dropdown-toggle');
    },
  },
};
</script>

<template>
  <div class="test-case-sidebar-items">
    <labels-select-widget
      :iid="String(testCaseId)"
      :full-path="projectFullPath"
      :allow-label-remove="canEditTestCase"
      :allow-multiselect="true"
      :issuable-type="$options.TYPE_TEST_CASE"
      :attr-workspace-path="projectFullPath"
      workspace-type="project"
      class="block labels js-labels-block"
      variant="sidebar"
      :label-create-type="$options.NAMESPACE_PROJECT"
      :labels-filter-base-path="testCasesPath"
      @toggle-collapse="handleLabelsCollapsedButtonClick"
    >
      {{ __('None') }}
    </labels-select-widget>
    <sidebar-confidentiality-widget
      :iid="String(testCaseId)"
      :full-path="projectFullPath"
      :issuable-type="$options.TYPE_TEST_CASE"
      @expand-sidebar="expandSidebar"
      @close-form="handleSidebarDropdownClose"
    />
    <project-select
      v-if="canMoveTestCase && !moved"
      :projects-fetch-path="projectsFetchPath"
      :dropdown-button-title="selectProjectDropdownButtonTitle"
      :dropdown-header-title="__('Move test case')"
      :move-in-progress="testCaseMoveInProgress"
      class="block"
      @dropdown-close="handleSidebarDropdownClose"
      @toggle-collapse="handleProjectsCollapsedButtonClick"
      @move-issuable="moveTestCase"
    />
  </div>
</template>
