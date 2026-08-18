import { resolvers } from 'ee/usage_quotas/seats/resolvers';
import Api from 'ee/api';
import * as GroupsApi from 'ee/api/groups_api';
import { mockMemberDetails } from 'ee_jest/usage_quotas/seats/mock_data';
import {
  HEADER_TOTAL_ENTRIES,
  HEADER_PAGE_NUMBER,
  HEADER_ITEMS_PER_PAGE,
} from 'ee/usage_quotas/seats/constants';

jest.mock('ee/api', () => {
  return {
    userSubscription: jest.fn(),
  };
});

jest.mock('ee/api/groups_api');

const subscriptionMockData = {
  billing: {
    subscription_end_date: '2024-12-31',
    subscription_start_date: '2024-01-01',
  },
  plan: {
    code: 'premium',
    name: 'Premium',
    trial: false,
    auto_renew: true,
    upgradable: true,
    exclude_guests: false,
  },
  usage: {
    seats_in_subscription: 10,
    seats_in_use: 8,
    max_seats_used: 9,
    seats_owed: 0,
  },
};

const subscriptionMockDataWithEmptyFields = {
  billing: {
    subscription_end_date: '2024-12-31',
    subscription_start_date: '2024-01-01',
  },
  plan: {
    code: 'premium',
    name: 'Premium',
  },
};

describe('resolvers', () => {
  describe('Query', () => {
    describe('subscription', () => {
      const namespaceId = 1;

      let subscriptionTestResult;

      beforeEach(async () => {
        jest.spyOn(Api, 'userSubscription').mockResolvedValue({ data: subscriptionMockData });
        subscriptionTestResult = await resolvers.Query.subscription(null, { namespaceId });
      });

      it('calls userSubscription API with correct namespace ID', () => {
        expect(Api.userSubscription).toHaveBeenCalledWith(namespaceId);
      });

      it('transforms API response into expected format', () => {
        expect(subscriptionTestResult).toEqual({
          id: namespaceId,
          endDate: '2024-12-31',
          startDate: '2024-01-01',
          plan: {
            code: 'premium',
            name: 'Premium',
            trial: false,
            auto_renew: true,
            upgradable: true,
            exclude_guests: false,
          },
          usage: {
            seats_in_subscription: 10,
            seats_in_use: 8,
            max_seats_used: 9,
            seats_owed: 0,
          },
          billing: {
            subscription_start_date: '2024-01-01',
            subscription_end_date: '2024-12-31',
          },
        });
      });

      describe('when response does not include all data', () => {
        beforeEach(async () => {
          jest
            .spyOn(Api, 'userSubscription')
            .mockResolvedValue({ data: subscriptionMockDataWithEmptyFields });
          subscriptionTestResult = await resolvers.Query.subscription(null, { namespaceId });
        });

        it('provides default values for undefined fields', () => {
          expect(subscriptionTestResult).toEqual({
            id: namespaceId,
            endDate: '2024-12-31',
            startDate: '2024-01-01',
            plan: {
              code: 'premium',
              name: 'Premium',
              trial: false,
              auto_renew: false,
              upgradable: false,
              exclude_guests: false,
            },
            usage: {
              seats_in_subscription: 0,
              seats_in_use: 0,
              max_seats_used: 0,
              seats_owed: 0,
            },
            billing: {
              subscription_start_date: '2024-01-01',
              subscription_end_date: '2024-12-31',
            },
          });
        });
      });
    });

    describe('billableMembers', () => {
      const mockBillableMembersResponse = {
        data: [
          { id: 1, name: 'Paul Slaughter' },
          { id: 2, name: 'Lukas Eipert' },
        ],
        headers: {
          [HEADER_TOTAL_ENTRIES]: '100',
          [HEADER_PAGE_NUMBER]: '2',
          [HEADER_ITEMS_PER_PAGE]: '20',
        },
      };

      let billableMembersResult;

      beforeEach(async () => {
        GroupsApi.fetchBillableGroupMembersList.mockResolvedValueOnce(mockBillableMembersResponse);

        billableMembersResult = await resolvers.Query.billableMembers(null, {
          namespaceId: 0,
          page: 1,
          search: 'test search',
          sort: 'test sort',
        });
      });

      it('calls fetchBillableGroupMembersList with the correct arguments', () => {
        expect(GroupsApi.fetchBillableGroupMembersList).toHaveBeenCalledTimes(1);
        expect(GroupsApi.fetchBillableGroupMembersList).toHaveBeenCalledWith(0, {
          page: 1,
          search: 'test search',
          sort: 'test sort',
        });
      });

      it('returns parsed data', () => {
        expect(billableMembersResult).toEqual({
          total: 100,
          page: 2,
          perPage: 20,
          members: mockBillableMembersResponse.data,
        });
      });
    });

    describe('billableMemberDetails', () => {
      const mockIndirectMemberDetails = { ...mockMemberDetails, hasIndirectMembership: true };

      let billableMemberDetailsResult;

      beforeEach(async () => {
        GroupsApi.fetchBillableGroupMemberMemberships.mockResolvedValueOnce({
          data: mockMemberDetails,
        });
        GroupsApi.fetchBillableGroupMemberIndirectMemberships.mockResolvedValueOnce({
          data: mockMemberDetails,
        });
        billableMemberDetailsResult = await resolvers.Query.billableMemberDetails(null, {
          namespaceId: 1,
          memberId: 2,
        });
      });

      it('calls fetchBillableGroupMemberMemberships and fetchBillableGroupMemberIndirectMemberships endpoints', () => {
        expect(GroupsApi.fetchBillableGroupMemberMemberships).toHaveBeenCalledWith(1, 2);
        expect(GroupsApi.fetchBillableGroupMemberIndirectMemberships).toHaveBeenCalledWith(1, 2);

        expect(billableMemberDetailsResult).toMatchObject({
          hasIndirectMembership: false,
          memberships: [
            {
              id: 173,
              source_id: 155,
              source_full_name: 'group_with_ultimate_plan / subgroup',
              created_at: '2021-02-25T08:21:32.257Z',
              expires_at: null,
              access_level: { string_value: 'Owner', integer_value: 50 },
            },
          ],
        });
      });

      describe.each`
        membershipApiRes       | indirectMembershipApiRes       | hasIndirectMembership
        ${[mockMemberDetails]} | ${[mockIndirectMemberDetails]} | ${false}
        ${[mockMemberDetails]} | ${[]}                          | ${false}
        ${[]}                  | ${[mockIndirectMemberDetails]} | ${true}
        ${[]}                  | ${[]}                          | ${false}
      `(
        'return the corrct hasIndirectMembership value',
        ({ membershipApiRes, indirectMembershipApiRes, hasIndirectMembership }) => {
          beforeEach(async () => {
            GroupsApi.fetchBillableGroupMemberMemberships.mockResolvedValue({
              data: membershipApiRes,
            });
            GroupsApi.fetchBillableGroupMemberIndirectMemberships.mockResolvedValue({
              data: indirectMembershipApiRes,
            });
            billableMemberDetailsResult = await resolvers.Query.billableMemberDetails(null, {
              namespaceId: 1,
              memberId: 2,
            });
          });

          it(`commits the correct mutation when response ${membershipApiRes.length ? 'does' : 'does not'} include membership and ${indirectMembershipApiRes.length ? 'does' : 'does not'} include indirect membership`, () => {
            expect(billableMemberDetailsResult).toMatchObject({
              hasIndirectMembership,
            });
          });
        },
      );
    });
  });
});
