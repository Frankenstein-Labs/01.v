import { GlAvatarLabeled, GlAvatarLink } from '@gitlab/ui';
import groupPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/group_pending_member_approvals.json';
import UserAvatar from 'ee/members/promotion_requests/components/user_avatar.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TEST_HOST } from 'helpers/test_constants';

describe('UserAvatar', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findAvatarLabeled = () => wrapper.findComponent(GlAvatarLabeled);
  const findAvatarLink = () => wrapper.findComponent(GlAvatarLink);

  const { user } =
    groupPendingMemberApprovalsQueryMockData.data.group.pendingMemberApprovals.nodes[0];

  const createComponent = (propsData = {}) => {
    wrapper = mountExtended(UserAvatar, {
      propsData: {
        user,
        ...propsData,
      },
    });
  };

  it("renders link to user's profile", () => {
    createComponent();

    const link = findAvatarLink();

    expect(link.exists()).toBe(true);
    expect(link.attributes()).toMatchObject({
      href: user.webUrl,
      'data-user-id': `${getIdFromGraphQLId(user.id)}`,
      'data-username': user.username,
    });
  });

  it("renders user's name", () => {
    createComponent();

    expect(wrapper.findByText(user.name).exists()).toBe(true);
  });

  it("renders user's username", () => {
    createComponent();

    expect(wrapper.findByText(`@${user.username}`).exists()).toBe(true);
  });

  describe('user avatar', () => {
    it('displays an internal avatar and sets width', () => {
      const avatarUrl = '/uploads/-/system/user/avatar/00/01.jpg';
      createComponent({
        user: {
          ...user,
          avatarUrl,
        },
      });

      expect(findAvatarLabeled().props('src')).toBe(`${TEST_HOST}${avatarUrl}?width=96`);
    });

    it('displays an external avatar and sets width', () => {
      const avatarUrl = 'https://www.gravatar.com/avatar/0';
      createComponent({
        user: {
          ...user,
          avatarUrl,
        },
      });

      expect(findAvatarLabeled().props('src')).toBe('https://www.gravatar.com/avatar/0?width=96');
    });

    it('does not render user avatar image if avatarUrl is null', () => {
      createComponent({
        user: {
          ...user,
          avatarUrl: null,
        },
      });
      expect(findAvatarLabeled().props('src')).toBeNull();
    });
  });

  describe('Orphaned request', () => {
    it('displays "Orphaned request" when user is null', () => {
      createComponent({ user: null });

      expect(findAvatarLabeled().props('label')).toBe('Orphaned request');
    });
  });
});
