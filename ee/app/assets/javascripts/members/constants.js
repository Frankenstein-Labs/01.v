import { GlFilteredSearchToken } from '@gitlab/ui';
import { groupMemberRequestFormatter } from '~/groups/members/utils';

import { __, n__, s__, sprintf } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  AVAILABLE_FILTERED_SEARCH_TOKENS as AVAILABLE_FILTERED_SEARCH_TOKENS_CE,
  MEMBERS_TAB_TYPES as MEMBERS_TAB_TYPES_CE,
  TAB_QUERY_PARAM_VALUES as CE_TAB_QUERY_PARAM_VALUES,
} from '~/members/constants';
import { helpPagePath } from '~/helpers/help_page_helper';

// eslint-disable-next-line import/export
export * from '~/members/constants';

export const DISABLE_TWO_FACTOR_MODAL_ID = 'disable-two-factor-modal';

export const I18N_CANCEL = __('Cancel');
export const I18N_DISABLE = __('Disable');
export const I18N_DISABLE_TWO_FACTOR_MODAL_TITLE = s__('Members|Disable two-factor authentication');

export const LDAP_OVERRIDE_CONFIRMATION_MODAL_ID = 'ldap-override-confirmation-modal';

export const FILTERED_SEARCH_TOKEN_ENTERPRISE = {
  type: 'enterprise',
  icon: 'work',
  title: __('Enterprise'),
  token: GlFilteredSearchToken,
  unique: true,
  operators: OPERATORS_IS,
  options: [
    { value: 'true', title: __('Yes') },
    { value: 'false', title: __('No') },
  ],
  requiredPermissions: 'canFilterByEnterprise',
};

export const FILTERED_SEARCH_USER_TYPE = {
  type: 'user_type',
  icon: 'account',
  title: __('Account'),
  token: GlFilteredSearchToken,
  unique: true,
  operators: OPERATORS_IS,
  options: [{ value: 'service_account', title: __('Service account') }],
  requiredPermissions: 'canManageMembers',
};

// eslint-disable-next-line import/export
export const AVAILABLE_FILTERED_SEARCH_TOKENS = [
  ...AVAILABLE_FILTERED_SEARCH_TOKENS_CE,
  FILTERED_SEARCH_TOKEN_ENTERPRISE,
  FILTERED_SEARCH_USER_TYPE,
];

// eslint-disable-next-line import/export
export const MEMBERS_TAB_TYPES = Object.freeze({
  ...MEMBERS_TAB_TYPES_CE,
  promotionRequest: 'promotionRequest',
  banned: 'banned',
});

// eslint-disable-next-line import/export
export const ACTION_BUTTONS = {
  [MEMBERS_TAB_TYPES.banned]: 'banned-action-buttons',
};

// eslint-disable-next-line import/export
export const TAB_QUERY_PARAM_VALUES = Object.freeze({
  ...CE_TAB_QUERY_PARAM_VALUES,
  promotionRequest: 'promotion_request',
  banned: 'banned',
});

const APP_OPTIONS_BASE = {
  [MEMBERS_TAB_TYPES.promotionRequest]: true,
};

const uniqueProjectDownloadLimitEnabled = gon.licensed_features?.uniqueProjectDownloadLimit;

// eslint-disable-next-line import/export
export const GROUPS_APP_OPTIONS = uniqueProjectDownloadLimitEnabled
  ? {
      ...APP_OPTIONS_BASE,
      [MEMBERS_TAB_TYPES.banned]: {
        tableFields: ['account', 'actions'],
        requestFormatter: groupMemberRequestFormatter,
      },
    }
  : APP_OPTIONS_BASE;

// eslint-disable-next-line import/export
export const PROJECTS_APP_OPTIONS = APP_OPTIONS_BASE;

export const GUEST_OVERAGE_MODAL_FIELDS = Object.freeze({
  TITLE: __('You are about to incur additional charges'),
  LINK: helpPagePath('subscriptions/quarterly_reconciliation'),
  BACK_BUTTON_LABEL: __('Cancel'),
  CONTINUE_BUTTON_LABEL: __('Continue with overages'),
  LINK_TEXT: __('%{linkStart} Learn more%{linkEnd}.'),
});

export const overageModalInfoText = (quantity) =>
  n__(
    'MembersOverage|Your subscription includes %d seat.',
    'MembersOverage|Your subscription includes %d seats.',
    quantity,
  );

export const overageModalInfoWarning = (quantity, groupName) =>
  sprintf(
    n__(
      'MembersOverage|If you continue, the %{groupName} group will have %{quantity} seat in use and will be billed for the overage.',
      'MembersOverage|If you continue, the %{groupName} group will have %{quantity} seats in use and will be billed for the overage.',
      quantity,
    ),
    {
      groupName,
      quantity,
    },
  );

export const MEMBER_ACCESS_LEVELS = {
  GUEST: 10,
};
