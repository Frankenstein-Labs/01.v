import { GlAvatar, GlAvatarLink, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useConfigurePathHelpers } from 'helpers/configure_path_helpers';
import AgentSessionRow from 'ee/ai/shared/widgets/agent_session_row.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { buildSession, mockUser1 } from 'ee_jest/ai/mocks';

describe('AgentSessionRow', () => {
  let wrapper;

  useConfigurePathHelpers();

  const createComponent = (session, props = {}) => {
    wrapper = shallowMountExtended(AgentSessionRow, {
      propsData: { session, ...props },
    });
  };

  const findTitle = () => wrapper.findByTestId('session-title');
  const findSessionId = () => wrapper.findByTestId('session-id');
  const findSessionIdLink = () => wrapper.findComponent(GlLink);
  const findViewDetailsButton = () => wrapper.findByTestId('session-view-details-button');
  const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);
  const findAvatarLink = () => wrapper.findComponent(GlAvatarLink);
  const findAvatar = () => wrapper.findComponent(GlAvatar);

  describe('session ID', () => {
    it('renders the numeric id as a link when project fullPath is available', () => {
      createComponent(buildSession());

      expect(findSessionIdLink().text()).toBe('#1');
    });

    it('renders the id as plain text when project fullPath is not available', () => {
      createComponent(buildSession({ project: null }));

      expect(findSessionIdLink().exists()).toBe(false);
      expect(findSessionId().text()).toBe('#1');
    });
  });

  describe('workflow definition', () => {
    it('humanizes the workflowDefinition', () => {
      createComponent(buildSession());

      expect(findTitle().text()).toBe('Planner');
    });
  });

  describe('updated at', () => {
    it('renders TimeAgoTooltip when updatedAt is present', () => {
      createComponent(buildSession());

      expect(findTimeAgoTooltip().props('time')).toBe('2026-01-15T10:00:00Z');
    });

    it('does not render TimeAgoTooltip when updatedAt is absent', () => {
      createComponent(buildSession({ updatedAt: null }));

      expect(findTimeAgoTooltip().exists()).toBe(false);
    });
  });

  describe('"View details" button', () => {
    it('renders as a confirm/tertiary link to the session URL when showViewDetails is true', () => {
      createComponent(buildSession(), { showViewDetails: true });

      expect(findViewDetailsButton().exists()).toBe(true);
      expect(findViewDetailsButton().text()).toBe('View details');
      expect(findViewDetailsButton().attributes('variant')).toBe('confirm');
      expect(findViewDetailsButton().attributes('category')).toBe('tertiary');
      expect(findViewDetailsButton().attributes('href')).toContain('group/project');
    });

    it('does not render when project fullPath is absent', () => {
      createComponent(buildSession({ project: null }), { showViewDetails: true });

      expect(findViewDetailsButton().exists()).toBe(false);
    });

    it('does not render when showViewDetails is false', () => {
      createComponent(buildSession());

      expect(findViewDetailsButton().exists()).toBe(false);
    });
  });

  describe('user avatar', () => {
    it('renders GlAvatarLink with the correct attributes', () => {
      createComponent(buildSession({ user: mockUser1 }));

      expect(findAvatarLink().attributes('href')).toBe(mockUser1.webPath);
      expect(findAvatarLink().attributes('title')).toBe(mockUser1.name);
      expect(findAvatarLink().attributes('data-username')).toBe(mockUser1.username);
      expect(findAvatarLink().attributes('data-user-id')).toBe('1');
    });

    it('renders GlAvatar with the correct props', () => {
      createComponent(buildSession({ user: mockUser1 }));

      expect(findAvatar().props('src')).toBe(mockUser1.avatarUrl);
      expect(findAvatar().props('entityName')).toBe(mockUser1.name);
      expect(findAvatar().props('size')).toBe(16);
    });

    it('does not render when user is absent', () => {
      createComponent(buildSession());

      expect(findAvatarLink().exists()).toBe(false);
    });
  });
});
