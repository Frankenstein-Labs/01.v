import {
  GlPagination,
  GlTable,
  GlAvatarLink,
  GlAvatarLabeled,
  GlBadge,
  GlModal,
  GlTooltip,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import SubscriptionUserList, {
  FIVE_MINUTES_IN_MS,
} from 'ee/usage_quotas/seats/components/subscription_user_list.vue';
import {
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX,
  DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX,
  SORT_OPTIONS,
} from 'ee/usage_quotas/seats/constants';
import { mockTableItems } from 'ee_jest/usage_quotas/seats/mock_data';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import SearchAndSortBar from '~/usage_quotas/components/search_and_sort_bar/search_and_sort_bar.vue';
import { useFakeDate } from 'helpers/fake_date';
import { createMockClient } from 'helpers/mock_apollo_helper';
import RemoveBillableMemberModal from 'ee/usage_quotas/seats/components/remove_billable_member_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import * as GroupsApi from 'ee/api/groups_api';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('~/alert');
jest.mock('ee/api/groups_api');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const MOCK_SEAT_USAGE_EXPORT_PATH = '/groups/test_group/-/seat_usage.csv';

const defaultProvide = {
  subscriptionHistoryHref: '/groups/my-group/-/usage_quotas/subscription_history.csv',
  seatUsageExportPath: MOCK_SEAT_USAGE_EXPORT_PATH,
  namespaceId: 1,
  namespaceName: 'GitLab',
};

const defaultProps = {
  hasFreePlan: false,
};

describe('SubscriptionUserList', () => {
  useLocalStorageSpy();
  useFakeDate('2025-03-16T15:00:00.000Z');

  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { jest.Mock } */
  let billableMembersMockHandler;

  const localStorageKey = `13-${DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX}`;
  const localStorageExpireKey = `13-${DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX}`;
  const fiveMinutesBeforeNow = () => new Date().getTime() - FIVE_MINUTES_IN_MS;
  const fiveMinutesFromNow = () => new Date().getTime() + FIVE_MINUTES_IN_MS;

  const createComponent = ({ mountFn = shallowMount, provide = {}, props = {} } = {}) => {
    const resolvers = {
      Query: {
        billableMembers: billableMembersMockHandler,
      },
    };

    const mockGitlabClient = createMockClient([], resolvers);

    const apolloProvider = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { gitlabClient: mockGitlabClient },
    });
    wrapper = extendedWrapper(
      mountFn(SubscriptionUserList, {
        apolloProvider,

        provide: {
          ...defaultProvide,
          ...provide,
        },
        propsData: {
          ...defaultProps,
          ...props,
        },
        stubs: {
          SearchAndSortBar: true,
        },
      }),
    );
    return waitForPromises();
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findExportButton = () => wrapper.findByTestId('export-button');
  const findExportSeatUsageHistoryButton = () =>
    wrapper.findByTestId('subscription-seat-usage-history');
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);
  const findPagination = () => wrapper.findComponent(GlPagination);
  const findAllRemoveUserItems = () => wrapper.findAllByTestId('remove-user');
  const findRemoveUserItem = (id) => wrapper.find(`[id="remove-user-${id}"]`);
  const findErrorModal = () => wrapper.findComponent(GlModal);
  const findRemoveBillableMemberModal = () => wrapper.findComponent(RemoveBillableMemberModal);

  const serializeTableRow = (rowWrapper) => {
    const extendedRowWrapper = extendedWrapper(rowWrapper);
    const emailWrapper = extendedRowWrapper.findByTestId('email');

    return {
      email: emailWrapper.text(),
      tooltip: emailWrapper.find('span').attributes('title'),
      removeUserButtonExists: extendedRowWrapper.findByTestId('remove-user').exists(),
      removeUserButtonDisabled:
        extendedRowWrapper.findByTestId('remove-user').attributes('aria-disabled') === 'true',
      removeUserButtonTooltip: extendedRowWrapper.findByTestId('remove-user-tooltip').exists()
        ? extendedRowWrapper.findByTestId('remove-user-tooltip').text()
        : undefined,
      lastActivityOn: extendedRowWrapper.findByTestId('last_activity_on').text(),
      lastLoginAt: extendedRowWrapper.findByTestId('last_login_at').text(),
    };
  };

  const findSerializedTable = (tableWrapper) => {
    return tableWrapper.findAll('tbody tr').wrappers.map(serializeTableRow);
  };

  beforeEach(() => {
    billableMembersMockHandler = jest.fn().mockResolvedValue({
      total: mockTableItems.length,
      page: 1,
      perPage: 5,
      members: mockTableItems,
    });
  });

  afterEach(() => {
    localStorage.clear();
  });

  describe('renders', () => {
    beforeEach(() => {
      return createComponent({
        mountFn: mount,
      });
    });

    describe('export button', () => {
      it('has the correct href', () => {
        expect(findExportButton().attributes().href).toBe(MOCK_SEAT_USAGE_EXPORT_PATH);
      });
    });

    describe('ExportSeatUsageHistoryButton', () => {
      it('has the correct href', () => {
        expect(findExportSeatUsageHistoryButton().attributes().href).toBe(
          defaultProvide.subscriptionHistoryHref,
        );
      });

      describe('with a Free Plan', () => {
        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
            props: {
              hasFreePlan: true,
            },
          });
        });

        it('does not render if plan is free', () => {
          expect(findExportSeatUsageHistoryButton().exists()).toBe(false);
        });
      });
    });

    describe('table content', () => {
      it('renders the correct data', () => {
        const serializedTable = findSerializedTable(findTable());

        expect(serializedTable).toMatchSnapshot();
      });
    });

    it('does not display the table in busy state', () => {
      expect(findTable().attributes('busy')).toBeUndefined();
    });

    it('pagination is rendered and passed correct values', () => {
      const pagination = findPagination();

      expect(pagination.props()).toMatchObject({
        perPage: 5,
        totalItems: 6,
      });
    });

    describe('with error modal', () => {
      it('does not render the modal if the user is not removable', async () => {
        await findAllRemoveUserItems().at(0).trigger('click');

        expect(findErrorModal().html()).toBe('');
      });

      it('renders the error modal if the user is removable', async () => {
        await findAllRemoveUserItems().at(2).trigger('click');

        expect(findErrorModal().text()).toContain(CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT);
      });
    });

    describe('when removing a billable user', () => {
      const user = mockTableItems[0];

      describe('when the request succeed', () => {
        beforeEach(async () => {
          GroupsApi.removeBillableMemberFromGroup.mockResolvedValue();

          await createComponent({ provide: { namespaceId: 13 } });
          // call removeBillableMember from the modal
          await findRemoveBillableMemberModal().vm.$emit('remove-billable-member', user.id);
        });

        it('sets the local storage key for the member id', () => {
          expect(localStorage.setItem).toHaveBeenCalledWith(localStorageKey, `[${user.id}]`);
        });

        it('sets the local storage key for expiration', () => {
          expect(localStorage.setItem).toHaveBeenCalledWith(
            localStorageExpireKey,
            fiveMinutesFromNow(),
          );
        });
      });

      describe('when the request fails', () => {
        beforeEach(async () => {
          GroupsApi.removeBillableMemberFromGroup.mockRejectedValueOnce();

          await createComponent({ provide: { namespaceId: 13 } });
        });

        it('does not adds the memberId to local storage', async () => {
          localStorage.clear();
          // call removeBillableMember from the modal
          await findRemoveBillableMemberModal().vm.$emit('remove-billable-member', user.id);
          expect(localStorage.setItem).not.toHaveBeenCalled();
        });
      });

      describe('when removing another member', () => {
        beforeEach(async () => {
          GroupsApi.removeBillableMemberFromGroup.mockResolvedValue();

          await createComponent({ provide: { namespaceId: 13 } });
          await findRemoveBillableMemberModal().vm.$emit('remove-billable-member', user.id);
          await findRemoveBillableMemberModal().vm.$emit('remove-billable-member', 3);
        });

        it('sets the local storage key for the member id', () => {
          expect(localStorage.setItem).toHaveBeenCalledWith(localStorageKey, `[${user.id},3]`);
        });

        it('sets the local storage key for expiration', () => {
          expect(localStorage.setItem).toHaveBeenCalledWith(
            localStorageExpireKey,
            fiveMinutesFromNow(),
          );
        });
      });
    });

    describe('when the removed billable user is set', () => {
      const selectedItem = 1;
      const user = mockTableItems[selectedItem];

      beforeEach(async () => {
        await createComponent({ mountFn: mount });
        GroupsApi.removeBillableMemberFromGroup.mockResolvedValue();

        await findRemoveBillableMemberModal().vm.$emit('remove-billable-member', user.id);
        // Wait for the component to re-render and Apollo to update
        await nextTick();
        await waitForPromises();
      });

      it('calls the endpoint to remove the user from the group', () => {
        expect(GroupsApi.removeBillableMemberFromGroup).toHaveBeenCalledWith(1, user.id);
      });

      it('disables the related remove button', () => {
        expect(findAllRemoveUserItems().at(selectedItem).attributes()['aria-disabled']).toBe(
          'true',
        );
      });

      it('does not disable unrelated remove button', () => {
        expect(findAllRemoveUserItems().at(2).attributes()['aria-disabled']).toBeUndefined();
      });

      it('shows a tooltip for related users', () => {
        const removeUserItem = findRemoveUserItem(user.id);
        expect(removeUserItem.findComponent(GlTooltip).text()).toBe(
          'This user is scheduled for removal.',
        );
      });

      it('does not show a tooltip for unrelated user', () => {
        const nonRemovedUser = mockTableItems[2];
        const removeUserItem = findRemoveUserItem(nonRemovedUser.id);
        expect(removeUserItem.findComponent(GlTooltip).exists()).toBe(false);
      });
    });

    describe('when the removed billable user is in local storage', () => {
      const selectedItem = 1;
      const user = mockTableItems[selectedItem];

      beforeEach(() => {
        localStorage.setItem(localStorageKey, `[${user.id}]`);
        localStorage.setItem(localStorageExpireKey, fiveMinutesFromNow());
        return createComponent({ provide: { namespaceId: 13 }, mountFn: mount });
      });

      it('disables the related remove button', () => {
        expect(findAllRemoveUserItems().at(selectedItem).attributes()['aria-disabled']).toBe(
          'true',
        );
      });

      it('does not disable unrelated remove button', () => {
        expect(findAllRemoveUserItems().at(3).attributes()['aria-disabled']).toBeUndefined();
      });

      it('shows a tooltip for related users', () => {
        const removeUserItem = findRemoveUserItem(user.id);
        expect(removeUserItem.findComponent(GlTooltip).text()).toBe(
          'This user is scheduled for removal.',
        );
      });

      it('does not show a tooltip for unrelated user', () => {
        const nonRemovedUser = mockTableItems[2];
        const removeUserItem = findRemoveUserItem(nonRemovedUser.id);
        expect(removeUserItem.findComponent(GlTooltip).exists()).toBe(false);
      });

      describe('when the local storage item is expired', () => {
        beforeEach(() => {
          localStorage.setItem(localStorageKey, `[${user.id}]`);
          localStorage.setItem(localStorageExpireKey, fiveMinutesBeforeNow());
          return createComponent({ provide: { namespaceId: 13 }, mountFn: mount });
        });

        it('does not disable the related remove button', () => {
          expect(
            findAllRemoveUserItems().at(selectedItem).attributes()['aria-disabled'],
          ).toBeUndefined();
        });

        it('removes the local storage key', () => {
          expect(localStorage.removeItem).toHaveBeenCalledWith(localStorageKey);
        });
      });

      describe('when the local storage item does not match the user', () => {
        beforeEach(() => {
          localStorage.setItem(localStorageKey, `[11]`);
          localStorage.setItem(localStorageExpireKey, fiveMinutesFromNow());
          return createComponent({ provide: { namespaceId: 13 }, mountFn: mount });
        });

        it('does not disable the related remove button', () => {
          expect(
            findAllRemoveUserItems().at(selectedItem).attributes()['aria-disabled'],
          ).toBeUndefined();
        });
      });

      describe('when the local storage item does not match namespace id', () => {
        beforeEach(() => {
          localStorage.setItem(localStorageKey, `[${user.id}]`);
          localStorage.setItem(localStorageExpireKey, fiveMinutesFromNow());
          return createComponent({ provide: { namespaceId: 11 }, mountFn: mount });
        });

        it('does not disable the related remove button', () => {
          expect(
            findAllRemoveUserItems().at(selectedItem).attributes()['aria-disabled'],
          ).toBeUndefined();
        });
      });

      describe('when the local storage errors', () => {
        beforeEach(() => {
          localStorage.setItem.mockImplementation(() => {
            throw new Error('This is an error');
          });
          return createComponent({ provide: { namespaceId: 11 }, mountFn: mount });
        });

        it('does not disable any remove button', () => {
          expect(
            findAllRemoveUserItems().at(selectedItem).attributes()['aria-disabled'],
          ).toBeUndefined();
        });
      });
    });

    describe('members labeled avatar', () => {
      it('shows the correct avatarLabeled length', () => {
        const avatarLabeledList = findTable().findAllComponents(GlAvatarLabeled);

        expect(avatarLabeledList).toHaveLength(6);
      });

      it('passes the correct props to avatarLabeled', () => {
        const avatarLabeled = findTable().findComponent(GlAvatarLabeled);

        expect(avatarLabeled.props()).toMatchObject({ label: 'Administrator', subLabel: '@root' });
      });
    });

    describe('members avatar', () => {
      it('shows the correct avatarLinks length', () => {
        const avatarLinks = findTable().findAllComponents(GlAvatarLink);

        expect(avatarLinks).toHaveLength(6);
      });

      it('passes the correct props to avatarLink', () => {
        const avatarLink = findTable().findComponent(GlAvatarLink);

        expect(avatarLink.attributes()).toMatchObject({
          alt: 'Administrator',
          href: 'path/to/administrator',
        });
      });

      it.each(['group_invite', 'project_invite'])(
        'shows the correct badge for membership_type %s',
        (membershipType) => {
          const avatarLinks = findTable().findAllComponents(GlAvatarLink);
          const badgeText = (
            membershipType.charAt(0).toUpperCase() + membershipType.slice(1)
          ).replace('_', ' ');

          avatarLinks.wrappers.forEach((avatarLinkWrapper) => {
            const currentMember = mockTableItems.find(
              (item) => item.name === avatarLinkWrapper.attributes().alt,
            );

            if (membershipType === currentMember.membership_type) {
              expect(avatarLinkWrapper.findComponent(GlBadge).text()).toBe(badgeText);
            }
          });
        },
      );
    });

    describe('members details always shown', () => {
      it.each`
        membershipType
        ${'project_invite'}
        ${'group_invite'}
        ${'project_member'}
        ${'group_member'}
      `(
        'when membershipType is $membershipType, shouldShowDetails will be true',
        ({ membershipType }) => {
          mockTableItems.forEach((item) => {
            const detailsExpandButtons = findTable().find(
              `[data-testid="toggle-seat-usage-details-${item.id}"]`,
            );

            if (membershipType === item.membership_type) {
              expect(detailsExpandButtons.exists()).toBe(true);
            }
          });
        },
      );
    });
  });

  describe('search box', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('input event changes search property', async () => {
      billableMembersMockHandler.mockClear();
      findSearchAndSortBar().vm.$emit('on-filter', 'search string');
      await nextTick();
      expect(billableMembersMockHandler).toHaveBeenCalledWith(
        expect.any(Object),
        {
          namespaceId: 1,
          page: 1,
          search: 'search string',
          sort: 'last_activity_on_desc',
        },
        expect.any(Object),
        expect.any(Object),
      );
    });

    it('contains the correct sort options', () => {
      expect(findSearchAndSortBar().props('sortOptions')).toMatchObject(SORT_OPTIONS);
    });
  });

  describe('remove billable members modal', () => {
    beforeEach(() => createComponent());
    describe('removing billable member', () => {
      it('renders an alert when request succeed', async () => {
        GroupsApi.removeBillableMemberFromGroup.mockResolvedValueOnce();

        await findRemoveBillableMemberModal().vm.$emit('remove-billable-member', 2);
        expect(createAlert).toHaveBeenCalledWith({
          message:
            'User successfully scheduled for removal. This process might take some time. Refresh the page to see the changes.',
          variant: 'success',
        });
      });
    });
  });

  describe('Loading state', () => {
    beforeEach(() => {
      billableMembersMockHandler.mockImplementation(() => new Promise(() => {}));
      createComponent();
    });

    it('displays table in busy state', () => {
      expect(findTable().attributes('busy')).toBe('true');
    });
  });

  describe('Error handling', () => {
    const ERROR = new Error('error');

    beforeEach(() => {
      billableMembersMockHandler.mockRejectedValue(ERROR);
      return createComponent();
    });

    it('logs the error to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(ERROR);
    });
  });
});
