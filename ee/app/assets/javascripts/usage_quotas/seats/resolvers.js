import Api from 'ee/api';
import * as GroupsApi from 'ee/api/groups_api';
import {
  HEADER_TOTAL_ENTRIES,
  HEADER_PAGE_NUMBER,
  HEADER_ITEMS_PER_PAGE,
} from 'ee/usage_quotas/seats/constants';

export const resolvers = {
  Query: {
    subscription(_, { namespaceId }) {
      return Api.userSubscription(namespaceId).then(({ data }) => {
        return {
          id: namespaceId,
          endDate: data.billing.subscription_end_date,
          startDate: data.billing.subscription_start_date,
          plan: {
            code: data.plan.code,
            name: data.plan.name,
            trial: Boolean(data.plan.trial),
            auto_renew: Boolean(data.plan.auto_renew),
            upgradable: Boolean(data.plan.upgradable),
            exclude_guests: Boolean(data.plan.exclude_guests),
          },
          usage: {
            seats_in_subscription: Number(data.usage?.seats_in_subscription) || 0,
            seats_in_use: Number(data.usage?.seats_in_use) || 0,
            max_seats_used: Number(data.usage?.max_seats_used) || 0,
            seats_owed: Number(data.usage?.seats_owed) || 0,
          },
          billing: {
            subscription_start_date: data.billing.subscription_start_date,
            subscription_end_date: data.billing.subscription_end_date,
          },
        };
      });
    },
    billableMembers(_, { namespaceId, page, search, sort }) {
      return GroupsApi.fetchBillableGroupMembersList(namespaceId, { page, search, sort }).then(
        ({ data, headers }) => {
          return {
            total: Number(headers[HEADER_TOTAL_ENTRIES]),
            page: Number(headers[HEADER_PAGE_NUMBER]),
            perPage: Number(headers[HEADER_ITEMS_PER_PAGE]),
            members: data || [],
          };
        },
      );
    },
    async billableMemberDetails(_, { namespaceId, memberId }) {
      const [{ data: memberships }, { data: indirectMembership }] = await Promise.all([
        GroupsApi.fetchBillableGroupMemberMemberships(namespaceId, memberId),
        GroupsApi.fetchBillableGroupMemberIndirectMemberships(namespaceId, memberId),
      ]);

      return {
        memberships: memberships.length ? memberships : indirectMembership,
        hasIndirectMembership: Boolean(indirectMembership?.length) && !memberships?.length,
      };
    },
  },
};
