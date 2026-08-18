import { GlAvatar, GlFilteredSearchTokenSegment } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import usersAutocompleteQuery from '~/graphql_shared/queries/users_autocomplete.query.graphql';
import TriggeredByToken from 'ee/agent_artifacts/components/tokens/triggered_by_token.vue';

Vue.use(VueApollo);

const mockUsers = [
  {
    id: 'gid://gitlab/User/1',
    username: 'alice',
    name: 'Alice Smith',
    avatarUrl: 'https://example.com/alice.png',
  },
  {
    id: 'gid://gitlab/User/2',
    username: 'bob',
    name: 'Bob Jones',
    avatarUrl: 'https://example.com/bob.png',
  },
];

const mockAutocompleteResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      autocompleteUsers: mockUsers,
    },
    project: null,
  },
};

describe('TriggeredByToken', () => {
  let wrapper;

  const createComponent = ({ value = { data: '' }, active = false, configOverrides = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [usersAutocompleteQuery, jest.fn().mockResolvedValue(mockAutocompleteResponse)],
    ]);

    wrapper = mount(TriggeredByToken, {
      propsData: {
        config: {
          type: 'triggeredByUserId',
          icon: 'user',
          title: 'Triggered by',
          unique: true,
          fullPath: 'gitlab-org',
          isProject: false,
          valueField: 'id',
          defaultUsers: [],
          initialUsers: mockUsers,
          ...configOverrides,
        },
        value,
        active,
        cursorPosition: 'start',
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        suggestionsListClass: () => 'custom-class',
        termsAsTokens: () => false,
      },
      apolloProvider,
      stubs: {
        Portal: true,
      },
    });
  };

  describe('getActiveUser', () => {
    const users = [
      {
        id: 'gid://gitlab/User/1',
        username: 'alice',
        name: 'Alice Smith',
        avatarUrl: 'https://example.com/alice.png',
      },
      {
        id: 'gid://gitlab/User/2',
        username: 'bob',
        name: 'Bob Jones',
        avatarUrl: 'https://example.com/bob.png',
      },
    ];

    // Access the method directly from the component options
    const { getActiveUser } = TriggeredByToken.methods;

    describe('when data matches a user global ID', () => {
      it('returns the matching user', () => {
        const result = getActiveUser(users, 'gid://gitlab/User/1');

        expect(result).toEqual(users[0]);
      });
    });

    describe('when data matches a username (case-insensitive)', () => {
      it('returns the matching user for exact username', () => {
        const result = getActiveUser(users, 'alice');

        expect(result).toEqual(users[0]);
      });

      it('returns the matching user for uppercase username', () => {
        const result = getActiveUser(users, 'BOB');

        expect(result).toEqual(users[1]);
      });
    });

    describe('when data does not match any user', () => {
      it('returns undefined', () => {
        const result = getActiveUser(users, 'nonexistent');

        expect(result).toBeUndefined();
      });
    });

    describe('when users list is empty', () => {
      it('returns undefined', () => {
        const result = getActiveUser([], 'gid://gitlab/User/1');

        expect(result).toBeUndefined();
      });
    });
  });

  describe('rendered token display', () => {
    describe('when value is a user global ID', () => {
      beforeEach(async () => {
        createComponent({ value: { data: 'gid://gitlab/User/1' } });
        await waitForPromises();
      });

      it('renders the user name instead of the raw global ID', () => {
        const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);
        const valueSegment = tokenSegments.at(2);

        expect(valueSegment.text()).toBe(mockUsers[0].name);
        expect(valueSegment.text()).not.toContain('gid://gitlab/User/');
      });

      it('renders the user avatar', () => {
        const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);
        const valueSegment = tokenSegments.at(2);

        expect(valueSegment.findComponent(GlAvatar).props('src')).toBe(mockUsers[0].avatarUrl);
      });
    });

    describe('when value is a username', () => {
      beforeEach(async () => {
        createComponent({ value: { data: 'bob' } });
        await waitForPromises();
      });

      it('renders the user name instead of the raw username', () => {
        const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);
        const valueSegment = tokenSegments.at(2);

        expect(valueSegment.text()).toBe(mockUsers[1].name);
      });

      it('renders the user avatar', () => {
        const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);
        const valueSegment = tokenSegments.at(2);

        expect(valueSegment.findComponent(GlAvatar).props('src')).toBe(mockUsers[1].avatarUrl);
      });
    });
  });
});
