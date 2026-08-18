import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useConfigurePathHelpers } from 'helpers/configure_path_helpers';
import AgentFlowListItem from 'ee/ai/duo_agents_platform/components/common/agent_flow_list_item.vue';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { formatAgentStatus, formatAgentFlowTitle } from 'ee/ai/duo_agents_platform/utils';

jest.mock('~/lib/utils/datetime/timeago_utility');
jest.mock('ee/ai/duo_agents_platform/utils');

describe('AgentFlowListItem', () => {
  let wrapper;

  useConfigurePathHelpers();

  const mockTimeago = { format: jest.fn() };
  const mockRouterPush = jest.fn();

  const mockItem = {
    id: 'gid://gitlab/DuoWorkflow::Workflow/1',
    status: 'FINISHED',
    humanStatus: 'finished',
    updatedAt: '2024-01-01T00:00:00Z',
    workflowDefinition: 'software_development',
    project: {
      id: 'gid://gitlab/Project/1',
      name: 'Test Project',
      fullPath: 'group/project',
    },
  };

  beforeEach(() => {
    formatAgentStatus.mockReturnValue('Finished');
    formatAgentFlowTitle.mockReturnValue('Custom generated title');
    getTimeago.mockReturnValue(mockTimeago);
    mockTimeago.format.mockReturnValue('2 days ago');
    mockRouterPush.mockClear();
  });

  const findLink = () => wrapper.findComponent(GlLink);
  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);
  const findItemTitle = () => wrapper.findByTestId('item-title');
  const findItemStatus = () => wrapper.findByTestId('item-status');
  const findUpdatedAt = () => wrapper.findByTestId('item-updated-date');
  const findItemProject = () => wrapper.findByTestId('item-project');
  const findItemTitleText = () => wrapper.findByTestId('item-title').find('strong');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AgentFlowListItem, {
      propsData: {
        item: mockItem,
        ...props,
      },
      mocks: {
        $router: { push: mockRouterPush },
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  it('renders as a list item', () => {
    expect(wrapper.find('li').exists()).toBe(true);
  });

  it('renders the link with a real href to the session page', () => {
    expect(findLink().exists()).toBe(true);
    expect(findLink().attributes('href')).toContain('/group/project/-/automate/agent-sessions/1');
  });

  describe('click behavior', () => {
    it('calls $router.push with the session route on a normal click', () => {
      const event = { metaKey: false, ctrlKey: false, preventDefault: jest.fn() };
      findLink().vm.$emit('click', event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(mockRouterPush).toHaveBeenCalledWith({
        name: AGENTS_PLATFORM_SHOW_ROUTE,
        params: { id: 1 },
      });
    });

    it('does not call $router.push when metaKey is held (Cmd+click opens new tab)', () => {
      const event = { metaKey: true, ctrlKey: false, preventDefault: jest.fn() };
      findLink().vm.$emit('click', event);

      expect(event.preventDefault).not.toHaveBeenCalled();
      expect(mockRouterPush).not.toHaveBeenCalled();
    });

    it('does not call $router.push when ctrlKey is held (Ctrl+click opens new tab)', () => {
      const event = { metaKey: false, ctrlKey: true, shiftKey: false, preventDefault: jest.fn() };
      findLink().vm.$emit('click', event);

      expect(event.preventDefault).not.toHaveBeenCalled();
      expect(mockRouterPush).not.toHaveBeenCalled();
    });

    it('does not call $router.push when shiftKey is held (Shift+click opens new window)', () => {
      const event = { metaKey: false, ctrlKey: false, shiftKey: true, preventDefault: jest.fn() };
      findLink().vm.$emit('click', event);

      expect(event.preventDefault).not.toHaveBeenCalled();
      expect(mockRouterPush).not.toHaveBeenCalled();
    });
  });

  describe('when project fullPath is absent', () => {
    beforeEach(() => {
      createWrapper({
        item: { ...mockItem, project: { id: 'gid://gitlab/Project/1', name: 'Test Project' } },
      });
    });

    it('renders the link without an href', () => {
      expect(findLink().attributes('href')).toBeUndefined();
    });
  });

  it('renders the status icon with formatted human status', () => {
    expect(findStatusIcon().exists()).toBe(true);
    expect(findStatusIcon().props('humanStatus')).toBe('Finished');
  });

  describe('item title', () => {
    it('displays the formatted title', () => {
      expect(findItemTitle().text()).toContain('Custom generated title');
    });

    it('sets the tooltip to title with numeric id', () => {
      expect(findItemTitleText().attributes('title')).toBe('Custom generated title #1');
    });

    describe('when item has no title', () => {
      beforeEach(() => {
        formatAgentFlowTitle.mockReturnValue('Software development');
        createWrapper({ item: { ...mockItem, title: null } });
      });

      it('falls back to workflow definition', () => {
        expect(findItemTitle().text()).toContain('Software development');
      });
    });
  });

  describe('project info', () => {
    it('does not show project name by default', () => {
      expect(findItemProject().exists()).toBe(false);
    });

    describe('when showProjectInfo is true', () => {
      beforeEach(() => {
        createWrapper({ showProjectInfo: true });
      });

      it('shows the project name', () => {
        expect(findItemProject().text()).toBe('Test Project');
      });
    });
  });

  it('displays the formatted status', () => {
    expect(findItemStatus().text()).toBe('Finished');
  });

  it('displays the formatted updated time', () => {
    expect(findUpdatedAt().text()).toContain('2 days ago');
  });
});
