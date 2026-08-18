import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Mock } from 'vitest';
import { ref, computed, type InjectionKey } from 'vue';
import { useCommunicationBridge } from './useCommunicationBridge';

// Test types
interface TestEvents {
  'event-one': [];
  'event-two': [data: string];
  'event-three': [id: number, name: string];
}

interface TestProps {
  title: string;
  count: number;
  callback: () => void;
  data: { id: number };
}

interface TestServices {
  logger: { log: (msg: string) => void };
  api: { fetch: (url: string) => Promise<unknown> };
}

describe('useCommunicationBridge', () => {
  let mockEmit: Mock;
  let testProps: TestProps;

  beforeEach(() => {
    mockEmit = vi.fn();
    testProps = {
      title: 'Test Title',
      count: 42,
      callback: vi.fn(),
      data: { id: 123 },
    };
  });

  describe('basic functionality', () => {
    it('should forward all props by default', () => {
      const { forwardedProps } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one'],
      );

      expect(forwardedProps.value).toEqual(testProps);
    });

    it('should exclude specified props from forwarding', () => {
      const { forwardedProps } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one'],
        { excludeProps: ['callback', 'count'] },
      );

      expect(forwardedProps.value).toEqual({
        title: 'Test Title',
        data: { id: 123 },
      });
      expect(forwardedProps.value).not.toHaveProperty('callback');
      expect(forwardedProps.value).not.toHaveProperty('count');
    });

    it('should create event listeners for all specified events', () => {
      const { eventListeners } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one', 'event-two', 'event-three'],
      );

      expect(eventListeners).toHaveProperty('event-one');
      expect(eventListeners).toHaveProperty('event-two');
      expect(eventListeners).toHaveProperty('event-three');
      expect(typeof eventListeners['event-one']).toBe('function');
      expect(typeof eventListeners['event-two']).toBe('function');
      expect(typeof eventListeners['event-three']).toBe('function');
    });
  });

  describe('event handling', () => {
    it('should emit events with no arguments', () => {
      const { eventListeners } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one'],
      );

      eventListeners['event-one']();

      expect(mockEmit).toHaveBeenCalledWith('event-one');
      expect(mockEmit).toHaveBeenCalledTimes(1);
    });

    it('should emit events with single argument', () => {
      const { eventListeners } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-two'],
      );

      eventListeners['event-two']('test-data');

      expect(mockEmit).toHaveBeenCalledWith('event-two', 'test-data');
      expect(mockEmit).toHaveBeenCalledTimes(1);
    });

    it('should emit events with multiple arguments', () => {
      const { eventListeners } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-three'],
      );

      eventListeners['event-three'](123, 'test-name');

      expect(mockEmit).toHaveBeenCalledWith('event-three', 123, 'test-name');
      expect(mockEmit).toHaveBeenCalledTimes(1);
    });

    it('should handle multiple event calls independently', () => {
      const { eventListeners } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one', 'event-two'],
      );

      eventListeners['event-one']();
      eventListeners['event-two']('data');
      eventListeners['event-one']();

      expect(mockEmit).toHaveBeenNthCalledWith(1, 'event-one');
      expect(mockEmit).toHaveBeenNthCalledWith(2, 'event-two', 'data');
      expect(mockEmit).toHaveBeenNthCalledWith(3, 'event-one');
      expect(mockEmit).toHaveBeenCalledTimes(3);
    });
  });

  describe('dependency injection', () => {
    it('should provide services when configured', () => {
      const serviceKey: InjectionKey<TestServices> = Symbol('test-services');
      const mockServices: TestServices = {
        logger: { log: vi.fn() },
        api: { fetch: vi.fn() },
      };
      const serviceFactory = vi.fn().mockReturnValue(mockServices);

      useCommunicationBridge<TestEvents, TestProps, TestServices>(
        testProps,
        mockEmit,
        ['event-one'],
        {
          services: {
            key: serviceKey,
            factory: serviceFactory,
          },
        },
      );

      expect(serviceFactory).toHaveBeenCalledWith(testProps);
      expect(serviceFactory).toHaveBeenCalledTimes(1);
    });

    it('should not call service factory when services not configured', () => {
      const serviceFactory = vi.fn();

      useCommunicationBridge<TestEvents, TestProps>(testProps, mockEmit, ['event-one']);

      expect(serviceFactory).not.toHaveBeenCalled();
    });
  });

  describe('reactivity', () => {
    it('should update forwardedProps when props change', () => {
      const reactiveProps = ref(testProps);

      // Create a computed that uses the bridge with reactive props
      const bridgeResult = computed(() =>
        useCommunicationBridge<TestEvents, TestProps>(reactiveProps.value, mockEmit, ['event-one']),
      );

      const initialProps = bridgeResult.value.forwardedProps.value;
      expect(initialProps.title).toBe('Test Title');

      // Update props
      reactiveProps.value = { ...testProps, title: 'Updated Title' };

      // The computed should update with new props
      const updatedProps = bridgeResult.value.forwardedProps.value;
      expect(updatedProps.title).toBe('Updated Title');
    });

    it('should maintain prop exclusion when props change', () => {
      const reactiveProps = ref(testProps);

      const bridgeResult = computed(() =>
        useCommunicationBridge<TestEvents, TestProps>(
          reactiveProps.value,
          mockEmit,
          ['event-one'],
          { excludeProps: ['callback'] },
        ),
      );

      // Initial state
      expect(bridgeResult.value.forwardedProps.value).not.toHaveProperty('callback');
      expect(bridgeResult.value.forwardedProps.value.title).toBe('Test Title');

      // Update props
      reactiveProps.value = {
        ...testProps,
        title: 'New Title',
        callback: vi.fn(), // New callback function
      };

      // Should still exclude callback but include updated title
      const updatedProps = bridgeResult.value.forwardedProps.value;
      expect(updatedProps).not.toHaveProperty('callback');
      expect(updatedProps.title).toBe('New Title');
    });

    it('should work with realistic Vue component props pattern', () => {
      // Simulate how Vue components actually receive props
      const componentProps = ref({
        messages: [{ id: 1, text: 'Hello' }],
        isLoading: false,
        userId: 'user-123',
      });

      type ComponentProps = typeof componentProps.value;
      interface ComponentEvents {
        'message-sent': [message: string];
        'loading-changed': [isLoading: boolean];
      }

      const bridgeResult = computed(() =>
        useCommunicationBridge<ComponentEvents, ComponentProps>(componentProps.value, mockEmit, [
          'message-sent',
          'loading-changed',
        ]),
      );

      // Initial state
      expect(bridgeResult.value.forwardedProps.value.isLoading).toBe(false);
      expect(bridgeResult.value.forwardedProps.value.messages).toHaveLength(1);

      // Simulate prop updates from parent component
      componentProps.value = {
        ...componentProps.value,
        isLoading: true,
        messages: [
          { id: 1, text: 'Hello' },
          { id: 2, text: 'World' },
        ],
      };

      // Props should be reactive
      const updatedProps = bridgeResult.value.forwardedProps.value;
      expect(updatedProps.isLoading).toBe(true);
      expect(updatedProps.messages).toHaveLength(2);
    });
  });

  describe('edge cases', () => {
    it('should handle empty events array', () => {
      const { eventListeners } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        [],
      );

      expect(Object.keys(eventListeners)).toHaveLength(0);
    });

    it('should handle empty props object', () => {
      const emptyProps = {} as TestProps;
      const { forwardedProps } = useCommunicationBridge<TestEvents, TestProps>(
        emptyProps,
        mockEmit,
        ['event-one'],
      );

      expect(forwardedProps.value).toEqual({});
    });

    it('should handle excludeProps with non-existent keys', () => {
      const { forwardedProps } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one'],
        { excludeProps: ['nonExistent' as keyof TestProps] },
      );

      expect(forwardedProps.value).toEqual(testProps);
    });

    it('should handle all props excluded', () => {
      const { forwardedProps } = useCommunicationBridge<TestEvents, TestProps>(
        testProps,
        mockEmit,
        ['event-one'],
        { excludeProps: ['title', 'count', 'callback', 'data'] },
      );

      expect(forwardedProps.value).toEqual({});
    });
  });
});
