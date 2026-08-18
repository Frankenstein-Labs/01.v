import { GlAvatar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoChatHeader from 'ee/ai/duo_agentic_chat/components/duo_chat_header.vue';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

describe('DuoChatHeader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoChatHeader, {
      propsData: {
        currentView: DUO_CHAT_VIEWS.CHAT,
        ...props,
      },
    });
  };

  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findAvatarSkeleton = () => wrapper.findByTestId('agent-avatar-skeleton');

  describe('agent avatar', () => {
    describe('when an agent id is provided', () => {
      beforeEach(() => {
        createComponent({
          agentId: 'gid://gitlab/Ai::Catalog::Item/123',
          agentAvatarUrl: 'https://example.com/security-agent.png',
        });
      });

      it('derives the avatar entity-id from the agent id and uses the agent avatar as src', () => {
        // GlAvatar identicon color is derived from entityId (entityId % 7 + 1), not entityName.
        expect(findAvatar().props('entityId')).toBe(123);
        expect(findAvatar().props('src')).toBe('https://example.com/security-agent.png');
      });

      it('does not render the skeleton loader', () => {
        expect(findAvatarSkeleton().exists()).toBe(false);
      });
    });

    describe('when no agent id is provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('shows the skeleton loader and hides the avatar', () => {
        expect(findAvatar().exists()).toBe(false);
        expect(findAvatarSkeleton().exists()).toBe(true);
      });
    });
  });
});
