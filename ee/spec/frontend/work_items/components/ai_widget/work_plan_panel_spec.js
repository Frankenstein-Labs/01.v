import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkPlanPanel from 'ee/work_items/components/ai_widget/work_plan_panel.vue';
import DuoWorkItemToMrAction from 'ee/ai/shared/widgets/duo_work_item_to_mr_action.vue';
import {
  WORKPLAN_GOAL_PREFIX,
  GENERATE_MR_BUTTON_OPTIONS,
} from 'ee/work_items/components/ai_widget/constants';
import { DUO_CHAT_AGENT_GITLAB_DUO } from 'ee/ai/constants';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import namespacePathsQuery from '~/work_items/graphql/namespace_paths.query.graphql';
import * as urlUtility from '~/lib/utils/url_utility';

Vue.use(VueApollo);

const MountingPortalStub = {
  name: 'MountingPortal',
  template: '<div data-testid="mounting-portal-stub"><slot /></div>',
};

const mockMarkdownPaths = {
  markdownPreviewPath: '/group/project/-/preview_markdown',
  uploadsPath: '/group/project/uploads',
  autocompleteSourcesPath: '/group/project/-/autocomplete_sources',
};

const namespacePathsHandler = jest.fn().mockResolvedValue({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      markdownPaths: mockMarkdownPaths,
    },
  },
});

const defaultProps = {
  open: true,
  workItemId: 'gid://gitlab/WorkItem/1',
  canUpdate: true,
  savedContent: '',
  draftContent: '',
  isEditing: false,
  isSaving: false,
  workItemIid: '1',
  workItemType: 'Issue',
  workItemWebUrl: 'http://gdk.test/group/project/-/work_items/1',
  hasRemoteFlowsEnabled: false,
};

