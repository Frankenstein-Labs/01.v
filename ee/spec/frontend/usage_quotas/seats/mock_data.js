export const mockMemberDetails = [
  {
    id: 173,
    source_id: 155,
    source_full_name: 'group_with_ultimate_plan / subgroup',
    created_at: '2021-02-25T08:21:32.257Z',
    expires_at: null,
    access_level: { string_value: 'Owner', integer_value: 50 },
  },
];

export const mockTableItems = [
  {
    id: 2,
    email: 'administrator@email.com',
    avatar_url: 'path/to/img_administrator',
    name: 'Administrator',
    username: 'root',
    web_url: 'path/to/administrator',
    last_activity_on: '2020-03-01',
    last_login_at: '2022-11-10T10:58:05.492Z',
    membership_type: 'group_member',
    membership_state: 'active',
    removable: true,
    is_last_owner: true,
  },
  {
    id: 3,
    email: 'agustin_walker@email.com',
    avatar_url: 'path/to/img_agustin_walker',
    name: 'Agustin Walker',
    username: 'lester.orn',
    web_url: 'path/to/agustin_walker',
    last_activity_on: '2020-03-01',
    last_login_at: '2021-01-20T10:58:05.492Z',
    membership_type: 'project_member',
    membership_state: 'active',
    removable: true,
    is_last_owner: false,
  },
  {
    id: 4,
    email: null,
    avatar_url: 'path/to/img_joella_miller',
    name: 'Joella Miller',
    username: 'era',
    web_url: 'path/to/joella_miller',
    last_activity_on: null,
    last_login_at: null,
    membership_type: 'group_invite',
    membership_state: 'active',
    removable: false,
    is_last_owner: false,
  },
  {
    id: 5,
    email: 'jdoe@email.com',
    avatar_url: 'path/to/img_john_doe',
    name: 'John Doe',
    username: 'jdoe',
    web_url: 'path/to/john_doe',
    last_activity_on: null,
    last_login_at: null,
    membership_type: 'project_invite',
    membership_state: 'awaiting',
    removable: false,
    is_last_owner: false,
  },
  {
    id: 6,
    email: 'jsnow@email.com',
    avatar_url: 'path/to/img_john_snow',
    name: 'John Snow',
    username: 'jown.snow',
    web_url: 'path/to/john_snow',
    last_activity_on: '2020-03-01',
    last_login_at: null,
    membership_type: 'group_member',
    membership_state: 'awaiting',
    removable: true,
    is_last_owner: false,
  },
  {
    id: 7,
    email: 'current_user@email.com',
    avatar_url: 'path/to/img_curent_user',
    name: 'Current user',
    username: 'current.user',
    web_url: 'path/to/current_user',
    last_activity_on: '2020-03-01',
    last_login_at: null,
    membership_type: 'group_member',
    membership_state: 'active',
    removable: true,
    is_last_owner: false,
  },
];

const subscriptionStartDate = '2023-03-16';
const subscriptionEndDate = '2024-03-16';

// Generates mock data for @client `ee/usage_quotas/seats/graphql/get_gitlab_subscription.query.graphql`
// as defined in `ee/usage_quotas/seats/resolvers.js`
const createMockSubscription = ({
  id = 1,
  endDate = subscriptionEndDate,
  startDate = subscriptionStartDate,
  code,
  name,
  seatsInSubscription = 0,
  seatsInUse = 0,
  maxSeatsUsed = 0,
  seatsOwed = 0,
  trial = false,
  trialEndsOn = null,
} = {}) =>
  Object.freeze({
    id,
    endDate,
    startDate,
    __typename: 'Subscription',
    plan: {
      __typename: 'Plan',
      code,
      name,
      trial,
      auto_renew: false,
      upgradable: false,
      exclude_guests: false,
    },
    usage: {
      seats_in_subscription: seatsInSubscription,
      seats_in_use: seatsInUse,
      max_seats_used: maxSeatsUsed,
      seats_owed: seatsOwed,
    },
    billing: {
      subscription_start_date: startDate,
      subscription_end_date: endDate,
      trial_ends_on: trialEndsOn,
    },
  });

export const createMockFreeSubscription = (config) =>
  createMockSubscription({
    ...config,
    code: 'free',
    name: 'Free',
  });

export const createMockUltimateSubscription = (config) =>
  createMockSubscription({
    ...config,
    code: 'ultimate',
    name: 'Ultimate',
  });

// Mock for CDot ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql
export const createMockSubscriptionPermissionsResponse = ({
  canAddSeats = false,
  canRenew = false,
  communityPlan = false,
  canAddDuoProSeats = false,
} = {}) => ({
  data: {
    subscription: {
      canAddSeats,
      canRenew,
      communityPlan,
      canAddDuoProSeats,
    },
    userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
  },
});
