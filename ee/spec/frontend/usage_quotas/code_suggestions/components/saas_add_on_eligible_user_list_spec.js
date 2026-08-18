import Vue, { nextTick } from 'vue';
import { GlBadge } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createMockClient } from 'helpers/mock_apollo_helper';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockPaginatedAddOnEligibleUsers,
  mockPaginatedAddOnEligibleUsersWithMembershipType,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/saas_add_on_eligible_users.query.graphql';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import { DUO_PRO, DUO_ENTERPRISE } from 'ee/constants/duo';
import { SORT_OPTIONS, DEFAULT_SORT_OPTION } from 'ee/usage_quotas/code_suggestions/constants';
import {
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNED_SEAT,
  TOKEN_TYPE_ASSIGNED_SEAT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('Add On Eligible User List', () => {
  let wrapper;

  const fullPath = 'namespace/full-path';
  const duoProAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';
  const duoEnterpriseAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/2';
  const activeDuoTier = DUO_PRO;
  const error = new Error('Error');

  const defaultPaginationParams = {
    first: DEFAULT_PER_PAGE,
    last: null,
    after: null,
    before: null,
    sort: DEFAULT_SORT_OPTION,
  };

  const duoProDefaultQueryVariables = {
    fullPath,
    addOnType: DUO_PRO,
    addOnPurchaseIds: [duoProAddOnPurchaseId],
    ...defaultPaginationParams,
  };
  const defaultDuoEnterpriseQueryVariables = {
    fullPath,
    addOnType: DUO_ENTERPRISE,
    addOnPurchaseIds: [duoEnterpriseAddOnPurchaseId],
    ...defaultPaginationParams,
  };

  const addOnEligibleUsersDataHandler = jest
    .fn()
    .mockResolvedValue(mockPaginatedAddOnEligibleUsers);
  const addOnEligibleUsersWithMembershipTypeDataHandler = jest
    .fn()
    .mockResolvedValue(mockPaginatedAddOnEligibleUsersWithMembershipType);
  const subscriptionPermissionsDataHandler = jest.fn().mockResolvedValue({
    data: {
      subscription: {
        canAddSeats: false,
        canRenew: false,
        communityPlan: false,
        canAddDuoProSeats: true,
      },
      userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
    },
  });

  const addOnEligibleUsersErrorHandler = jest.fn().mockRejectedValue(error);
  const subscriptionPermissionErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (addOnEligibleUsersHandler, subscriptionPermissionsHandler) => {
    const mockClient = createMockClient([[getAddOnEligibleUsers, addOnEligibleUsersHandler]]);
    const mockClientCustomersDot = createMockClient([
      [getSubscriptionPermissionsData, subscriptionPermissionsHandler],
    ]);
    return new VueApollo({
      defaultClient: mockClient,
      clients: { customersDotClient: mockClientCustomersDot },
    });
  };

  const createComponent = ({
    props = {},
    addOnEligibleUsersHandler = addOnEligibleUsersDataHandler,
    subscriptionPermissionsHandler = subscriptionPermissionsDataHandler,
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(SaasAddOnEligibleUserList, {
      apolloProvider: createMockApolloProvider(
        addOnEligibleUsersHandler,
        subscriptionPermissionsHandler,
      ),
      propsData: {
        addOnPurchaseId: duoProAddOnPurchaseId,
        activeDuoTier,
        ...props,
      },
      provide: {
        fullPath,
        addDuoProHref: 'http://customers.gitlab.com/namespaces/0/duo_pro_seats',
        groupId: 1,
        subscriptionName: null,
      },
    });
    return waitForPromises();
  };

  const findAddOnEligibleUserList = () => wrapper.findComponent(AddOnEligibleUserList);
  const findAddOnEligibleUsersFetchError = () =>
    wrapper.findComponentByTestId('add-on-eligible-users-fetch-error');
  const findMembershipTypeBadge = () => wrapper.findComponent(GlBadge);
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);

  describe('add-on eligible user list', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('displays add-on eligible user list', () => {
      const { pageInfo, nodes: users } =
        mockPaginatedAddOnEligibleUsers.data.namespace.addOnEligibleUsers;
      const expectedProps = {
        addOnPurchaseId: duoProAddOnPurchaseId,
        activeDuoTier,
        isLoading: false,
        pageInfo,
        pageSize: DEFAULT_PER_PAGE,
        users,
        search: '',
      };

      expect(findAddOnEligibleUserList().props()).toMatchObject(expectedProps);
    });

    it('calls addOnEligibleUsers query with appropriate params', () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(duoProDefaultQueryVariables);
    });

    describe('with Duo Enterprise add-on tier', () => {
      beforeEach(() => {
        return createComponent({
          props: { activeDuoTier: DUO_ENTERPRISE, addOnPurchaseId: duoEnterpriseAddOnPurchaseId },
        });
      });

      it('calls addOnEligibleUsers query with appropriate params', () => {
        expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(
          defaultDuoEnterpriseQueryVariables,
        );
      });
    });

    it('does not the membership type badge', () => {
      expect(findMembershipTypeBadge().exists()).toBe(false);
    });

    describe('with group invited users', () => {
      it('shows the membership type badge', async () => {
        await createComponent({
          addOnEligibleUsersHandler: addOnEligibleUsersWithMembershipTypeDataHandler,
          mountFn: mountExtended,
        });

        expect(findMembershipTypeBadge().text()).toBe('Group invite');
      });
    });

    it('passes the correct sort options to <search-and-sort-bar>', () => {
      expect(findSearchAndSortBar().props('sortOptions')).toStrictEqual(SORT_OPTIONS);
    });

    it('passes the correct tokens to <search-and-sort-bar>', () => {
      expect(findSearchAndSortBar().props('tokens')).toStrictEqual([
        {
          options: [
            { value: 'true', title: 'Yes' },
            { value: 'false', title: 'No' },
          ],
          icon: 'user',
          operators: OPERATORS_IS,
          title: TOKEN_TITLE_ASSIGNED_SEAT,
          token: BaseToken,
          type: TOKEN_TYPE_ASSIGNED_SEAT,
          unique: true,
        },
      ]);
    });

    describe('when there is an error fetching add on eligible users', () => {
      beforeEach(() => {
        return createComponent({ addOnEligibleUsersHandler: addOnEligibleUsersErrorHandler });
      });

      it('does not display loading state for add-on eligible user list', () => {
        expect(findAddOnEligibleUserList().props('isLoading')).toBe(false);
      });

      it('sends the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException.mock.calls[0][0]).toEqual(error);
      });

      it('shows an error alert', () => {
        const expectedProps = {
          dismissible: true,
          error: ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
          errorDictionary: ADD_ON_ERROR_DICTIONARY,
        };

        expect(findAddOnEligibleUsersFetchError().props()).toEqual(
          expect.objectContaining(expectedProps),
        );
      });

      it('clears error alert when dismissed', async () => {
        findAddOnEligibleUsersFetchError().vm.$emit('dismiss');

        await nextTick();

        expect(findAddOnEligibleUsersFetchError().exists()).toBe(false);
      });
    });

    describe('subscription permissions', () => {
      beforeEach(() => {
        return createComponent({
          subscriptionPermissionsHandler: subscriptionPermissionErrorHandler,
        });
      });

      describe('when user has sufficient permissions to add seats', () => {
        it('shows Add Button seat on error messages in AddOnEligibleUserList', () => {
          const expectedProps = {
            hideAddButtonSeatOnErrorMessage: false,
          };

          expect(findAddOnEligibleUserList().props()).toEqual(
            expect.objectContaining(expectedProps),
          );
        });
      });

      describe('when there is an error fetching subscription permissions', () => {
        it('sends the error to Sentry', () => {
          expect(Sentry.captureException).toHaveBeenCalledTimes(1);
          expect(Sentry.captureException.mock.calls[0][0]).toEqual(error);
        });
      });
    });
  });

  describe('when loading', () => {
    it('displays add-on eligible user list in loading state', () => {
      createComponent();

      expect(findAddOnEligibleUserList().props('isLoading')).toBe(true);
    });
  });

  describe('pagination', () => {
    const { startCursor, endCursor } =
      mockPaginatedAddOnEligibleUsers.data.namespace.addOnEligibleUsers.pageInfo.endCursor;
    beforeEach(() => {
      return createComponent();
    });

    it('fetches next page of users on next', async () => {
      findAddOnEligibleUserList().vm.$emit('next', endCursor);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        after: endCursor,
      });
    });

    it('fetches prev page of users on prev', async () => {
      findAddOnEligibleUserList().vm.$emit('prev', startCursor);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        first: null,
        last: 20,
        before: startCursor,
      });
    });
  });

  describe('with page size selection', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('fetches changed number of user items', async () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        first: DEFAULT_PER_PAGE,
      });

      const newPageSize = 50;
      findAddOnEligibleUserList().vm.$emit('page-size-change', newPageSize);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        first: newPageSize,
      });
    });
  });

  describe('with filters and sort options', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('fetches users list with the default sorting value', async () => {
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        sort: DEFAULT_SORT_OPTION,
      });
    });

    it('fetches users list matching the search term', async () => {
      const filterOptions = { search: 'test' };

      findSearchAndSortBar().vm.$emit('on-filter', filterOptions);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        ...filterOptions,
      });
    });

    it('fetches users list with the correct sorting values', async () => {
      findSearchAndSortBar().vm.$emit('on-sort', 'LAST_ACTIVITY_ON_DESC');
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        sort: 'LAST_ACTIVITY_ON_DESC',
      });
    });

    it('fetches users list by assigned seats', async () => {
      const filterOptions = { filterByAssignedSeat: 'true' };
      findSearchAndSortBar().vm.$emit('on-filter', filterOptions);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        ...filterOptions,
      });
    });
  });
});
