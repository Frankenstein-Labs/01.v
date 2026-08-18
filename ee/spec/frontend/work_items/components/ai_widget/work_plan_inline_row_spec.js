import { GlButtonGroup, GlDisclosureDropdown, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import WorkPlanInlineRow from 'ee/work_items/components/ai_widget/work_plan_inline_row.vue';
import WorkPlanStatusBar from 'ee/work_items/components/ai_widget/work_plan_status_bar.vue';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import DuoWorkItemToMrAction from 'ee/ai/shared/widgets/duo_work_item_to_mr_action.vue';

describe('WorkPlanInlineRow', () => {
  let wrapper;

  const duoMrActionProps = {
    projectPath: 'group/project',
    workItemIid: '42',
    workItemType: 'Epic',
    workItemWebUrl: '/group/project/-/work_items/42',
    runDuoDeveloperInChat: true,
    generateMrButtonOptions: { size: 'medium', variant: 'confirm', category: 'primary' },
  };

  const duoMrActionComponentProps = {
    hasContent: true,
    canUpdate: true,
    hasRemoteFlowsEnabled: true,
    ...duoMrActionProps,
  };

  const defaultProps = {
    workItemId: 'gid://gitlab/WorkItem/1',
  };

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(WorkPlanInlineRow, {
      propsData: { ...defaultProps, ...props },
      provide: { glFeatures: {}, ...provide },
      stubs: { DuoWorkItemToMrAction: true, HelpPopover, GlSprintf },
    });
  };

  const findRow = () => wrapper.findByTestId('work-plan-inline-row');
  const findOpenButton = () => wrapper.findComponentByTestId('open-work-plan-button');
  const findDuoWorkItemToMrAction = () => wrapper.findComponent(DuoWorkItemToMrAction);
  const findDivider = () => wrapper.findByTestId('duo-divider');
  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDuoChatAction = () => wrapper.findComponent(DuoChatQuickAction);
  const findHelpPopover = () => wrapper.findComponent(HelpPopover);
  const findHelpPopoverLink = () => findHelpPopover().findComponent(GlLink);
  const findWorkPlanStatusBar = () => wrapper.findComponent(WorkPlanStatusBar);

  describe('help popover', () => {
    it('is shown before a workplan exists', () => {
      createComponent({ hasContent: false });
      expect(findHelpPopover().exists()).toBe(true);
    });

    it('is hidden once a workplan exists', () => {
      createComponent({ hasContent: true });
      expect(findHelpPopover().exists()).toBe(false);
    });

    it('explains what a workplan is and links to the docs', () => {
      createComponent({ hasContent: false });
      expect(findHelpPopover().props('options').title).toBe('What is a workplan?');
      expect(findHelpPopover().text()).toContain('breaks a work item into clear, ordered steps');
      expect(findHelpPopoverLink().text()).toBe('Learn more');
      expect(findHelpPopoverLink().attributes('href')).toBe('/help/user/work_items/workplan');
    });
  });

  describe('status label', () => {
    describe('when there is no content', () => {
      describe('and user can update', () => {
        beforeEach(() => {
          createComponent({ hasContent: false, canUpdate: true });
        });

        it('shows "Not yet created"', () => {
          expect(findRow().text()).toContain('Workplan');
          expect(findRow().text()).toContain('Not yet created');
        });
      });

      describe('and user cannot update', () => {
        beforeEach(() => {
          createComponent({ hasContent: false, canUpdate: false });
        });

        it('shows "No workplan"', () => {
          expect(findRow().text()).toContain('No workplan');
        });
      });
    });

    describe('when there is content', () => {
      beforeEach(() => {
        createComponent({ hasContent: true, canUpdate: true });
      });

      it('shows "Ready for review"', () => {
        expect(findRow().text()).toContain('Ready for review');
      });
    });
  });

  describe('create actions (empty state)', () => {
    describe('when user cannot update', () => {
      beforeEach(() => {
        createComponent({ hasContent: false, canUpdate: false });
      });

      it('does not show a create action', () => {
        expect(findOpenButton().exists()).toBe(false);
        expect(findButtonGroup().exists()).toBe(false);
      });
    });
  });

  describe('Split button with dropdown', () => {
    describe('when there is no content and user can update', () => {
      beforeEach(() => {
        createComponent({
          hasContent: false,
          canUpdate: true,
        });
      });

      it('shows the button group', () => {
        expect(findButtonGroup().exists()).toBe(true);
      });

      it('shows the disclosure dropdown', () => {
        expect(findDisclosureDropdown().exists()).toBe(true);
      });

      it('dropdown contains "Create manually" option', () => {
        const dropdownItems = findDisclosureDropdown().props('items');
        expect(dropdownItems).toHaveLength(1);
        expect(dropdownItems[0].text).toBe('Create manually');
      });

      it('emits "open" when dropdown action is triggered', async () => {
        await findDisclosureDropdown().vm.$emit('action');
        expect(wrapper.emitted('open')).toHaveLength(1);
      });
    });

    describe('when content exists', () => {
      beforeEach(() => {
        createComponent({
          hasContent: true,
          canUpdate: true,
          workItemId: 'gid://gitlab/WorkItem/1',
        });
      });

      it('does not show the split button', () => {
        expect(findButtonGroup().exists()).toBe(false);
      });
    });
  });

  describe('View toggle button', () => {
    describe('when content exists', () => {
      beforeEach(() => {
        createComponent({ hasContent: true, canUpdate: true });
      });

      it('shows "View" button', () => {
        expect(findOpenButton().text()).toBe('View');
      });

      it('emits "open" when clicked', async () => {
        await findOpenButton().vm.$emit('click');
        expect(wrapper.emitted('open')).toHaveLength(1);
      });
    });

    describe('when user cannot update', () => {
      beforeEach(() => {
        createComponent({ hasContent: true, canUpdate: false });
      });

      it('still shows the button (read-only viewers can view)', () => {
        expect(findOpenButton().exists()).toBe(true);
      });
    });

    describe('when panel is open', () => {
      beforeEach(() => {
        createComponent({ hasContent: true, isPanelOpen: true });
      });

      it('reflects the panel-open state via aria-pressed', () => {
        expect(findOpenButton().attributes('aria-pressed')).toBe('true');
      });
    });
  });

  describe('Duo actions', () => {
    describe('when content is missing', () => {
      beforeEach(() => {
        createComponent({
          hasContent: false,
          canUpdate: true,
          workItemId: 'gid://gitlab/WorkItem/1',
        });
      });

      it('shows Generate-workplan chat action', () => {
        expect(findDuoChatAction().exists()).toBe(true);
      });

      it('does not show Generate-MR action', () => {
        expect(findDuoWorkItemToMrAction().exists()).toBe(false);
      });

      it('emits "open-chat-request" when DuoChatQuickAction is clicked', async () => {
        await findDuoChatAction().vm.$emit('click');
        expect(wrapper.emitted('open-chat-request')).toHaveLength(1);
      });

      it('emits "open-chat-completed" when DuoChatQuickAction emits "chat-opened"', async () => {
        await findDuoChatAction().vm.$emit('chat-opened');
        expect(wrapper.emitted('open-chat-completed')).toHaveLength(1);
        expect(wrapper.emitted('open')).toBeUndefined();
      });
    });

    describe('when content exists', () => {
      describe('and remote flows are enabled', () => {
        beforeEach(() => {
          createComponent({
            ...duoMrActionComponentProps,
            canUpdate: true,
            workItemId: 'gid://gitlab/WorkItem/1',
          });
        });

        it('does not show Generate-workplan chat action', () => {
          expect(findDuoChatAction().exists()).toBe(false);
        });

        it('shows Generate-MR action', () => {
          expect(findDuoWorkItemToMrAction().exists()).toBe(true);
        });

        it('passes correct props to Generate-MR action', () => {
          expect(findDuoWorkItemToMrAction().props()).toMatchObject({
            ...duoMrActionProps,
          });
        });
      });

      describe('and remote flows are disabled', () => {
        beforeEach(() => {
          createComponent({
            hasContent: true,
            canUpdate: true,
            workItemId: 'gid://gitlab/WorkItem/1',
            hasRemoteFlowsEnabled: false,
          });
        });

        it('does not show Generate-workplan button', () => {
          expect(wrapper.findByTestId('inline-generate-with-duo-button').exists()).toBe(false);
        });

        it('does not show Generate-MR action', () => {
          expect(findDuoWorkItemToMrAction().exists()).toBe(false);
        });
      });
    });
  });

  describe('Duo "Generate MR" button', () => {
    describe('when content exists and remote flows are enabled', () => {
      beforeEach(() => {
        createComponent(duoMrActionComponentProps);
      });

      it('is shown', () => {
        expect(findDuoWorkItemToMrAction().exists()).toBe(true);
      });

      it('passes correct props', () => {
        expect(findDuoWorkItemToMrAction().props()).toMatchObject({
          ...duoMrActionProps,
        });
      });
    });

    describe('when content is empty', () => {
      beforeEach(() => {
        createComponent({
          hasContent: false,
          hasRemoteFlowsEnabled: true,
        });
      });

      it('is not shown', () => {
        expect(findDuoWorkItemToMrAction().exists()).toBe(false);
      });
    });

    describe('when remote flows are disabled', () => {
      beforeEach(() => {
        createComponent({
          hasContent: true,
          hasRemoteFlowsEnabled: false,
        });
      });

      it('is not shown', () => {
        expect(findDuoWorkItemToMrAction().exists()).toBe(false);
      });
    });

    describe('when user cannot update', () => {
      beforeEach(() => {
        createComponent({
          hasContent: true,
          canUpdate: false,
          hasRemoteFlowsEnabled: true,
        });
      });

      it('is not shown', () => {
        expect(findDuoWorkItemToMrAction().exists()).toBe(false);
      });
    });

    it('passes correct props', () => {
      createComponent({
        hasContent: true,
        canUpdate: true,
        hasRemoteFlowsEnabled: true,
        projectPath: 'group/project',
        workItemIid: '42',
        workItemType: 'Epic',
        workItemWebUrl: '/group/project/-/work_items/42',
      });
      expect(findDuoWorkItemToMrAction().props()).toMatchObject({
        projectPath: 'group/project',
        workItemIid: '42',
        workItemType: 'Epic',
        workItemWebUrl: '/group/project/-/work_items/42',
        runDuoDeveloperInChat: true,
      });
    });
  });

  describe('divider', () => {
    describe.each`
      scenario                                                      | props                                                                                    | shouldShow
      ${'there is no plan and only the create actions are visible'} | ${{ hasContent: false, canUpdate: true, workItemId: 'gid://gitlab/WorkItem/1' }}         | ${false}
      ${'"Generate MR" button is visible'}                          | ${{ hasContent: true, canUpdate: true, hasRemoteFlowsEnabled: true, workItemIid: '1' }}  | ${true}
      ${'user cannot update (Generate MR hidden)'}                  | ${{ hasContent: true, canUpdate: false, hasRemoteFlowsEnabled: true, workItemIid: '1' }} | ${false}
      ${'neither Duo button is visible'}                            | ${{ hasContent: false, canUpdate: false, hasRemoteFlowsEnabled: false }}                 | ${false}
    `('when $scenario', ({ props, shouldShow }) => {
      beforeEach(() => {
        createComponent(props);
      });

      it(`is ${shouldShow ? 'shown' : 'hidden'}`, () => {
        expect(findDivider().exists()).toBe(shouldShow);
      });
    });
  });

  describe('signal bar', () => {
    describe('when content exists', () => {
      beforeEach(() => {
        createComponent({ hasContent: true });
      });

      it('uses the success variant', () => {
        expect(findWorkPlanStatusBar().props('variant')).toBe('success');
      });

      it('labels the bar with the status', () => {
        expect(findWorkPlanStatusBar().attributes('aria-label')).toBe('Ready for review');
      });
    });

    describe('when content is missing', () => {
      beforeEach(() => {
        createComponent({ hasContent: false });
      });

      it('uses the neutral variant', () => {
        expect(findWorkPlanStatusBar().props('variant')).toBe('neutral');
      });
    });
  });
});
