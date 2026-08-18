import { GlAttributeList, GlBadge, GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';
import AgentFlowTriggeredUser from 'ee/ai/duo_agents_platform/components/common/agent_flow_triggered_user.vue';
import TodoChecklist from 'ee/ai/duo_agents_platform/components/common/todo_checklist.vue';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { mockUser1, mockWorkItem, mockMergeRequest } from '../../../../mocks';

const buildTodoMessage = (todos) => ({
  toolInfo: JSON.stringify({ name: 'todo_write', args: { todos } }),
});

const mockTodos = [
  { status: 'completed', description: 'Read repository' },
  { status: 'in_progress', description: 'Extract logic' },
  { status: 'pending', description: 'Add tests' },
];

const mockDuoMessages = [buildTodoMessage(mockTodos)];

jest.mock('~/lib/utils/datetime/locale_dateformat');

describe('AgentFlowInfo', () => {
  let wrapper;

  const mockDateTimeFormatter = {
    format: jest.fn(),
  };

  beforeEach(() => {
    localeDateFormat.asDateTime = mockDateTimeFormatter;
    mockDateTimeFormatter.format.mockImplementation((date) => {
      if (date.toISOString() === '2023-01-01T00:00:00.000Z') {
        return 'Jan 1, 2023, 12:00 AM';
      }
      if (date.toISOString() === '2024-01-01T00:00:00.000Z') {
        return 'Jan 1, 2024, 12:00 AM';
      }
      return date.toISOString();
    });
  });

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(AgentFlowInfo, {
      propsData: {
        isLoading: false,
        status: 'RUNNING',
        humanStatus: 'Running',
        agentFlowDefinition: 'software_development',
        allExecutorUrls: ['https://gitlab.com/gitlab-org/gitlab/-/jobs/123'],
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
        user: mockUser1,
        canUpdateWorkflow: true,
        workItem: mockWorkItem,
        mergeRequest: mockMergeRequest,
        isSidePanelView: false,
        project: {
          id: 'gid://gitlab/Project/1',
          name: 'Test Project',
          fullPath: 'gitlab-org/test-project',
          webUrl: 'https://gitlab.com/gitlab-org/test-project',
          namespace: {
            id: 'gid://gitlab/Group/1',
            name: 'gitlab-org',
            webUrl: 'https://gitlab.com/gitlab-org',
          },
        },
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: { AgentFlowTriggeredUser: stubComponent(AgentFlowTriggeredUser) },
      mocks: {
        $route: {
          params: {
            id: '4545',
          },
        },
      },
    });
  };

  const findInfoList = () => wrapper.findComponent(GlAttributeList);
  const findListItems = () => wrapper.findComponent(GlAttributeList).props('items');
  const findRow = (label) => wrapper.findByTestId(`info-row-${label}`);
  const findListItemTitles = () => wrapper.findAllByTestId('info-title');
  const findListItemValues = () => wrapper.findAllByTestId('info-value');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-session-button');
  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findModelBadge = () => wrapper.findByTestId('model-badge');
  const findModelRow = () => findRow('Default model');
  const findTriggeredUser = () => wrapper.findComponent(AgentFlowTriggeredUser);
  const findAttributeListContainer = () => wrapper.findByTestId('attribute-list-container');
  const findAttributeListSection = () => wrapper.findByTestId('attribute-list-section');
  const findPlanSection = () => wrapper.findByTestId('plan-section');
  const findTodoChecklist = () => wrapper.findComponent(TodoChecklist);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true }, mountExtended);
    });

    it('renders the attribute list', () => {
      expect(findInfoList().exists()).toBe(true);
    });

    it('renders all session info items', () => {
      expect(findListItems()).toHaveLength(12);
    });

    it('displays the skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(12);
    });

    it('does not display placeholder N/A values', () => {
      expect(wrapper.text()).not.toContain('N/A');
    });
  });

  describe('info data', () => {
    beforeEach(() => {
      createComponent(
        { modelName: 'claude_sonnet_4_6', modelIdentifier: 'claude-sonnet-4-20250514' },
        mountExtended,
      );
    });

    it('renders all expected info values in the correct order', () => {
      const listItems = findListItemValues();
      const expectedData = [
        'software_development', // AI Item
        '4545', // Session ID
        'Flow', // Type
        'Test Project', // Project
        'gitlab-org', // Group
        `#42`, // Work item
        `!7`, // Merge request
        'Running', // Status
        'Jan 1, 2023, 12:00 AM', // Started
        'Jan 1, 2024, 12:00 AM', // Last updated
        '123', // Job IDs
        'claude_sonnet_4_6', // Default model
      ];

      expectedData.forEach((expectedText, index) => {
        expect(listItems.at(index).text()).toContain(expectedText);
      });
    });

    it('renders the status badge with the correct props', () => {
      const badge = findBadge();

      expect(badge.exists()).toBe(true);
      expect(badge.props()).toMatchObject({
        icon: 'play',
        iconSize: 'sm',
        variant: 'info',
      });
      expect(badge.text()).toBe('Running');
    });

    it('renders all the expected titles in the correct order', () => {
      const listItemTitles = findListItemTitles();
      const expectedTitles = [
        'AI Item',
        'Session ID',
        'Type',
        'Project',
        'Group',
        'Triggered by',
        'Work item',
        'Merge request',
        'Status',
        'Started',
        'Last updated',
        'Job IDs',
        'Default model',
      ];

      expectedTitles.forEach((expectedTitle, index) => {
        expect(listItemTitles.at(index).text()).toContain(expectedTitle);
      });
    });

    it.each`
      label              | href                                                               | text
      ${'Session ID'}    | ${'/gitlab-org/test-project/-/automate/agent-sessions/4545'}       | ${'4545'}
      ${'Project'}       | ${'https://gitlab.com/gitlab-org/test-project'}                    | ${'Test Project'}
      ${'Group'}         | ${'https://gitlab.com/gitlab-org'}                                 | ${'gitlab-org'}
      ${'Work item'}     | ${'https://gitlab.com/gitlab-org/test-project/-/work_items/42'}    | ${'#42'}
      ${'Merge request'} | ${'https://gitlab.com/gitlab-org/test-project/-/merge_requests/7'} | ${'!7'}
      ${'Job IDs'}       | ${'https://gitlab.com/gitlab-org/gitlab/-/jobs/123'}               | ${'123'}
    `('renders link for $label', ({ label, href, text }) => {
      const link = findRow(label).findComponent(GlLink);
      expect(link.attributes('href')).toBe(href);
      expect(link.text()).toBe(text);
    });

    describe('when work item is linked', () => {
      beforeEach(() => {
        createComponent({ workItem: mockWorkItem }, mountExtended);
      });

      it('renders the work item row with a link', () => {
        const workItemRow = findRow('Work item');
        expect(workItemRow.text()).toContain(`#${mockWorkItem.iid}`);
        expect(workItemRow.findComponent(GlLink).attributes('href')).toBe(mockWorkItem.webUrl);
      });
    });

    describe('when work item is not linked', () => {
      it('displays None for work item', () => {
        createComponent({ workItem: null }, mountExtended);
        expect(findRow('Work item').text()).toContain('None');
      });
    });

    describe('when merge request is linked', () => {
      beforeEach(() => {
        createComponent({ mergeRequest: mockMergeRequest }, mountExtended);
      });

      it('renders the merge request row with a link', () => {
        const mrRow = findRow('Merge request');
        expect(mrRow.text()).toContain(`!${mockMergeRequest.iid}`);
        expect(mrRow.findComponent(GlLink).attributes('href')).toBe(mockMergeRequest.webUrl);
      });
    });

    describe('when merge request is not linked', () => {
      it('displays None for merge request', () => {
        createComponent({ mergeRequest: null }, mountExtended);
        expect(findRow('Merge request').text()).toContain('None');
      });
    });

    describe('when project information is missing', () => {
      beforeEach(() => {
        createComponent({ project: {} }, mountExtended);
      });

      it('displays None for missing project information', () => {
        expect(findRow('Project').text()).toContain('None');
        expect(findRow('Group').text()).toContain('None');
      });

      it('does not display links for project, group, and sessionId', () => {
        expect(findRow('Session ID').findComponent(GlLink).exists()).toBe(false);
        expect(findRow('Project').findComponent(GlLink).exists()).toBe(false);
        expect(findRow('Group').findComponent(GlLink).exists()).toBe(false);
      });
    });

    describe('when project namespace is missing', () => {
      beforeEach(() => {
        createComponent(
          {
            project: {
              id: 'gid://gitlab/Project/1',
              name: 'Test Project',
              fullPath: 'gitlab-org/test-project',
              webUrl: 'https://gitlab.com/gitlab-org/test-project',
            },
          },
          mountExtended,
        );
      });

      it('displays None for missing namespace information', () => {
        expect(findRow('Project').text()).toContain('Test Project');
        expect(findRow('Group').text()).toContain('None');
      });

      it('displays project, sessionId, and executor links but not group link', () => {
        const links = findLinks();

        expect(links).toHaveLength(5);
        expect(links.at(0).attributes('href')).toBe(
          '/gitlab-org/test-project/-/automate/agent-sessions/4545',
        );
        expect(links.at(1).attributes('href')).toBe('https://gitlab.com/gitlab-org/test-project');
        expect(links.at(2).attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/test-project/-/work_items/42',
        );
        expect(links.at(3).attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/test-project/-/merge_requests/7',
        );
        expect(links.at(4).attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/gitlab/-/jobs/123',
        );
      });
    });

    describe('triggered by payload text', () => {
      const findTriggeredByItem = () =>
        wrapper.vm.payload.find((item) => item.type === 'triggeredUser');

      it.each`
        user         | expectedText
        ${mockUser1} | ${mockUser1.name}
        ${{}}        | ${'Unknown'}
        ${null}      | ${'Unknown'}
      `('sets text to "$expectedText" for user=$user', ({ user, expectedText }) => {
        createComponent({ user }, mountExtended);

        expect(findTriggeredByItem().text).toBe(expectedText);
      });
    });

    describe('job IDs payload text', () => {
      const findJobIdsItem = () => wrapper.vm.payload.find((item) => item.type === 'jobItems');

      it.each`
        allExecutorUrls                                                                                           | expectedText
        ${['https://gitlab.com/gitlab-org/gitlab/-/jobs/123']}                                                    | ${'123'}
        ${['https://gitlab.com/gitlab-org/gitlab/-/jobs/123', 'https://gitlab.com/gitlab-org/gitlab/-/jobs/456']} | ${'123, 456'}
        ${[]}                                                                                                     | ${'None'}
        ${['https://gitlab.com/invalid-url']}                                                                     | ${'None'}
      `(
        'sets text to "$expectedText" for $allExecutorUrls',
        ({ allExecutorUrls, expectedText }) => {
          createComponent({ allExecutorUrls }, mountExtended);

          expect(findJobIdsItem().text).toBe(expectedText);
        },
      );
    });

    describe('Model', () => {
      describe('when a model is available', () => {
        beforeEach(() => {
          createComponent(
            { modelName: 'claude_sonnet_4_6', modelIdentifier: 'claude-sonnet-4-20250514' },
            mountExtended,
          );
        });

        it('renders a pill with the model name', () => {
          expect(findModelBadge().exists()).toBe(true);
          expect(findModelBadge().text()).toBe('claude_sonnet_4_6');
        });

        it('exposes the model identifier as the pill tooltip', () => {
          expect(getBinding(findModelBadge().element, 'gl-tooltip').value).toBe(
            'claude-sonnet-4-20250514',
          );
        });
      });

      describe('when the model has no identifier', () => {
        beforeEach(() => {
          createComponent({ modelName: 'claude_sonnet_4_6', modelIdentifier: '' }, mountExtended);
        });

        it('still renders the model name pill', () => {
          expect(findModelBadge().exists()).toBe(true);
          expect(findModelBadge().text()).toBe('claude_sonnet_4_6');
        });

        it('does not set a tooltip', () => {
          expect(getBinding(findModelBadge().element, 'gl-tooltip').value).toBe('');
        });
      });

      describe('when no model is available', () => {
        beforeEach(() => {
          createComponent({ modelName: '' }, mountExtended);
        });

        it('does not render the Model row', () => {
          expect(findModelRow().exists()).toBe(false);
          expect(findModelBadge().exists()).toBe(false);
        });
      });
    });

    describe('when executor URL is invalid', () => {
      beforeEach(() => {
        createComponent({ allExecutorUrls: ['https://gitlab.com/invalid-url'] }, mountExtended);
      });

      it('does not display a link or job ID for an invalid URL', () => {
        expect(findRow('Job IDs').findComponent(GlLink).exists()).toBe(false);
        expect(findRow('Job IDs').text()).toContain('None');
      });
    });

    describe('when executor URL is empty', () => {
      beforeEach(() => {
        createComponent({ allExecutorUrls: [] }, mountExtended);
      });

      it('displays None for empty executor URL', () => {
        expect(findRow('Job IDs').text()).toContain('None');
      });
    });

    it('uses locale-aware date formatting', () => {
      expect(mockDateTimeFormatter.format).toHaveBeenCalledWith(new Date('2023-01-01T00:00:00Z'));
      expect(mockDateTimeFormatter.format).toHaveBeenCalledWith(new Date('2024-01-01T00:00:00Z'));
    });

    describe('when date values are invalid', () => {
      beforeEach(() => {
        mockDateTimeFormatter.format.mockClear();
        createComponent({ createdAt: null, updatedAt: 'invalid-date' }, mountExtended);
      });

      it('does not display if invalid dates', () => {
        expect(findRow('Started').exists()).toBe(false);
        expect(findRow('Last updated').exists()).toBe(false);
      });

      it('does not call the date formatter for invalid dates', () => {
        expect(mockDateTimeFormatter.format).not.toHaveBeenCalled();
      });
    });

    it('renders AgentFlowTriggeredUser component', () => {
      createComponent({}, mountExtended);
      expect(findTriggeredUser().exists()).toBe(true);
    });
  });

  describe('attribute list container style', () => {
    it('applies minWidth style when isSidePanelView is true', () => {
      createComponent({ isSidePanelView: true }, mountExtended);

      expect(findAttributeListContainer().attributes('style')).toBe('min-width: 30rem;');
    });

    it('does not apply minWidth style when isSidePanelView is false', () => {
      createComponent({ isSidePanelView: false }, mountExtended);

      expect(findAttributeListContainer().attributes('style')).toBeUndefined();
    });

    describe('when isSidePanelView is true', () => {
      beforeEach(() => {
        createComponent({ isSidePanelView: true }, mountExtended);
      });

      it('renders a top border on the attribute list section', () => {
        expect(findAttributeListSection().classes()).toContain('gl-border-t');
      });

      it('renders the top border with no plan section present', () => {
        expect(findPlanSection().exists()).toBe(false);
        expect(findAttributeListSection().classes()).toContain('gl-border-t');
      });
    });

    describe('when isSidePanelView is false', () => {
      beforeEach(() => {
        createComponent({ isSidePanelView: false }, mountExtended);
      });

      it('does not render a top border on the attribute list section', () => {
        expect(findAttributeListSection().classes()).not.toContain('gl-border-t');
      });
    });
  });

  describe('Cancel session button', () => {
    describe('when session can be cancelled', () => {
      it.each`
        status                           | description
        ${'CREATED'}                     | ${'created status'}
        ${'RUNNING'}                     | ${'running status'}
        ${'PAUSED'}                      | ${'paused status'}
        ${'INPUT_REQUIRED'}              | ${'input_required status'}
        ${'PLAN_APPROVAL_REQUIRED'}      | ${'plan_approval_required status'}
        ${'TOOL_CALL_APPROVAL_REQUIRED'} | ${'tool_call_approval_required status'}
      `('shows cancel button for $description', ({ status }) => {
        createComponent({ status });

        expect(findCancelButton().exists()).toBe(true);
        expect(findCancelButton().text()).toBe('Cancel session');
        expect(findCancelButton().props('variant')).toBe('danger');
        expect(findCancelButton().props('disabled')).toBe(false);
      });

      it('emits cancel-session event when clicked', async () => {
        createComponent({ status: 'RUNNING' });

        await findCancelButton().vm.$emit('click');

        expect(wrapper.emitted('cancel-session')).toHaveLength(1);
      });
    });

    describe('when session cannot be cancelled', () => {
      it.each`
        status        | description
        ${'FINISHED'} | ${'finished status'}
        ${'FAILED'}   | ${'failed status'}
      `('does not show cancel button for $description', ({ status }) => {
        createComponent({ status });

        expect(findCancelButton().exists()).toBe(false);
      });
    });

    describe('when user lacks permission to cancel', () => {
      beforeEach(() => {
        createComponent({ status: 'RUNNING', canUpdateWorkflow: false });
      });

      it('shows cancel button disabled', () => {
        expect(findCancelButton().exists()).toBe(true);
        expect(findCancelButton().props('disabled')).toBe(true);
      });
    });
  });

  describe('Plan section', () => {
    describe('when there are todo_write messages', () => {
      beforeEach(() => {
        createComponent({ duoMessages: mockDuoMessages });
      });

      it('renders the Plan section', () => {
        expect(findPlanSection().exists()).toBe(true);
      });

      it('renders the Agent todos heading', () => {
        expect(wrapper.findByTestId('todos-heading').text()).toBe('Agent todos');
      });

      it('renders the completed count out of the total in the header', () => {
        expect(wrapper.findByTestId('todo-progress-summary').text()).toBe('1 of 3');
      });

      it('passes the latest todo tool info to TodoChecklist', () => {
        expect(findTodoChecklist().props('toolInfo')).toMatchObject({
          name: 'todo_write',
          args: { todos: mockTodos },
        });
      });

      it('renders the TodoChecklist without a border', () => {
        expect(findTodoChecklist().props('bordered')).toBe(false);
      });

      it('does not render a top border on the plan section', () => {
        expect(findPlanSection().classes()).not.toContain('gl-border-t');
      });
    });

    describe('when rendered in the side panel', () => {
      beforeEach(() => {
        createComponent({ duoMessages: mockDuoMessages, isSidePanelView: true });
      });

      it('renders a top border on the plan section', () => {
        expect(findPlanSection().classes()).toContain('gl-border-t');
      });
    });

    describe('when multiple todo_write messages exist', () => {
      const laterTodos = [{ status: 'completed', description: 'All done' }];

      beforeEach(() => {
        createComponent({
          duoMessages: [buildTodoMessage(mockTodos), buildTodoMessage(laterTodos)],
        });
      });

      it('passes the latest todo state to TodoChecklist', () => {
        expect(findTodoChecklist().props('toolInfo').args.todos).toEqual(laterTodos);
      });
    });

    describe('when there are no todo_write messages', () => {
      beforeEach(() => {
        createComponent({ duoMessages: [] });
      });

      it('does not render the Plan section', () => {
        expect(findPlanSection().exists()).toBe(false);
      });

      it('does not render the TodoChecklist', () => {
        expect(findTodoChecklist().exists()).toBe(false);
      });
    });

    describe.each`
      status        | flowFinished
      ${'RUNNING'}  | ${false}
      ${'FINISHED'} | ${true}
      ${'FAILED'}   | ${true}
      ${'STOPPED'}  | ${true}
    `('when the session status is $status', ({ status, flowFinished }) => {
      beforeEach(() => {
        createComponent({ status, duoMessages: mockDuoMessages });
      });

      it(`passes flowFinished=${flowFinished} to TodoChecklist`, () => {
        expect(findTodoChecklist().props('flowFinished')).toBe(flowFinished);
      });
    });
  });
});
