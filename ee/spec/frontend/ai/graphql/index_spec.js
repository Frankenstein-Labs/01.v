import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { eventHub, QUEUE_CHAT_COMMAND } from 'ee/ai/events/panel';
import { cacheConfig, createApolloProvider } from 'ee/ai/graphql';

jest.mock('~/lib/graphql');
jest.mock('ee/ai/events/panel');
jest.mock('vue-apollo');

describe('AI GraphQL Configuration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('cacheConfig', () => {
    it('has the correct structure', () => {
      expect(cacheConfig).toMatchObject({
        typePolicies: {
          Query: {
            fields: {
              isMaximized: {
                read: expect.any(Function),
              },
            },
          },
        },
      });
    });

    it('does not include activeTab in type policies', () => {
      expect(cacheConfig.typePolicies.Query.fields.activeTab).toBeUndefined();
    });

    it('disables AiAdditionalContext normalisation so per-message context items do not collide by id', () => {
      // AiAdditionalContext.id is a discriminator constant
      // ("page-context", "agents-md-user-instructions", ...) repeated across
      // messages — normalising would let one message's metadata overwrite
      // another's in the cache.
      expect(cacheConfig.typePolicies.AiAdditionalContext).toEqual({ keyFields: false });
    });
  });

  describe('createApolloProvider', () => {
    let mockClient;
    const eventHandlers = {};

    beforeEach(() => {
      eventHub.$on.mockImplementation((event, handler) => {
        eventHandlers[event] = handler;
      });
      mockClient = { query: jest.fn() };
      createDefaultClient.mockReturnValue(mockClient);
      VueApollo.mockImplementation(function MockVueApollo(config) {
        this.defaultClient = config.defaultClient;
      });
    });

    describe('events', () => {
      beforeEach(() => {
        createApolloProvider();
      });

      it('listens to QUEUE_CHAT_COMMAND events', () => {
        expect(eventHub.$on).toHaveBeenCalledWith(QUEUE_CHAT_COMMAND, expect.any(Function));
      });
    });

    describe('apollo provider creation', () => {
      let provider;

      beforeEach(() => {
        provider = createApolloProvider();
      });

      it('calls createDefaultClient with cacheConfig', () => {
        expect(createDefaultClient).toHaveBeenCalledWith({}, { cacheConfig });
      });

      it('creates VueApollo instance with defaultClient', () => {
        expect(VueApollo).toHaveBeenCalledWith({ defaultClient: mockClient });
      });

      it('returns VueApollo instance', () => {
        expect(provider).toBeInstanceOf(VueApollo);
        expect(provider.defaultClient).toBe(mockClient);
      });
    });
  });
});
