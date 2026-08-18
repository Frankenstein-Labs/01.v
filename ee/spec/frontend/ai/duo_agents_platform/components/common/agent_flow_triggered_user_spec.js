import { shallowMount } from '@vue/test-utils';
import { GlAvatarLink } from '@gitlab/ui';
import AgentFlowTriggeredUser from 'ee/ai/duo_agents_platform/components/common/agent_flow_triggered_user.vue';
import { getBinding, createMockDirective } from 'helpers/vue_mock_directive';
import { mockUser1 } from '../../../mocks';

describe('AgentFlowTriggeredUser', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AgentFlowTriggeredUser, {
      propsData: {
        user: mockUser1,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findAvatarLink = () => wrapper.findComponent(GlAvatarLink);

  describe('when rendered', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders avatar link with correct attributes', () => {
      expect(findAvatarLink().attributes()).toEqual(
        expect.objectContaining({
          href: mockUser1.webUrl,
          'data-username': mockUser1.username,
        }),
      );
    });

    it('renders username with @ symbol', () => {
      expect(wrapper.text()).toContain(`@${mockUser1.username}`);
    });

    it('renders avatar link with tooltip', () => {
      const avatarLink = findAvatarLink();
      const tooltip = getBinding(avatarLink.element, 'gl-tooltip');

      expect(tooltip).toBeDefined();
      expect(tooltip.modifiers.bottom).toBe(true);
      expect(avatarLink.attributes('title')).toBe(mockUser1.name);
    });
  });

  describe('when user is empty', () => {
    beforeEach(() => {
      createWrapper({ user: {} });
    });

    it('renders avatar link with empty attributes', () => {
      expect(findAvatarLink().attributes()).toEqual(
        expect.objectContaining({
          href: '',
          'data-username': '',
        }),
      );
    });
  });
});
