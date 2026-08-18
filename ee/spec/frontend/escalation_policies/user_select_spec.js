import { GlTokenSelector, GlAvatar, GlToken } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import UserSelect from 'ee/escalation_policies/components/user_select.vue';
import { getParticipantsWithTokenStyles } from 'ee/escalation_policies/utils';
import searchProjectMembersQuery from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const mockUsers = [
  {
    __typename: 'UserCore',
    id: 1,
    name: 'User 1',
    username: 'user1',
    avatarUrl: 'avatar.com/user1.png',
  },
  {
    __typename: 'UserCore',
    id: 2,
    name: 'User2',
    username: 'user2',
    avatarUrl: 'avatar.com/user1.png',
  },
];

const membersQueryResponse = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      projectMembers: {
        __typename: 'MemberInterfaceConnection',
        nodes: mockUsers.map((user, index) => ({
          __typename: 'ProjectMember',
          id: `gid://gitlab/ProjectMember/${index + 1}`,
          user,
        })),
      },
    },
  },
};

describe('UserSelect', () => {
  let wrapper;
  const projectPath = 'group/project';

  const createComponent = async () => {
    wrapper = shallowMount(UserSelect, {
      apolloProvider: createMockApollo([
        [searchProjectMembersQuery, jest.fn().mockResolvedValue(membersQueryResponse)],
      ]),
      propsData: {
        mappedParticipants: getParticipantsWithTokenStyles([{ user: mockUsers[0] }]),
      },
      stubs: {
        GlTokenSelector,
      },
      provide: {
        projectPath,
      },
    });

    // The `users` smart query is debounced (250ms); advance timers so it fires.
    jest.runOnlyPendingTimers();
    await waitForPromises();
  };

  beforeEach(async () => {
    await createComponent();
  });

  const findTokenSelector = () => wrapper.findComponent(GlTokenSelector);
  const findSelectedUserToken = () => wrapper.findComponent(GlToken);
  const findAvatar = () => wrapper.findComponent(GlAvatar);

  describe('When no user selected', () => {
    it('renders token selector and provides it with correct params', () => {
      const tokenSelector = findTokenSelector();
      expect(tokenSelector.exists()).toBe(true);
      expect(tokenSelector.props('dropdownItems')).toEqual(mockUsers);
      expect(tokenSelector.props('loading')).toEqual(false);
    });

    it('does not render selected user token', () => {
      expect(findSelectedUserToken().exists()).toBe(false);
    });

    it('passes aria-label to the token selector', () => {
      expect(findTokenSelector().props('ariaLabel')).toBe('Search for user');
    });
  });

  describe('On user selected', () => {
    it('hides token selector', async () => {
      const tokenSelector = findTokenSelector();
      expect(tokenSelector.exists()).toBe(true);
      tokenSelector.vm.$emit('input', [mockUsers[0]]);
      await nextTick();
      expect(tokenSelector.exists()).toBe(false);
    });

    it('shows selected user token with name and avatar', async () => {
      const selectedUser = { ...mockUsers[0], ...wrapper.props('mappedParticipants')[0] };
      findTokenSelector().vm.$emit('input', [selectedUser]);
      await nextTick();
      const userToken = findSelectedUserToken();
      expect(userToken.exists()).toBe(true);
      expect(userToken.text()).toMatchInterpolatedText(selectedUser.name);
      expect(userToken.classes(selectedUser.class)).toBe(true);
      expect(userToken.attributes('style')).toContain('background-color:');
      const avatar = findAvatar();
      expect(avatar.exists()).toBe(true);
      expect(avatar.props('src')).toBe(selectedUser.avatarUrl);
      expect(avatar.attributes('alt')).toBe('');
      expect(userToken.props('removeLabel')).toBe('Remove User 1');
    });
  });

  describe('On user deselected', () => {
    it('hides selected user token and avatar, shows token selector', async () => {
      // select user
      findTokenSelector().vm.$emit('input', [mockUsers[0]]);
      await nextTick();
      const userToken = findSelectedUserToken();
      expect(userToken.exists()).toBe(true);
      // deselect user
      userToken.vm.$emit('close');
      await nextTick();
      expect(userToken.exists()).toBe(false);
      expect(findTokenSelector().exists()).toBe(true);
    });
  });
});
