import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { DEFAULT_PER_PAGE } from '~/api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/self_managed_add_on_eligible_users.query.graphql';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import { DUO_PRO, DUO_ENTERPRISE, DUO_AMAZON_Q } from 'ee/constants/duo';
import { SORT_OPTIONS, DEFAULT_SORT_OPTION } from 'ee/usage_quotas/code_suggestions/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import {
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNED_SEAT,
  TOKEN_TYPE_ASSIGNED_SEAT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  eligibleSMUsers,
  pageInfoWithMorePages,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('Add On Eligible User List', () => {
  let wrapper;

  const duoProAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';
  const duoEnterpriseAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/2';
  const duoAmazonQAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3';

  const error = new Error('Error');
  const addOnEligibleUsersResponse = {
    data: {
      selfManagedAddOnEligibleUsers: {
        nodes: eligibleSMUsers,
        pageInfo: pageInfoWithMorePages,
        __typename: 'AddOnUserConnection',
      },
    },
  };

  const defaultPaginationParams = {
    first: DEFAULT_PER_PAGE,
    last: null,
    after: null,
    before: null,
    sort: DEFAULT_SORT_OPTION,
  };

  const activeDuoTier = DUO_PRO;
  const duoProDefaultQueryVariables = {
    addOnType: DUO_PRO,
    addOnPurchaseIds: [duoProAddOnPurchaseId],
    ...defaultPaginationParams,
  };
  const defaultDuoEnterpriseQueryVariables = {
    addOnType: DUO_ENTERPRISE,
    addOnPurchaseIds: [duoEnterpriseAddOnPurchaseId],
    ...defaultPaginationParams,
  };
  const defaultDuoAmazonQQueryVariables = {
    addOnType: DUO_AMAZON_Q,
    addOnPurchaseIds: [duoAmazonQAddOnPurchaseId],
    ...defaultPaginationParams,
  };

  const addOnEligibleUsersDataHandler = jest.fn().mockResolvedValue(addOnEligibleUsersResponse);
  const addOnEligibleUsersErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler) =>
    createMockApollo([[getAddOnEligibleUsers, handler]]);

  const createComponent = ({ props = {}, handler = addOnEligibleUsersDataHandler } = {}) => {
    wrapper = shallowMountExtended(SelfManagedAddOnEligibleUserList, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        addOnPurchaseId: duoProAddOnPurchaseId,
        activeDuoTier,
        ...props,
      },
    });

    return waitForPromises();
  };

  const findAddOnEligibleUserList = () => wrapper.findComponent(AddOnEligibleUserList);
  const findAddOnEligibleUsersFetchError = () =>
    wrapper.findComponentByTestId('add-on-eligible-users-fetch-error');
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);

  describe('add-on eligible user list', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('displays add-on eligible user list', () => {
      const expectedProps = {
        addOnPurchaseId: duoProAddOnPurchaseId,
        activeDuoTier: DUO_PRO,
        isLoading: false,
        pageInfo: pageInfoWithMorePages,
        pageSize: DEFAULT_PER_PAGE,
        search: '',
        users: eligibleSMUsers,
        hideAddButtonSeatOnErrorMessage: true,
      };

      expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
    });

    it('calls addOnEligibleUsers query with appropriate params', () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(duoProDefaultQueryVariables);
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

    it('fetches users list by assigned seats', async () => {
      const filterOptions = { filterByAssignedSeat: 'true' };

      findSearchAndSortBar().vm.$emit('on-filter', { filterByAssignedSeat: 'true' });
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        ...filterOptions,
      });
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

    describe('with Duo with Amazon Q add-on tier', () => {
      beforeEach(() => {
        return createComponent({
          props: { activeDuoTier: DUO_AMAZON_Q, addOnPurchaseId: duoAmazonQAddOnPurchaseId },
        });
      });

      it('calls addOnEligibleUsers query with appropriate params', () => {
        expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(defaultDuoAmazonQQueryVariables);
      });
    });

    describe('when there is an error fetching add on eligible users', () => {
      beforeEach(() => {
        return createComponent({ handler: addOnEligibleUsersErrorHandler });
      });

      it('displays add-on eligible user list', () => {
        const expectedProps = {
          addOnPurchaseId: duoProAddOnPurchaseId,
          activeDuoTier: DUO_PRO,
          isLoading: false,
          pageInfo: undefined,
          pageSize: DEFAULT_PER_PAGE,
          search: '',
          users: [],
          hideAddButtonSeatOnErrorMessage: true,
        };

        expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
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
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays add-on eligible user list in loading state', () => {
      expect(findAddOnEligibleUserList().props('isLoading')).toBe(true);
    });
  });

  describe('pagination', () => {
    const { startCursor, endCursor } = pageInfoWithMorePages;

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

      const pageSize = 50;
      findAddOnEligibleUserList().vm.$emit('page-size-change', pageSize);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        first: pageSize,
      });
    });
  });

  describe('search', () => {
    const filterOptions = { search: 'test' };

    beforeEach(() => {
      return createComponent();
    });

    it('fetches users list matching the search term', async () => {
      findSearchAndSortBar().vm.$emit('on-filter', filterOptions);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...duoProDefaultQueryVariables,
        ...filterOptions,
      });
    });
  });

  describe('sort', () => {
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
  });
});
