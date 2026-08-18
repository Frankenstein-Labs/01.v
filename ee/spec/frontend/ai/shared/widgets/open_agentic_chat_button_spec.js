import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { openDuoChatWithAgent } from 'ee/ai/utils';
import {
  subscribeToEvent,
  DUO_CHAT_TOOL_COMPLETED_EVENT,
} from 'ee/ai/duo_agentic_chat/events/event_hub';
import OpenAgenticChatButton from 'ee/ai/shared/widgets/open_agentic_chat_button.vue';
import duoChatAvailableQuery from 'ee/ai/graphql/duo_chat_available.query.graphql';

jest.mock('ee/ai/utils', () => ({
  openDuoChatWithAgent: jest.fn(),
}));

jest.mock('ee/ai/duo_agentic_chat/events/event_hub', () => ({
  subscribeToEvent: jest.fn().mockReturnValue({ dispose: jest.fn() }),
  DUO_CHAT_TOOL_COMPLETED_EVENT: 'duo:tool-completed',
}));

Vue.use(VueApollo);

describe('OpenAgenticChatButton', () => {
  let wrapper;
  let duoChatAvailableHandler;

  const defaultProps = {
    buttonText: 'Set permissions with Duo',
    resourceId: 'gid://gitlab/User/1',
    agent: { name: 'Permissions Assistant' },
  };

  const duoChatAvailableResponse = (available = true) => ({
    data: {
      currentUser: {
        id: 'gid://gitlab/User/1',
        duoChatAvailable: available,
      },
    },
  });

  const createComponent = async (props = {}) => {
    wrapper = shallowMountExtended(OpenAgenticChatButton, {
      apolloProvider: createMockApollo([[duoChatAvailableQuery, duoChatAvailableHandler]]),
      propsData: { ...defaultProps, ...props },
    });

    await waitForPromises();
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(true));
  });

  describe('permissions', () => {
    it('renders the button when duoChatAvailable is true', async () => {
      await createComponent();

      expect(findButton().exists()).toBe(true);
    });

    it('does not render the button when duoChatAvailable is false', async () => {
      duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(false));
      await createComponent();

      expect(findButton().exists()).toBe(false);
    });

    it('does not render the button when the query errors', async () => {
      duoChatAvailableHandler = jest.fn().mockRejectedValue(new Error('network error'));
      await createComponent();

      expect(findButton().exists()).toBe(false);
    });
  });

  describe('rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders the buttonText', () => {
      expect(findButton().text()).toBe('Set permissions with Duo');
    });

    it('renders the tanuki-ai icon', () => {
      expect(findButton().props('icon')).toBe('tanuki-ai');
    });
  });

  describe('on click', () => {
    beforeEach(async () => {
      await createComponent({
        welcomeMessage: 'Welcome!',
        predefinedPrompts: ['Prompt one', 'Prompt two'],
      });
    });

    it('calls openDuoChatWithAgent with the correct arguments', async () => {
      await findButton().vm.$emit('click');

      expect(openDuoChatWithAgent).toHaveBeenCalledWith({
        agent: { name: 'Permissions Assistant' },
        resourceId: 'gid://gitlab/User/1',
        welcomeMessage: 'Welcome!',
        predefinedPrompts: ['Prompt one', 'Prompt two'],
        additionalContext: null,
      });
    });

    it('forwards additionalContext to openDuoChatWithAgent', async () => {
      const additionalContext = [
        { category: 'form_context', content: '{"form_id":"my-form"}', metadata: '{}' },
      ];
      await createComponent({
        welcomeMessage: 'Welcome!',
        predefinedPrompts: ['Prompt one', 'Prompt two'],
        additionalContext,
      });

      await findButton().vm.$emit('click');

      expect(openDuoChatWithAgent).toHaveBeenCalledWith(
        expect.objectContaining({ additionalContext }),
      );
    });

    it('does not auto-send a message', async () => {
      await findButton().vm.$emit('click');

      expect(openDuoChatWithAgent).not.toHaveBeenCalledWith(
        expect.objectContaining({ question: expect.anything() }),
      );
    });
  });

  describe('tool-completed event', () => {
    it('subscribes to the agentic chat event hub on mount', async () => {
      await createComponent();

      expect(subscribeToEvent).toHaveBeenCalledWith(
        DUO_CHAT_TOOL_COMPLETED_EVENT,
        expect.any(Function),
      );
    });

    it('unsubscribes from the agentic chat event hub on destroy', async () => {
      await createComponent();
      const { dispose } = subscribeToEvent.mock.results[0].value;
      wrapper.destroy();

      expect(dispose).toHaveBeenCalled();
    });

    it('emits tool-completed when the event hub fires', async () => {
      await createComponent();

      const payload = { name: 'some_tool', args: { key: 'value' } };
      const handler = subscribeToEvent.mock.calls.find(
        ([event]) => event === DUO_CHAT_TOOL_COMPLETED_EVENT,
      )[1];
      handler(payload);

      expect(wrapper.emitted('tool-completed')).toEqual([[payload]]);
    });
  });
});
