import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import TestCaseSidebar from 'ee/test_case_show/components/test_case_sidebar.vue';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import ProjectSelect from '~/sidebar/components/move/issuable_move_dropdown.vue';
import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import projectTestCase from 'ee/test_case_show/queries/project_test_case.query.graphql';

import { TYPE_TEST_CASE, NAMESPACE_PROJECT } from '~/issues/constants';
import { mockProvide, mockTaskCompletionResponse } from '../mock_data';

Vue.use(VueApollo);

describe('TestCaseSidebar', () => {
  let wrapper;

  const createComponent = ({ provide = {}, sidebarExpanded = true, moved = false } = {}) => {
    const apolloProvider = createMockApollo([[projectTestCase, mockTaskCompletionResponse]]);

    wrapper = shallowMountExtended(TestCaseSidebar, {
      provide: {
        ...mockProvide,
        ...provide,
      },
      apolloProvider,
      propsData: {
        sidebarExpanded,
        moved,
      },
    });
  };

  const findLabelsSelectWidget = () => wrapper.findComponent(LabelsSelectWidget);
  const findSidebarConfidentialityWidget = () =>
    wrapper.findComponent(SidebarConfidentialityWidget);
  const findProjectSelect = () => wrapper.findComponent(ProjectSelect);

  beforeEach(() => {
    setHTMLFixture('<aside class="right-sidebar"></aside>');
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('Label select widget', () => {
    it('renders label-select', () => {
      createComponent();

      const { testCaseId, canEditTestCase, projectFullPath, testCasesPath } = mockProvide;
      const labelSelectEl = findLabelsSelectWidget();

      expect(labelSelectEl.props()).toMatchObject({
        iid: testCaseId,
        fullPath: projectFullPath,
        allowLabelRemove: canEditTestCase,
        allowMultiselect: true,
        issuableType: TYPE_TEST_CASE,
        attrWorkspacePath: projectFullPath,
        workspaceType: 'project',
        variant: 'sidebar',
        labelCreateType: NAMESPACE_PROJECT,
        labelsFilterBasePath: testCasesPath,
      });
      expect(labelSelectEl.text()).toBe('None');
    });

    it('emits "sidebar-toggle" events on click', () => {
      createComponent({
        sidebarExpanded: false,
      });

      expect(wrapper.emitted('sidebar-toggle')).toBeUndefined();

      findLabelsSelectWidget().vm.$emit('toggle-collapse');

      expect(wrapper.emitted('sidebar-toggle')).toHaveLength(1);
    });
  });

  describe('Confidentiality widget', () => {
    describe('when sidebar is expanded by default', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders confidentiality widget', () => {
        const { testCaseId, projectFullPath } = mockProvide;
        const sidebarConfidentialityEl = findSidebarConfidentialityWidget();

        expect(sidebarConfidentialityEl.props()).toMatchObject({
          iid: testCaseId,
          fullPath: projectFullPath,
          issuableType: TYPE_TEST_CASE,
        });
      });

      it('does not emit "sidebar-toggle" on close-form', () => {
        expect(wrapper.emitted('sidebar-toggle')).toBeUndefined();

        findSidebarConfidentialityWidget().vm.$emit('close-form');

        expect(wrapper.emitted('sidebar-toggle')).toBeUndefined();
      });
    });

    describe('when sidebar has been expanded by click', () => {
      it('emits "sidebar-toggle" on close-form', () => {
        createComponent({
          sidebarExpanded: false,
        });

        expect(wrapper.emitted('sidebar-toggle')).toBeUndefined();

        findSidebarConfidentialityWidget().vm.$emit('expand-sidebar');

        expect(wrapper.emitted('sidebar-toggle')).toHaveLength(1);

        findSidebarConfidentialityWidget().vm.$emit('close-form');

        expect(wrapper.emitted('sidebar-toggle')).toHaveLength(2);
      });
    });
  });

  describe('Project select', () => {
    it('renders project-select', () => {
      createComponent();

      const { projectsFetchPath } = mockProvide;
      const projectSelectEl = findProjectSelect();

      expect(projectSelectEl.props()).toMatchObject({
        projectsFetchPath,
        dropdownButtonTitle: 'Move test case',
        moveInProgress: false,
      });
    });

    it('does not render project-select', () => {
      createComponent({
        provide: {
          canMoveTestCase: false,
        },
        sidebarExpanded: false,
      });

      expect(findProjectSelect().exists()).toBe(false);
    });

    it('emits "sidebar-toggle" on dropdown-close when the sidebar has been expanded by click', () => {
      createComponent({
        sidebarExpanded: false,
      });

      expect(wrapper.emitted('sidebar-toggle')).toBeUndefined();

      findLabelsSelectWidget().vm.$emit('toggle-collapse');

      expect(wrapper.emitted('sidebar-toggle')).toHaveLength(1);

      findProjectSelect().vm.$emit('dropdown-close');

      expect(wrapper.emitted('sidebar-toggle')).toHaveLength(2);
    });

    it('dispatches click event on move test case button', async () => {
      setHTMLFixture(`
        <aside class="right-sidebar"></aside>
        <div class="js-issuable-move-block">
          <button class="js-sidebar-dropdown-toggle"></button>
        </div>
      `);

      createComponent({
        sidebarExpanded: false,
      });

      const buttonEl = document.querySelector('.js-sidebar-dropdown-toggle');
      const sidebarEl = document.querySelector('aside.right-sidebar');
      jest.spyOn(buttonEl, 'dispatchEvent');

      findProjectSelect().vm.$emit('toggle-collapse');
      await nextTick();
      sidebarEl.dispatchEvent(new Event('transitionend'));

      expect(buttonEl.dispatchEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'click',
          bubbles: true,
          cancelable: false,
        }),
      );

      resetHTMLFixture();
    });
  });
});