describe('WorkPlanPanel', () => {
  let wrapper;

  const createComponent = ({ fullPath = 'group/project', ...props } = {}) => {
    wrapper = shallowMountExtended(WorkPlanPanel, {
      apolloProvider: createMockApollo([[namespacePathsQuery, namespacePathsHandler]]),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: { fullPath },
      stubs: {
        MountingPortal: MountingPortalStub,
      },
    });
  };

  const findPortal = () => wrapper.findByTestId('mounting-portal-stub');
  const findPanel = () => wrapper.findByTestId('work-plan-panel');
  const findEditButton = () => wrapper.findComponentByTestId('panel-edit-button');
  const findMoreActionsDropdown = () => wrapper.findComponentByTestId('panel-edit-more-actions');
  const findCloseButton = () => wrapper.findComponentByTestId('panel-close-button');
  const findSaveButton = () => wrapper.findComponentByTestId('save-work-plan-button');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-work-plan-button');
  const findEmptyState = () => wrapper.findByTestId('work-plan-empty-state');
  const findEmptyStateComponent = () => wrapper.findComponentByTestId('work-plan-empty-state');
  const findGenerateWithDuoButton = () =>
    wrapper.findComponentByTestId('panel-generate-with-duo-button');
  const findCreateManuallyButton = () =>
    wrapper.findComponentByTestId('panel-create-manually-button');
  const findGenerateMrButton = () => wrapper.findByTestId('panel-generate-mr-with-duo');
  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findRenderedMarkdown = () => wrapper.findComponent(NonGfmMarkdown);

  const enterEditMode = async () => {
    await findEditButton().vm.$emit('click');
    await wrapper.setProps({ isEditing: true });
  };

  describe('rendering', () => {
    describe('when open is false', () => {
      beforeEach(() => {
        createComponent({ open: false });
      });

      it('does not render the portal', () => {
        expect(findPortal().exists()).toBe(false);
      });
    });

    describe('when open is true', () => {
      beforeEach(() => {
        createComponent({ open: true });
      });

      it('renders the panel chrome', () => {
        expect(findPanel().exists()).toBe(true);
      });
    });
  });

  describe('view mode', () => {
    describe('when there is no saved content and the user can update', () => {
      beforeEach(() => {
        createComponent({ savedContent: '', canUpdate: true });
      });

      it('shows the empty state', () => {
        expect(findEmptyState().exists()).toBe(true);
        expect(findEmptyStateComponent().props('title')).toBe('Create a workplan');
      });

      it('renders both empty-state actions', () => {
        expect(findGenerateWithDuoButton().exists()).toBe(true);
        expect(findCreateManuallyButton().exists()).toBe(true);
      });

      it('passes the work item id and the GitLab Duo command to the Duo action', () => {
        const props = findGenerateWithDuoButton().props();
        expect(props.resourceId).toBe('gid://gitlab/WorkItem/1');
        expect(props.command.agent.name).toBe(DUO_CHAT_AGENT_GITLAB_DUO);
        expect(props.command.agenticPrompt).toEqual(expect.any(String));
        expect(props.command.agenticPrompt).toContain(
          'http://gdk.test/group/project/-/work_items/1',
        );
        expect(props.trackingInfo).toEqual({ label: 'create_work_plan' });
      });

      describe('when Create manually is clicked', () => {
        beforeEach(async () => {
          await findCreateManuallyButton().vm.$emit('click');
        });

        it('emits "start-edit"', () => {
          expect(wrapper.emitted('start-edit')).toHaveLength(1);
        });
      });
    });

    describe('when the user cannot update', () => {
      beforeEach(() => {
        createComponent({ savedContent: '', canUpdate: false });
      });

      it('shows a read-only empty state with no actions', () => {
        expect(findEmptyState().text()).toContain("don't have permission");
        expect(findGenerateWithDuoButton().exists()).toBe(false);
        expect(findCreateManuallyButton().exists()).toBe(false);
      });
    });

    describe('when saved content exists', () => {
      beforeEach(() => {
        createComponent({ savedContent: 'Some plan content' });
      });

      it('renders the saved markdown', () => {
        expect(findRenderedMarkdown().exists()).toBe(true);
        expect(findRenderedMarkdown().props('markdown')).toBe('Some plan content');
      });
    });

    describe('Implement button in view mode', () => {
      describe('when remote flows are enabled and content exists', () => {
        beforeEach(() => {
          createComponent({ savedContent: 'Some plan content', hasRemoteFlowsEnabled: true });
        });

        it('renders the button', () => {
          expect(findGenerateMrButton().exists()).toBe(true);
        });

        it('forwards the expected props to DuoWorkItemToMrAction', () => {
          expect(wrapper.findComponent(DuoWorkItemToMrAction).props()).toMatchObject({
            projectPath: 'group/project',
            workItemIid: '1',
            workItemType: 'Issue',
            workItemWebUrl: 'http://gdk.test/group/project/-/work_items/1',
            runDuoDeveloperInChat: true,
            additionalGoalContext: WORKPLAN_GOAL_PREFIX,
            generateMrButtonOptions: GENERATE_MR_BUTTON_OPTIONS,
          });
        });
      });

      describe('when there is no saved content', () => {
        beforeEach(() => {
          createComponent({ savedContent: '', hasRemoteFlowsEnabled: true });
        });

        it('does not render the button', () => {
          expect(findGenerateMrButton().exists()).toBe(false);
        });
      });

      describe('when remote flows are disabled', () => {
        beforeEach(() => {
          createComponent({ savedContent: 'Some plan content', hasRemoteFlowsEnabled: false });
        });

        it('does not render the button', () => {
          expect(findGenerateMrButton().exists()).toBe(false);
        });
      });

      describe('when in edit mode', () => {
        beforeEach(() => {
          createComponent({
            savedContent: 'Some plan content',
            hasRemoteFlowsEnabled: true,
            isEditing: true,
          });
        });

        it('does not render the button', () => {
          expect(findGenerateMrButton().exists()).toBe(false);
        });
      });
    });

    describe('more actions dropdown', () => {
      describe('with saved content', () => {
        let dropdownItems;

        beforeEach(() => {
          createComponent({ savedContent: 'Some plan', canUpdate: true });
          dropdownItems = findMoreActionsDropdown().props('items') || [];
        });

        it('exposes Delete workplan as an option', () => {
          expect(dropdownItems.map((i) => i.text)).toContain('Delete workplan');
        });

        it('exposes Regenerate workplan as an option', () => {
          expect(dropdownItems.map((i) => i.text)).toContain('Regenerate workplan');
        });

        describe('when the Regenerate item is activated', () => {
          beforeEach(() => {
            const regenerate = dropdownItems.find((i) => i.text === 'Regenerate workplan');
            regenerate.action();
          });

          it('emits "regenerate"', () => {
            expect(wrapper.emitted('regenerate')).toHaveLength(1);
          });
        });
      });

      describe('without saved content', () => {
        beforeEach(() => {
          createComponent({ savedContent: '', canUpdate: true });
        });

        it('hides the dropdown so Regenerate is not exposed', () => {
          expect(findMoreActionsDropdown().exists()).toBe(false);
        });
      });
    });
  });

  describe('header buttons', () => {
    describe('when the user can update and is not editing', () => {
      beforeEach(async () => {
        createComponent({ canUpdate: true });
        await waitForPromises();
      });

      it('shows the Edit button', () => {
        expect(findEditButton().exists()).toBe(true);
      });

      describe('when the Close button is clicked', () => {
        beforeEach(async () => {
          await findCloseButton().vm.$emit('click');
        });

        it('emits "close"', () => {
          expect(wrapper.emitted('close')).toHaveLength(1);
        });
      });
    });

    describe('when the user cannot update', () => {
      beforeEach(async () => {
        createComponent({ canUpdate: false });
        await waitForPromises();
      });

      it('hides the Edit button', () => {
        expect(findEditButton().exists()).toBe(false);
      });
    });

    describe('when the Edit button is clicked', () => {
      beforeEach(async () => {
        createComponent({ canUpdate: true, savedContent: 'plan' });
        await findEditButton().vm.$emit('click');
      });

      it('emits "start-edit"', () => {
        expect(wrapper.emitted('start-edit')).toHaveLength(1);
      });
    });
  });

  describe('initial mode', () => {
    it('opens in view mode by default', () => {
      createComponent({ savedContent: 'plan' });
      expect(findMarkdownEditor().exists()).toBe(false);
      expect(findRenderedMarkdown().exists()).toBe(true);
    });
  });

  describe('edit mode', () => {
    beforeEach(async () => {
      createComponent({ savedContent: 'existing plan', canUpdate: true });
      await waitForPromises();
      await enterEditMode();
    });

    it('renders the markdown editor with the saved content', () => {
      expect(findMarkdownEditor().props()).toMatchObject({
        value: 'existing plan',
        renderMarkdownPath: mockMarkdownPaths.markdownPreviewPath,
        uploadsPath: mockMarkdownPaths.uploadsPath,
      });
    });

    it('hides the Edit header button while editing', () => {
      expect(findEditButton().exists()).toBe(false);
    });

    describe('keystrokes', () => {
      it('emits draft-change on every input', async () => {
        await findMarkdownEditor().vm.$emit('input', 'half-typed');
        expect(wrapper.emitted('draft-change')).toEqual([['half-typed']]);
      });
    });

    describe('save', () => {
      it('emits "save" with the new content', async () => {
        await findMarkdownEditor().vm.$emit('input', 'updated plan');
        await findSaveButton().vm.$emit('click');
        expect(wrapper.emitted('save')).toEqual([['updated plan']]);
      });

      it('does not flip out of edit mode locally (orchestrator decides)', async () => {
        await findMarkdownEditor().vm.$emit('input', 'updated plan');
        await findSaveButton().vm.$emit('click');
        await nextTick();
        expect(findMarkdownEditor().exists()).toBe(true);
      });
    });

    describe('cancel', () => {
      describe('when the cancel button is clicked', () => {
        beforeEach(async () => {
          await findCancelButton().vm.$emit('click');
        });

        it('emits "cancel-edit"', () => {
          expect(wrapper.emitted('cancel-edit')).toHaveLength(1);
        });
      });

      it('re-initialises the editor from saved content on the next edit', async () => {
        await findMarkdownEditor().vm.$emit('input', 'unsaved');
        await findCancelButton().vm.$emit('click');
        await wrapper.setProps({ isEditing: false, draftContent: '' });
        await wrapper.setProps({ isEditing: true });
        expect(findMarkdownEditor().props('value')).toBe('existing plan');
      });
    });
  });

  describe('URL state', () => {
    let updateHistorySpy;
    let originalSearch;

    const setSearch = (search) => {
      Object.defineProperty(window, 'location', {
        configurable: true,
        value: { ...window.location, search },
      });
    };

    beforeEach(() => {
      originalSearch = window.location.search;
      updateHistorySpy = jest.spyOn(urlUtility, 'updateHistory').mockImplementation(() => {});
    });

    afterEach(() => {
      setSearch(originalSearch);
      updateHistorySpy.mockRestore();
    });

    describe('when open becomes true', () => {
      beforeEach(async () => {
        createComponent({ open: false });
        updateHistorySpy.mockClear();
        await wrapper.setProps({ open: true });
      });

      it('writes ?show=workplan to history', () => {
        expect(updateHistorySpy).toHaveBeenCalledTimes(1);
        expect(updateHistorySpy.mock.calls[0][0].url).toMatch(/show=workplan/);
      });
    });

    describe('when open becomes false and the value still matches', () => {
      beforeEach(async () => {
        setSearch('?show=workplan');
        createComponent({ open: true });
        updateHistorySpy.mockClear();
        await wrapper.setProps({ open: false });
      });

      it('strips ?show=workplan', () => {
        expect(updateHistorySpy).toHaveBeenCalledTimes(1);
        expect(updateHistorySpy.mock.calls[0][0].url).not.toMatch(/show=/);
      });
    });

    describe('when open becomes false but another panel already overwrote the value', () => {
      beforeEach(async () => {
        setSearch('?show=workplan');
        createComponent({ open: true });
        setSearch('?show=eyJpaWQiOiI0NiJ9');
        updateHistorySpy.mockClear();
        await wrapper.setProps({ open: false });
      });

      it('does not strip ?show', () => {
        expect(updateHistorySpy).not.toHaveBeenCalled();
      });
    });

    describe('when opening with ?show=workplan already set', () => {
      beforeEach(async () => {
        setSearch('?show=workplan');
        createComponent({ open: false });
        updateHistorySpy.mockClear();
        await wrapper.setProps({ open: true });
      });

      it('does not push a duplicate history entry', () => {
        expect(updateHistorySpy).not.toHaveBeenCalled();
      });
    });

    describe('when mounting with open=false and ?show=workplan present', () => {
      // Regression test: when the page loads with ?show=workplan the panel
      // briefly mounts with open=false before the parent propagates
      // isPanelOpen=true. created() only ever adds the param (when open), so the
      // param is never stripped on initial mount, preventing a URL flap on load.
      beforeEach(() => {
        setSearch('?show=workplan');
        createComponent({ open: false });
      });

      it('does not strip ?show=workplan (prevents URL flap on load)', () => {
        expect(updateHistorySpy).not.toHaveBeenCalled();
      });
    });
  });

  describe('keyboard handling', () => {
    let addEventListenerSpy;
    let keydownHandler;

    beforeEach(() => {
      addEventListenerSpy = jest
        .spyOn(document, 'addEventListener')
        .mockImplementation((event, handler) => {
          if (event === 'keydown') keydownHandler = handler;
        });
    });

    afterEach(() => {
      addEventListenerSpy.mockRestore();
    });

    describe('when Escape is pressed while open', () => {
      beforeEach(() => {
        createComponent({ open: true });
        keydownHandler({ key: 'Escape' });
      });

      it('emits "close"', () => {
        expect(wrapper.emitted('close')).toHaveLength(1);
      });
    });

    describe('when Escape is pressed while closed', () => {
      beforeEach(() => {
        createComponent({ open: false });
        keydownHandler({ key: 'Escape' });
      });

      it('does nothing', () => {
        expect(wrapper.emitted('close')).toBeUndefined();
      });
    });

    describe('when a modal is open in the document', () => {
      beforeEach(() => {
        createComponent({ open: true });
        document.body.classList.add('modal-open');
        keydownHandler({ key: 'Escape' });
      });

      afterEach(() => {
        document.body.classList.remove('modal-open');
      });

      it('does not emit close', () => {
        expect(wrapper.emitted('close')).toBeUndefined();
      });
    });
  });
});
