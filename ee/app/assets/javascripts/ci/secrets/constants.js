import { GL_COLOR_BLUE_100, GL_COLOR_NEUTRAL_100 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { __, s__ } from '~/locale';

export const SECRET_DESCRIPTION_MAX_LENGTH = 200;
export const BRANCH_QUERY_LIMIT = 100;
export const PROJECT_SECRETS_QUERY_LIMIT = 100;
export const GROUP_SECRETS_QUERY_LIMIT = 500;

export const ALL_BRANCHES_OPTION = {
  value: '*',
  text: '*',
};

export const ALL_BRANCHES_TOGGLE_TEXT = __('All (default)');

export const INDEX_ROUTE_NAME = 'index';
export const NEW_ROUTE_NAME = 'new';
export const DETAILS_ROUTE_NAME = 'details';
export const EDIT_ROUTE_NAME = 'edit';

export const SCOPED_LABEL_COLOR = GL_COLOR_BLUE_100;
export const UNSCOPED_LABEL_COLOR = GL_COLOR_NEUTRAL_100;

// contexts the secrets manager page works in
export const ENTITY_GROUP = 'group';
export const ENTITY_PROJECT = 'project';
export const ACCEPTED_CONTEXTS = [ENTITY_GROUP, ENTITY_PROJECT];

export const ACTION_ENABLE_SECRET_MANAGER = 'ENABLE_SECRET_MANAGER';
export const ACTION_DISABLE_SECRET_MANAGER = 'DISABLE_SECRET_MANAGER';
export const SECRET_MANAGER_STATUS_ACTIVE = 'ACTIVE';
export const SECRET_MANAGER_STATUS_INACTIVE = 'INACTIVE';
export const SECRET_MANAGER_STATUS_PROVISIONING = 'PROVISIONING';
export const SECRET_MANAGER_STATUS_DEPROVISIONING = 'DEPROVISIONING';
export const SECRET_MANAGER_STATUS_ERROR = 'ERROR'; // when we fail to fetch the status

export const SECRET_STATUS_ICONS_OPTICALLY_ALIGNED = [
  'COMPLETED',
  'CREATE_IN_PROGRESS',
  'UPDATE_IN_PROGRESS',
];

export const SECRET_STATUS = {
  COMPLETED: {
    icon: 'status-success',
    iconSize: 'sm',
    variant: 'success',
    text: __('Healthy'),
    description: s__('SecretsManager|Secret created or updated successfully.'),
  },
  CREATE_IN_PROGRESS: {
    icon: 'status-running',
    iconSize: 'sm',
    variant: 'neutral',
    text: __('Creating'),
    description: s__('SecretsManager|Secret is being created.'),
  },
  CREATE_STALE: {
    icon: 'warning-solid',
    iconSize: 'sm',
    variant: 'danger',
    text: __('Needs attention'),
    description: s__('SecretsManager|Secret creation failed. Delete the secret and try again.'),
  },
  UPDATE_IN_PROGRESS: {
    icon: 'status-running',
    iconSize: 'sm',
    variant: 'neutral',
    text: __('Updating'),
    description: s__('SecretsManager|Secret is being updated.'),
  },
  UPDATE_STALE: {
    icon: 'warning-solid',
    iconSize: 'sm',
    variant: 'danger',
    text: __('Needs attention'),
    description: s__('SecretsManager|Secret update failed. Retry the update or delete the secret.'),
  },
};

export const SECRET_ROTATION_STATUS = {
  approaching: 'APPROACHING',
  overdue: 'OVERDUE',
};

export const POLL_INTERVAL = 2000;

// event tracking
export const GROUP_EVENTS = {
  pageVisit: 'visit_group_secrets_manager',
};

export const PROJECT_EVENTS = {
  pageVisit: 'visit_project_secrets_manager',
};

export const PAGE_VISIT_EDIT = 'edit_form';
export const PAGE_VISIT_NEW = 'create_form';
export const PAGE_VISIT_SECRET_DETAILS = 'secret_details_page';
export const PAGE_VISIT_SECRETS_TABLE = 'secrets_table_page';

export const I18N_OPEN_BETA_ALERT = {
  title: s__('SecretsManager|Charges may be incurred at the end of open beta'),
  description: s__(
    'SecretsManager|GitLab Secrets Manager is free during open beta, but will consume %{linkStart}GitLab Credits%{linkEnd} when it becomes generally available. Credits will be consumed only if you opt in. You will receive advance notice before general availability.',
  ),
};

export const I18N_BILLING_ALERT = {
  onDemandEnabled: {
    title: s__('SecretsManager|On-demand is enabled'),
  },
  onDemandDisabled: {
    title: s__('SecretsManager|Enable on-demand billing to try GitLab Secrets Manager'),
  },
  description: s__(
    'SecretsManager|After the trial period, GitLab Secrets Manager consumes GitLab credits to store and fetch secrets. Enable on-demand billing to avoid a service interruption when the trial ends.',
  ),
  linkText: s__('SecretsManager|How is GitLab Secrets Manager billed?'),
};

// Entitlement states — mirrors SecretsManagement::Entitlement::STATES
export const ENTITLEMENT_STATE_TRIAL_ELIGIBLE = 'TRIAL_ELIGIBLE';
export const ENTITLEMENT_STATE_TRIAL = 'TRIAL';
export const ENTITLEMENT_STATE_PAID = 'PAID';
export const ENTITLEMENT_STATE_OFFLINE_PAID = 'OFFLINE_PAID';
export const ENTITLEMENT_STATE_BLOCKED = 'BLOCKED';
export const ENTITLEMENT_STATE_INELIGIBLE = 'INELIGIBLE';

// Blocked reasons — mirrors SecretsManagement::Entitlement::BLOCKED_REASONS
export const BLOCKED_REASON_CREDITS_EXHAUSTED = 'CREDITS_EXHAUSTED';
export const BLOCKED_REASON_GRACE = 'GRACE';
export const BLOCKED_REASON_ON_DEMAND_DISABLED = 'ON_DEMAND_DISABLED';
export const BLOCKED_REASON_SUBSCRIPTION_CANCELLED = 'SUBSCRIPTION_CANCELLED';
export const BLOCKED_REASON_TRIAL_EXPIRED = 'TRIAL_EXPIRED';

export const I18N_TRIAL_ALERT = {
  descriptionNoOnDemand: s__(
    'SecretsManagerTrial|Contact your billing administrator to enable on-demand billing and avoid disruption.',
  ),
  titleCreditsRemaining: s__(
    'SecretsManagerTrial|%{creditsRemaining}%% of credits left in secrets manager trial',
  ),
  titleTrialDaysRemaining: s__(
    'SecretsManagerTrial|Secrets manager trial ends in %{trialDaysRemaining} days',
  ),
};

export const TRIAL_ALERT_OPTIONS_CREDITS_LOW = {
  onDemandEnabled: {
    variant: 'warning',
    title: I18N_TRIAL_ALERT.titleCreditsRemaining,
    description: s__(
      'SecretsManagerTrial|On-demand billing is enabled, and you will incur charges after the trial period ends. %{linkStart}How is secrets manager billed?%{linkEnd}',
    ),
  },
  onDemandDisabled: {
    variant: 'warning',
    title: I18N_TRIAL_ALERT.titleCreditsRemaining,
    description: I18N_TRIAL_ALERT.descriptionNoOnDemand,
  },
};

// shown while the trial is still active: with on-demand billing enabled,
// usage continues at 0 credits and overage charges start immediately
export const TRIAL_ALERT_OPTIONS_CREDITS_EXHAUSTED = {
  variant: 'warning',
  title: s__('SecretsManagerTrial|All trial credits used'),
  description: s__(
    'SecretsManagerTrial|On-demand billing is enabled, and you are incurring charges for continued usage. %{linkStart}How is secrets manager billed?%{linkEnd}',
  ),
};

export const TRIAL_ALERT_OPTIONS_TRIAL_EXPIRING = {
  onDemandEnabled: {
    variant: 'warning',
    title: I18N_TRIAL_ALERT.titleTrialDaysRemaining,
    description: s__(
      'SecretsManagerTrial|On-demand billing is enabled. When all trial credits are consumed, GitLab credits will be used. Disable secrets manager to stop credit consumption.',
    ),
  },
  onDemandDisabled: {
    variant: 'warning',
    title: I18N_TRIAL_ALERT.titleTrialDaysRemaining,
    description: I18N_TRIAL_ALERT.descriptionNoOnDemand,
  },
};

export const TRIAL_ALERT_OPTIONS_BLOCKED = {
  [BLOCKED_REASON_CREDITS_EXHAUSTED]: {
    variant: 'danger',
    title: s__('SecretsManagerTrial|0 credits left in secrets manager trial'),
    description: I18N_TRIAL_ALERT.descriptionNoOnDemand,
  },
  [BLOCKED_REASON_GRACE]: {
    variant: 'danger',
    title: s__('SecretsManagerTrial|Your secrets manager subscription has been cancelled'),
    description: s__(
      'SecretsManagerTrial|You have a short grace period remaining before access is removed. Contact your billing administrator to enable on-demand billing and avoid disruption.',
    ),
  },
  [BLOCKED_REASON_ON_DEMAND_DISABLED]: {
    variant: 'danger',
    title: s__('SecretsManagerTrial|On-demand billing is disabled'),
    description: I18N_TRIAL_ALERT.descriptionNoOnDemand,
  },
  [BLOCKED_REASON_SUBSCRIPTION_CANCELLED]: {
    variant: 'danger',
    title: s__(
      'SecretsManagerTrial|Your secrets manager add-on has been removed from your license',
    ),
    description: I18N_TRIAL_ALERT.descriptionNoOnDemand,
  },
  [BLOCKED_REASON_TRIAL_EXPIRED]: {
    variant: 'danger',
    title: s__('SecretsManagerTrial|Secrets manager trial period has ended'),
    description: I18N_TRIAL_ALERT.descriptionNoOnDemand,
  },
};

export const TRIAL_EXPIRING_SOON_DAYS = 10;
export const TRIAL_CREDITS_LOW_PERCENTAGE = 10;

// When TLG starts a trial, we chain three mutations: enrollment, trial,
// provisioning. Backend returning these error strings should be treated
// as a success in the trial-button-chain so a retry on partial progress
// no-ops instead of surfacing a misleading error.
// Matched literally against server response text -- not user-facing copy.
/* eslint-disable @gitlab/require-i18n-strings */
export const BENIGN_ENROLL_ERRORS = ['Namespace is already enrolled.'];
export const BENIGN_TRIAL_ERRORS = ['A Secrets Manager trial is already active for this group.'];
export const BENIGN_PROVISION_ERRORS = ['Secrets manager already initialized for the group.'];
/* eslint-enable @gitlab/require-i18n-strings */

export const I18N_TRIAL_STARTED_ALERT = s__(
  'SecretsManager|The GitLab Secrets Manager trial has been enabled for all groups and projects within this namespace. %{linkStart}Manage group permissions.%{linkEnd}',
);

export const I18N_SECRETS_EMPTY_STATE = {
  title: s__('SecretsManager|Secure your sensitive information'),
  description: s__(
    'SecretsManager|Use the secrets manager to store your sensitive credentials, and then safely use them in your processes.',
  ),
  groupSubheader: s__(
    'SecretsManager|By default, all subgroups and projects can use stored secrets in their pipelines.',
  ),
};
