import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon, GlIcon } from '@gitlab/ui';
import SkipCiConfiguration from 'ee/security_orchestration/components/policy_drawer/skip_ci_configuration.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getUsersByUserIdsOrUsernames from 'ee/graphql_shared/queries/get_users_by_user_ids_or_usernames.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

describe('SkipCiConfiguration', () => {
  let wrapper;
  let requestHandler;

  const [mockUser1, mockUser2] = [1, 2].map((id) => ({
    __typename: 'UserCore',
    id: `gid://gitlab/User/${id}`,
    avatarUrl: '/avatar1',
    name: `user_${id}`,
    username: 'root',
    webUrl: '/root',
    webPath: '/root',
  }));

  const defaultHandler = (users = [mockUser1, mockUser2]) =>
    jest.fn().mockResolvedValue({
      data: {
        users: {
          __typename: 'UserCoreConnection',
          nodes: users,
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getUsersByUserIdsOrUsernames, handler]]);
  };

  const createComponent = ({ propsData = {}, handler = defaultHandler() } = {}) => {
    wrapper = shallowMountExtended(SkipCiConfiguration, {
      propsData,
      apolloProvider: createMockApolloProvider(handler),
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStatusIcon = () => wrapper.findComponent(GlIcon);
  const findUserList = () => wrapper.findByTestId('user-list');
  const findStatusLabel = () => wrapper.findByTestId('status-label');

  it('renders status by default', () => {
    createComponent();

    expect(findStatusIcon().props('name')).toBe('check-circle-dashed');
    expect(findStatusLabel().text()).toBe("Users can't skip pipelines");
    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findUserList().exists()).toBe(false);
  });

  it('renders enabled status', () => {
    createComponent({
      propsData: {
        configuration: {
          allowed: true,
        },
      },
    });

    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findStatusIcon().props('name')).toBe('check-circle-filled');
    expect(findStatusLabel().text()).toBe('Users can skip pipelines');
    expect(findUserList().exists()).toBe(false);
  });

  it('does not render user list if no user ids were provided', () => {
    createComponent({
      propsData: {
        configuration: {
          allowed: false,
        },
      },
    });

    expect(findStatusIcon().props('name')).toBe('check-circle-dashed');
    expect(findStatusLabel().text()).toBe("Users can't skip pipelines");
    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findUserList().exists()).toBe(false);
  });

  it('renders user list with exceptions', async () => {
    createComponent({
      handler: defaultHandler([mockUser1]),
      propsData: {
        configuration: {
          allowed: false,
          allowlist: {
            users: [{ id: 1 }],
          },
        },
      },
    });

    expect(findLoadingIcon().exists()).toBe(true);

    await waitForPromises();

    expect(requestHandler).toHaveBeenCalledTimes(1);
    expect(requestHandler).toHaveBeenCalledWith({ user_ids: ['gid://gitlab/User/1'] });
    expect(findLoadingIcon().exists()).toBe(false);
    expect(findUserList().exists()).toBe(true);
    expect(findUserList().text()).toBe('user_1');
  });

  it('does not render user list when skip ci is allowed', async () => {
    createComponent({
      propsData: {
        configuration: {
          allowed: true,
          allowlist: {
            users: [{ id: 1 }],
          },
        },
      },
    });

    await waitForPromises();

    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findUserList().exists()).toBe(false);
  });
});
