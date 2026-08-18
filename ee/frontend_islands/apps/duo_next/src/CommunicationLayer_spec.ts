import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, VueWrapper } from '@vue/test-utils';
import { computed } from 'vue';
import CommunicationLayer from './CommunicationLayer.vue';
import App from './App.vue';
import type { HostDataProps, ChatModel } from './types';
import * as useCommunicationBridgeModule from './composables/useCommunicationBridge';

const mockUseCommunicationBridge = vi.fn();
vi.spyOn(useCommunicationBridgeModule, 'useCommunicationBridge').mockImplementation(
  mockUseCommunicationBridge,
);

describe('CommunicationLayer', () => {
  let wrapper: VueWrapper;

  const mockModels: ChatModel[] = [
    {
      value: 'gpt-4',
      text: 'GPT-4',
    },
  ];

  const defaultProps: HostDataProps = {
    models: mockModels,
    avatarUrl: 'https://example.com/avatar.png',
    userName: 'FooBar',
  };

  const findAppComponent = () => wrapper.findComponent(App);

  beforeEach(() => {
    vi.clearAllMocks();

    mockUseCommunicationBridge.mockImplementation((props, emit, events) => {
      const eventListeners: Record<string, (...args: unknown[]) => void> = {};
      events.forEach((eventName: string) => {
        eventListeners[eventName] = (...args: unknown[]) => {
          emit(eventName, ...args);
        };
      });

      return {
        forwardedProps: computed(() => props),
        eventListeners,
      };
    });
  });

  it('should render the App component', () => {
    wrapper = mount(CommunicationLayer, {
      props: defaultProps,
    });

    expect(findAppComponent().exists()).toBe(true);
  });

  it('should forward props and bind event listeners to App component', async () => {
    wrapper = mount(CommunicationLayer, {
      props: defaultProps,
    });

    const appComponent = findAppComponent();

    // Verify props are forwarded
    expect(appComponent.props('models')).toEqual(mockModels);
    expect(appComponent.props('avatarUrl')).toBe('https://example.com/avatar.png');
    expect(appComponent.props('userName')).toBe('FooBar');

    // Verify event listeners are bound
    // The useCommunicationBridge composable should have been called with the correct event names
    expect(mockUseCommunicationBridge).toHaveBeenCalledWith(
      defaultProps,
      expect.any(Function),
      expect.arrayContaining([
        'chat-hidden',
        'change-model',
        'thread-selected',
        'new-chat',
        'back-to-list',
        'delete-thread',
        'chat-cancel',
        'send-chat-prompt',
        'track-feedback',
        'chat-resize',
      ]),
    );

    // Verify that the event listeners returned by the composable are actually functions
    const { eventListeners } = mockUseCommunicationBridge.mock.results[0].value;
    expect(typeof eventListeners['chat-hidden']).toBe('function');
    expect(typeof eventListeners['change-model']).toBe('function');
    expect(typeof eventListeners['thread-selected']).toBe('function');
  });

  it.each<HostDataProps>([
    { models: mockModels },
    { avatarUrl: 'https://example.com/avatar.png' },
    {},
  ])('should work with different prop combinations: %o', (props) => {
    wrapper = mount(CommunicationLayer, {
      props,
    });

    expect(findAppComponent().exists()).toBe(true);
    expect(mockUseCommunicationBridge).toHaveBeenCalledWith(
      props,
      expect.any(Function),
      expect.any(Array),
    );
  });
});
