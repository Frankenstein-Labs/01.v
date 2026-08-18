import { __, s__ } from '~/locale';
import { PROMO_URL } from '~/constants';

export const subscriptionMainTitle = s__('SuperSonics|Subscription');
export const subscriptionActivationNotificationText = s__(
  `SuperSonics|Your subscription was successfully activated. You can see the details below.`,
);
export const subscriptionActivationFutureDatedNotificationTitle = s__(
  'SuperSonics|Your future dated license was successfully added',
);
export const subscriptionActivationFutureDatedNotificationMessage = s__(
  'SuperSonics|You have successfully added a license that activates on %{date}. Please see the subscription history table below for more details.',
);
export const subscriptionActivationInsertCode = __(
  'Find the activation code for a purchased or renewed subscription in the %{linkStart}Customers Portal%{linkEnd} or purchase confirmation email.',
);
export const howToActivateSubscription = s__(
  'SuperSonics|Learn how to %{linkStart}activate your subscription%{linkEnd}.',
);
export const subscriptionHistoryFailedTitle = s__('SuperSonics|Subscription unavailable');
export const subscriptionHistoryFailedMessage = s__(
  'SuperSonics|Your %{subscriptionEntryName} cannot be displayed at the moment. Please refresh the page to try again.',
);
export const currentSubscriptionsEntryName = s__('SuperSonics|current subscription');
export const pastSubscriptionsEntryName = s__('SuperSonics|past subscriptions');
export const futureSubscriptionsEntryName = s__('SuperSonics|future subscriptions');

export const cancelLabel = __('Cancel');
export const activateLabel = s__('AdminUsers|Activate');
export const activateSubscription = s__('SuperSonics|Activate subscription');
export const addActivationCode = s__('SuperSonics|Add activation code');
export const subscriptionDetailsHeaderText = s__('SuperSonics|Subscription details');
export const licensedToHeaderText = s__('SuperSonics|Licensed to');
export const copySubscriptionIdButtonText = __('Copy');
export const licenseFileText = __('Legacy license');
export const onlineCloudLicenseText = s__('SuperSonics|Online license');
export const offlineCloudLicenseText = s__('SuperSonics|Offline license');
export const detailsLabels = {
  address: __('Address'),
  company: __('Company'),
  email: __('Email'),
  id: __('ID'),
  lastSync: s__('Subscriptions|Last sync'),
  name: licensedToHeaderText,
  plan: __('Plan'),
  subscriptionName: s__('SuperSonics|Subscription name'),
  type: __('Type'),
  expiresAt: s__('Subscriptions|End date'),
  startsAt: s__('Subscriptions|Start date'),
};

export const subscriptionTable = {
  activatedAt: s__('Subscriptions|Activation date'),
  expiresOn: s__('Subscriptions|End date'),
  seats: __('Seats'),
  startsAt: s__('Subscriptions|Start date'),
  title: __('Subscription History'),
  type: __('Type'),
};

export const subscriptionActivationForm = {
  activationCode: s__('SuperSonics|Activation code'),
  activationCodeFeedback: s__(
    'SuperSonics|The activation code should be a 24-character alphanumeric string',
  ),
  pasteActivationCode: s__('SuperSonics|Enter activation code'),
  acceptTerms: s__(
    'SuperSonics|I agree that my use of the GitLab Software is subject to the Subscription Agreement located at the %{linkStart}Terms of Service%{linkEnd}, unless otherwise agreed to in writing with GitLab.',
  ),
  acceptTermsFeedback: s__('SuperSonics|Select that you agree before activating the subscription.'),
};

export const addLicenseKey = s__(
  'SuperSonics|Received a license key? %{linkStart}Go to license settings%{linkEnd} to add it to your GitLab instance.',
);

export const manageSubscription = s__('SuperSonics|Manage subscription');

export const subscriptionSyncStatus = {
  SYNC_FAILURE: 'SYNC_FAILURE',
  SYNC_PENDING: 'SYNC_PENDING',
  SYNC_SUCCESS: 'SYNC_SUCCESS',
};

export const subscriptionTypes = {
  ONLINE_CLOUD: 'online_cloud',
  OFFLINE_CLOUD: 'offline_cloud',
  LEGACY_LICENSE: 'legacy_license',
};

export const SUBSCRIPTION_ACTIVATION_FAILURE_EVENT = 'subscription-activation-failure';
export const SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT = 'subscription-activation-success';
export const SUBSCRIPTION_ACTIVATION_FINALIZED_EVENT = 'subscription-activation-finalized';

// Server-sent error messages (or regexes to match those messages) to detect error type
export const INVALID_ACTIVATION_CODE_SERVER_ERROR = 'invalid activation code';
export const EXPIRED_LICENSE_SERVER_ERROR = 'This license has already expired.';
export const EXPIRED_TRIAL_SERVER_ERROR = 'Trial has expired';
export const SILENT_MODE_ENABLED_ERROR =
  'only get, head, options, and trace methods are allowed in silent mode';
export const SUBSCRIPTION_NOT_FOUND_SERVER_ERROR = 'without cloud compatible subscription';
export const SUBSCRIPTION_OVERAGES_SERVER_ERROR_REGEX =
  /(This GitLab installation currently has|During the year before this license started, this GitLab installation had) (\d+) active users?, exceeding this license's limit of (\d+) by (\d+) users?\. Please add a license for at least (\d+) users? or contact sales at https:\/\/about\.gitlab\.com\/sales\//;
export const SUBSCRIPTION_INSUFFICIENT_TRUE_UP_SERVER_ERROR_REGEX =
  /You have applied a True-up for (\d+) users? but you need one for (\d+) users?\. Please contact sales at https:\/\/about\.gitlab\.com\/sales\//;

export const CONNECTIVITY_ERROR = 'CONNECTIVITY_ERROR';
export const INVALID_CODE_ERROR = 'INVALID_CODE_ERROR';

export const supportLink = `${PROMO_URL}/support/#contact-support`;
export const exportLicenseUsageBtnText = s__('SuperSonics|Export license usage file');

export const instanceHasFutureLicenseBanner = {
  title: s__('SuperSonics|You have a future dated license'),
  message: s__(
    'SuperSonics|You have added a license that activates on %{date}. Please see the subscription history table below for more details.',
  ),
};

// Subscription Sync Button
export const SYNC_BUTTON_ID = 'syncButton';
export const syncButtonTexts = Object.freeze({
  syncSubscriptionButtonText: s__('SuperSonics|Sync subscription details'),
  syncSubscriptionTooltipText: s__(
    'SuperSonics|You can sync your subscription data to ensure your details are up to date.',
  ),
});

export const VIEW_ADMIN_SUBSCRIPTION_PAGELOAD = 'view_admin_subscription_pageload';
