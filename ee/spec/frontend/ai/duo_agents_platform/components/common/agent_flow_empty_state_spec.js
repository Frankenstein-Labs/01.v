import { GlLink, GlSprintf } from '@gitlab/ui';
import { DuoChatContextConversation as DuoChatConversation } from '@gitlab/duo-ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentFlowEmptyState from 'ee/ai/duo_agents_platform/components/common/agent_flow_empty_state.vue';
import { AGENT_PLATFORM_SESSION_RETENTION_LENGTH } from 'ee/ai/duo_agents_platform/constants';
import { mockUser1 } from '../../../mocks';

describe('AgentFlowEmptyState', () => {
  let wrapper;

  const defaultProps = {
    createdAt: '2024-01-01T00:00:00Z',
    hasLogs: false,
    updatedAt: '2024-01-15T00:00:00Z',
    status: '',
    user: mockUser1,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AgentFlowEmptyState, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findRetentionMessage = () => wrapper.find('[data-testid="retention-message-container"]');
  const findLearnMoreLink = () => wrapper.findComponent(GlLink);
  const findChatConversation = () => wrapper.findComponent(DuoChatConversation);

  describe('retention message', () => {
    beforeEach(() => {
      const oldDate = new Date();
      oldDate.setDate(oldDate.getDate() - (AGENT_PLATFORM_SESSION_RETENTION_LENGTH + 1));

      createComponent({
        updatedAt: oldDate.toISOString(),
        hasLogs: false,
      });
    });

    it('displays retention message when outside retention period and no logs', () => {
      const retentionMessage = findRetentionMessage();
      expect(retentionMessage.exists()).toBe(true);
      expect(retentionMessage.text()).toContain('Activity deleted after 30 days of inactivity');
    });

    it('displays learn more link', () => {
      expect(findRetentionMessage().text()).toContain('Learn more');
      expect(findLearnMoreLink().attributes()).toMatchObject({
        href: expect.stringContaining('sessions'),
        target: '_blank',
      });
    });

    it('does not render the chat conversation', () => {
      expect(findChatConversation().exists()).toBe(false);
    });
  });

  describe('within retention period', () => {
    describe('when creating session', () => {
      beforeEach(() => {
        createComponent({ hasLogs: false, status: '' });
      });

      it('renders DuoChatConversation', () => {
        expect(findChatConversation().exists()).toBe(true);
      });

      it('passes creating session message as chat bubble', () => {
        const messages = findChatConversation().props('messages');

        expect(messages).toHaveLength(1);
        expect(messages[0]).toMatchObject({
          message_type: 'agent',
          role: 'system',
          requestId: 'creating-session',
          status: 'success',
        });
      });

      it('disables feedback, code insertion, and delimiter', () => {
        expect(findChatConversation().props('showDelimiter')).toBe(false);
        expect(findChatConversation().props('withFeedback')).toBe(false);
        expect(findChatConversation().props('enableCodeInsertion')).toBe(false);
      });
    });

    describe('when starting job', () => {
      beforeEach(() => {
        createComponent({ hasLogs: false, status: 'RUNNING' });
      });

      it('renders both the created session and starting job messages', () => {
        const messages = findChatConversation().props('messages');

        expect(messages).toHaveLength(2);
        expect(messages[1].requestId).toBe('starting-job');
      });
    });

    describe('when session is created with logs', () => {
      beforeEach(() => {
        createComponent({ hasLogs: true, status: 'SUCCESS' });
      });

      it('renders DuoChatConversation with created session message including user name', () => {
        const messages = findChatConversation().props('messages');

        expect(messages).toHaveLength(1);
        expect(messages[0]).toMatchObject({
          requestId: 'created-session',
          message_type: 'agent',
          status: 'success',
        });
        expect(messages[0].content).toContain(mockUser1.name);
      });
    });

    describe('when session failed without logs', () => {
      beforeEach(() => {
        createComponent({ hasLogs: false, status: 'FAILED' });
      });

      it('renders DuoChatConversation with only the created session message', () => {
        const messages = findChatConversation().props('messages');

        expect(messages).toHaveLength(1);
        expect(messages[0].requestId).toBe('created-session');
      });
    });
  });
});
