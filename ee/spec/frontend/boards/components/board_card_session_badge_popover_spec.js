import { GlPopover, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BoardCardSessionBadgePopover from 'ee/boards/components/board_card_session_badge_popover.vue';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';
import {
  buildSession,
  FINISHED_SESSION,
  RUNNING_SESSION,
  SESSION_WITHOUT_PROJECT,
} from './board_card_session_badge_mock_data';

describe('BoardCardSessionBadgePopover', () => {
  let wrapper;

  const defaultProps = {
    target: 'session-badge-1',
    sessions: [FINISHED_SESSION, RUNNING_SESSION],
    isLoading: false,
    queryError: false,
    hasNextPage: false,
    displayCount: '2',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(BoardCardSessionBadgePopover, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findPopover = () => wrapper.findComponent(GlPopover);
  const findSessionRows = () => wrapper.findAllByTestId('popover-session-row');
  const findSessionLinks = () => wrapper.findAllComponentsByTestId('popover-session-link');
  const findSessionDefinitions = () => wrapper.findAllByTestId('popover-session-definition');
  const findSessionStatuses = () => wrapper.findAllByTestId('popover-session-status');
  const findAgentStatusIcons = () => wrapper.findAllComponents(AgentStatusIcon);
  const findViewAllLink = () => wrapper.findComponentByTestId('popover-view-all-link');

  describe('popover wiring', () => {
    beforeEach(() => {
      createComponent();
    });

    it('targets the provided ID with click trigger', () => {
      expect(findPopover().props('target')).toBe('session-badge-1');
      expect(findPopover().props('triggers')).toBe('click blur');
    });
  });

  describe('with sessions loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a row per session with correct details', () => {
      expect(findSessionRows()).toHaveLength(2);

      expect(findSessionLinks().at(0).text()).toBe('#1');
      expect(findSessionLinks().at(1).text()).toBe('#2');

      expect(findSessionDefinitions().at(0).text()).toBe('Planner');
      expect(findSessionDefinitions().at(1).text()).toBe('Developer');

      expect(findSessionStatuses().at(0).text()).toBe('Completed');
      expect(findSessionStatuses().at(1).text()).toBe('Running');

      expect(findAgentStatusIcons().at(0).props('status')).toBe('FINISHED');
      expect(findAgentStatusIcons().at(1).props('status')).toBe('RUNNING');
    });

    it('emits show-session with the session object on link click', () => {
      findSessionLinks().at(0).vm.$emit('click', { preventDefault: jest.fn() });

      expect(wrapper.emitted('show-session')[0]).toEqual([FINISHED_SESSION]);
    });

    it('emits view-all on "View all sessions" click', () => {
      findViewAllLink().vm.$emit('click', { preventDefault: jest.fn() });

      expect(wrapper.emitted('view-all')).toHaveLength(1);
    });

    it('renders the "View all sessions" footer link', () => {
      expect(findViewAllLink().text()).toBe('View all sessions');
    });
  });

  describe('with a session without a project', () => {
    beforeEach(() => {
      createComponent({ sessions: [SESSION_WITHOUT_PROJECT], displayCount: '1' });
    });

    it('still renders the session ID as a clickable link', () => {
      expect(findSessionLinks()).toHaveLength(1);
      expect(findSessionLinks().at(0).text()).toBe('#6');
    });
  });

  describe('when hasNextPage is true', () => {
    beforeEach(() => {
      const nodes = Array.from({ length: 5 }, (_, i) =>
        buildSession({ id: `gid://gitlab/Ai::DuoWorkflows::Workflow/${i + 1}` }),
      );
      createComponent({ sessions: nodes, hasNextPage: true, displayCount: '5+' });
    });

    it('shows "Showing most recent 5" in the footer', () => {
      expect(wrapper.findByTestId('popover-showing-first').text()).toContain(
        'Showing most recent 5',
      );
    });
  });

  describe('when hasNextPage is false', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not show "Showing first" text', () => {
      expect(wrapper.findByTestId('popover-showing-first').exists()).toBe(false);
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true, sessions: [] });
    });

    it('shows a skeleton loader', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('does not show session rows', () => {
      expect(findSessionRows()).toHaveLength(0);
    });
  });

  describe('when query errored', () => {
    beforeEach(() => {
      createComponent({ queryError: true, sessions: [] });
    });

    it('shows error message', () => {
      expect(wrapper.findByTestId('popover-error').text()).toContain("Couldn't load sessions.");
    });

    it('shows a retry button that emits retry', async () => {
      const retryButton = wrapper.findComponent(GlButton);

      expect(retryButton.text()).toBe('Retry');

      await retryButton.vm.$emit('click');

      expect(wrapper.emitted('retry')).toHaveLength(1);
    });
  });
});
