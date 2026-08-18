import { computed, provide } from 'vue';
import type { InjectionKey, ComputedRef } from 'vue';

/**
 * Generic communication bridge composable for any event type.
 * Forwards props and creates type-safe event listeners for Vue components.
 *
 * @param props - Props received from the host
 * @param emit - Emit function for sending events to host
 * @param events - Array of event names to forward
 * @param config - Optional configuration for prop filtering and dependency injection
 */
export function useCommunicationBridge<
  TEvents extends { [K in keyof TEvents]: unknown[] },
  TProps extends object,
  TServices extends object = object,
>(
  props: TProps,
  emit: <K extends keyof TEvents>(event: K, ...args: TEvents[K]) => void,
  events: (keyof TEvents)[],
  config: {
    /** Keys to exclude from automatic prop forwarding */
    excludeProps?: (keyof TProps)[];
    /** Services to provide via dependency injection */
    services?: {
      key: InjectionKey<TServices>;
      factory: (props: TProps) => TServices;
    };
  } = {},
): {
  forwardedProps: ComputedRef<Partial<TProps>>;
  eventListeners: { [K in keyof TEvents]: (...args: TEvents[K]) => void };
} {
  const { excludeProps = [], services } = config;

  if (services) {
    provide(services.key, services.factory(props));
  }

  /**
   * Forward all props except excluded ones
   * Returns a reactive object that automatically tracks prop changes
   */
  const forwardedProps = computed<Partial<TProps>>(() => {
    const result: Partial<TProps> = {};
    const excludeSet = new Set(excludeProps);

    // Access each prop individually to ensure reactivity tracking
    Object.keys(props).forEach((key) => {
      const typedKey = key as keyof TProps;
      if (!excludeSet.has(typedKey)) {
        result[typedKey] = props[typedKey];
      }
    });

    return result;
  });

  /**
   * Create type-safe event handler
   */
  const createEventHandler =
    <K extends keyof TEvents>(eventName: K) =>
    (...args: TEvents[K]) =>
      emit(eventName, ...args);

  /**
   * Create event listeners for all specified events
   */
  const eventListeners = {} as { [K in keyof TEvents]: (...args: TEvents[K]) => void };

  events.forEach((eventName) => {
    eventListeners[eventName] = createEventHandler(eventName);
  });

  return {
    forwardedProps,
    eventListeners,
  };
}
