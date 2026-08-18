import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

// Billable Seats HTTP headers
export const HEADER_TOTAL_ENTRIES = 'x-total';
export const HEADER_PAGE_NUMBER = 'x-page';
export const HEADER_ITEMS_PER_PAGE = 'x-per-page';
export const PLAN_CODE_FREE = 'free';

export const FIELDS = [
  {
    key: 'disclosure',
    label: __('Disclosure'),
    thClass: '!gl-p-0 gl-sr-only',
    tdClass: '!gl-p-0 !gl-align-middle',
  },
  {
    key: 'user',
    label: __('User'),
    thClass: `gl-w-6/20 !gl-pl-2`,
    tdClass: '!gl-align-middle !gl-pl-2',
  },
  {
    key: 'email',
    label: __('Email'),
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  {
    key: 'lastActivityTime',
    label: __('Last GitLab activity'),
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  {
    key: 'lastLoginAt',
    label: __('Last login'),
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  {
    key: 'actions',
    label: __('Actions'),
    thClass: 'gl-w-2/20',
    tdClass: '!gl-align-middle gl-text-right',
  },
];

export const membershipDetailsFields = (indirect) => {
  return [
    {
      key: 'source_full_name',
      label: indirect ? s__('Billing|Invited group') : s__('Billing|Direct memberships'),
    },
    { key: 'created_at', label: __('Access granted') },
    { key: 'expires_at', label: __('Access expires') },
    { key: 'role', label: __('Role') },
  ].map((field) => ({
    ...field,
    thClass: '!gl-border-0',
    tdClass: '!gl-border-0',
  }));
};

export const CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID = 'cannot-remove-member-modal';
export const CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE = s__('Billing|Cannot remove user');
export const CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT = s__(
  `Billing|Members who were invited via a group invitation cannot be removed.
  You can either remove the entire group, or ask an Owner of the invited group to remove the member.`,
);
export const DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX = 'group-members-deleted';
export const DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX = 'group-members-deleted.expires';
export const REMOVE_BILLABLE_MEMBER_MODAL_ID = 'billable-member-remove-modal';
export const REMOVE_BILLABLE_MEMBER_MODAL_CONTENT_TEXT_TEMPLATE = s__(
  `Billing|You are about to remove user %{username} from your subscription.
If you continue, the user will be removed from the %{namespace}
group and all its subgroups and projects. This action can't be undone.`,
);
export const AVATAR_SIZE = 32;
export const SORT_OPTIONS = [
  {
    id: 10,
    title: __('Last GitLab activity'),
    sortDirection: {
      descending: 'last_activity_on_desc',
      ascending: 'last_activity_on_asc',
    },
  },
  {
    id: 20,
    title: __('Name'),
    sortDirection: {
      descending: 'name_desc',
      ascending: 'name_asc',
    },
  },
  {
    id: 30,
    title: __('Last login'),
    sortDirection: {
      descending: 'recent_sign_in',
      ascending: 'oldest_sign_in',
    },
  },
];
export const EXPLORE_PAID_PLANS_CLICKED = 'explore_paid_plans_clicked';
export const seatsInUseLink = helpPagePath('subscriptions/manage_seats', {
  anchor: 'gitlabcom-billing-and-usage',
});
export const seatsOwedLink = helpPagePath('subscriptions/manage_seats', {
  anchor: 'users-over-subscription-limit',
});
export const seatsUsedLink = helpPagePath('subscriptions/manage_subscription', {
  anchor: 'view-subscription',
});
export const emailNotVisibleTooltipText = s__(
  'Billing|An email address is only visible for users with public emails.',
);
export const filterUsersPlaceholder = __('Filter users');
export const inASeatLabel = s__('Billings|In a seat');
export const seatsUsedText = __('Max seats used');
export const seatsUsedHelpText = __('Learn more about max seats used');
export const seatsOwedText = __('Seats owed');
export const seatsOwedHelpText = __('Learn more about seats owed');
export const addSeatsText = s__('Billing|Add seats');
export const seatsUsedDescriptionText = s__('Billing|%{plan} SaaS Plan seats used');
