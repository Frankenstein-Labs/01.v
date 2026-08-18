import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { InternalEvents } from '~/tracking';
import { eventHub, QUEUE_CHAT_COMMAND, SHOW_NEW_CHAT } from 'ee/ai/events/panel';
import {
  subscribeToEvent,
  DUO_CHAT_TOOL_COMPLETED_EVENT,
} from 'ee/ai/duo_agentic_chat/events/event_hub';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import duoChatAvailableQuery from 'ee/ai/graphql/duo_chat_available.query.graphql';

jest.mock('ee/ai/events/panel', () => {
  const actual = jest.requireActual('ee/ai/events/panel');
  return {
    ...actual,
    eventHub: { $emit: jest.fn(), $on: jest.fn(), $off: jest.fn() },
  };
});

jest.mock('ee/ai/duo_agentic_chat/events/event_hub', () => ({
  subscribeToEvent: jest.fn().mockReturnValue({ dispose: jest.fn() }),
  DUO_CHAT_TOOL_COMPLETED_EVENT: 'duo:tool-completed',
}));

Vue.use(VueApollo);

describe('DuoChatQuickAction', () => {
  let wrapper;
  let trackEventSpy;
  let duoChatAvailableHandler;

  const defaultProps = {
    buttonText: 'Test Action',
    resourceId: 'gid://gitlab/Issue/1',
    trackingInfo: { label: 'test_label' },
    command: { agenticPrompt: 'do something' },
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
    wrapper = shallowMountExtended(DuoChatQuickAction, {
      apolloProvider: createMockApollo([[duoChatAvailableQuery, duoChatAvailableHandler]]),
      propsData: { ...defaultProps, ...props },
    });

    await waitForPromises();
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    trackEventSpy = jest.spyOn(InternalEvents, 'trackEvent').mockImplementation(() => {});
    duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(true));
  });

  describe('permissions', () => {
    describe('when duoChatAvailable is true', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('renders the button', () => {
        expect(findButton().exists()).toBe(true);
      });
    });

    describe('when duoChatAvailable is false', () => {
      beforeEach(async () => {
        duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(false));

        await createComponent();
      });

      it('does not render the button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when the query errors', () => {
      beforeEach(async () => {
        duoChatAvailableHandler = jest.fn().mockRejectedValue(new Error('network error'));

        await createComponent();
      });

      it('does not render the button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });

  describe('rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders a GlButton with the provided buttonText', () => {
      expect(findButton().text()).toBe('Test Action');
    });

    it('renders the tanuki-ai icon', () => {
      expect(findButton().props('icon')).toBe('tanuki-ai');
    });
  });

  describe('props validation', () => {
    describe('trackingInfo validator', () => {
      const { validator } = DuoChatQuickAction.props.trackingInfo;

      it.each`
        label                 | valid
        ${'two_words'}        | ${true}
        ${'three_snake_case'} | ${true}
        ${'single'}           | ${false}
        ${'camelCase'}        | ${false}
        ${'With_upper'}       | ${false}
        ${'trailing_'}        | ${false}
      `('returns $valid for label "$label"', ({ label, valid }) => {
        expect(validator({ label })).toBe(valid);
      });
    });

    describe('command validator', () => {
      const { validator } = DuoChatQuickAction.props.command;

      it.each`
        description             | value                             | valid
        ${'with agenticPrompt'} | ${{ agenticPrompt: 'summarize' }} | ${true}
        ${'with agent'}         | ${{ agent: { name: 'myAgent' } }} | ${true}
        ${'without either key'} | ${{ other: 'value' }}             | ${false}
      `('returns $valid $description', ({ value, valid }) => {
        expect(Boolean(validator(value))).toBe(valid);
      });
    });

    describe('classicQuickAction validator', () => {
      const { validator } = DuoChatQuickAction.props.classicQuickAction;

      it.each`
        value                    | valid
        ${null}                  | ${true}
        ${'/summarize_comments'} | ${true}
        ${'/summarize'}          | ${true}
        ${'summarize'}           | ${false}
        ${'no_slash'}            | ${false}
      `('returns $valid for "$value"', ({ value, valid }) => {
        expect(validator(value)).toBe(valid);
      });
    });
  });

  describe('on click', () => {
    describe('event tracking', () => {
      it('tracks click_duo_quick_action with additionalTracking', async () => {
        await createComponent();

        await findButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_quick_action',
          { label: 'test_label' },
          undefined,
        );
      });
    });

    describe('event hub emissions', () => {
      it('emits SHOW_NEW_CHAT', async () => {
        await createComponent();

        await findButton().vm.$emit('click');

        expect(eventHub.$emit).toHaveBeenCalledWith(SHOW_NEW_CHAT);
      });
    });

    it('emits click', async () => {
      await createComponent();

      await findButton().vm.$emit('click');

      expect(wrapper.emitted('click')).toHaveLength(1);
    });

    it('emits chat-opened', async () => {
      await createComponent();

      await findButton().vm.$emit('click');

      expect(wrapper.emitted('chat-opened')).toHaveLength(1);
    });

    describe('QUEUE_CHAT_COMMAND', () => {
      it('emits QUEUE_CHAT_COMMAND with agenticPrompt as question', async () => {
        await createComponent();

        await findButton().vm.$emit('click');

        expect(eventHub.$emit).toHaveBeenCalledWith(QUEUE_CHAT_COMMAND, {
          agenticPrompt: 'do something',
          question: 'do something',
          resourceId: 'gid://gitlab/Issue/1',
        });
      });

      it('uses classicQuickAction as question when provided', async () => {
        await createComponent({ classicQuickAction: '/summarize' });

        await findButton().vm.$emit('click');

        expect(eventHub.$emit).toHaveBeenCalledWith(QUEUE_CHAT_COMMAND, {
          agenticPrompt: 'do something',
          question: '/summarize',
          resourceId: 'gid://gitlab/Issue/1',
        });
      });
    });
  });

  describe('duo-tool-completed event', () => {
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

    it('emits duo-tool-completed when the event hub fires', async () => {
      await createComponent();

      const payload = { name: 'some_tool', args: { key: 'value' } };
      const handler = subscribeToEvent.mock.calls.find(
        ([event]) => event === DUO_CHAT_TOOL_COMPLETED_EVENT,
      )[1];
      handler(payload);

      expect(wrapper.emitted('duo-tool-completed')).toEqual([[payload]]);
    });
  });
});
