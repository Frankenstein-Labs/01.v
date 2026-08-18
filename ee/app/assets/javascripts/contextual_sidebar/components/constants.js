import { __, s__ } from '~/locale';

export const DUO_PRO = 'duo_pro';
export const DUO_ENTERPRISE = 'duo_enterprise';
export const ULTIMATE_WITH_DAP = 'ultimate_with_dap';
export const SELF_MANAGED_ULTIMATE = 'self_managed_ultimate';

export const TRIAL_WIDGET_REMAINING_DAYS = s__('TrialWidget|%{daysLeft} days left in trial');
export const TRIAL_WIDGET_LEARN_MORE = s__('TrialWidget|Learn more');
export const TRIAL_WIDGET_UPGRADE_TEXT = s__('TrialWidget|Upgrade');
export const TRIAL_WIDGET_SEE_UPGRADE_OPTIONS = s__('TrialWidget|See upgrade options');
export const TRIAL_WIDGET_DISMISS = __('Dismiss');

export const TRIAL_WIDGET_DUO_PRO_NAME = s__('TrialWidget|GitLab Duo Pro');
export const TRIAL_WIDGET_DUO_PRO_TITLE = s__('TrialWidget|GitLab Duo Pro Trial');
export const TRIAL_WIDGET_DUO_PRO_EXPIRED = s__(
  'TrialWidget|Your trial of GitLab Duo Pro has ended',
);

export const TRIAL_WIDGET_DUO_ENTERPRISE_NAME = s__('TrialWidget|GitLab Duo Enterprise');
export const TRIAL_WIDGET_DUO_ENTERPRISE_TITLE = s__('TrialWidget|GitLab Duo Enterprise Trial');
export const TRIAL_WIDGET_DUO_ENTERPRISE_EXPIRED = s__(
  'TrialWidget|Your trial of GitLab Duo Enterprise has ended',
);

export const TRIAL_WIDGET_ULTIMATE_DAP_NAME = s__(
  'TrialWidget|Ultimate with GitLab Duo Agent Platform',
);
export const TRIAL_WIDGET_ULTIMATE_DAP_TITLE = s__('TrialWidget|GitLab Ultimate Trial');
export const TRIAL_WIDGET_ULTIMATE_DAP_EXPIRED = s__(
  'TrialWidget|Your trial of GitLab Ultimate has ended',
);
export const TRIAL_WIDGET_SELF_MANAGED_ULTIMATE_TRACKING_LABEL = 'gitlab_ultimate_trial';
export const TRIAL_WIDGET_SELF_MANAGED_ULTIMATE_TITLE = s__('TrialWidget|GitLab Ultimate Trial');
export const TRIAL_WIDGET_SELF_MANAGED_ULTIMATE_EXPIRED = s__(
  'TrialWidget|Your trial of GitLab Ultimate has ended',
);

export const TRIAL_WIDGET_CONTAINER_ID = 'trial-sidebar-widget';
export const TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS = 30;

export const TRIAL_WIDGET_CLICK_UPGRADE = 'click_upgrade_link_on_trial_widget';
export const TRIAL_WIDGET_CLICK_LEARN_MORE = 'click_learn_more_link_on_trial_widget';
export const TRIAL_WIDGET_CLICK_DISMISS = 'click_dismiss_button_on_trial_widget';

export const TRIAL_TYPES_CONFIG = {
  [DUO_PRO]: {
    name: TRIAL_WIDGET_DUO_PRO_NAME,
    widgetTitle: TRIAL_WIDGET_DUO_PRO_TITLE,
    widgetTitleExpiredTrial: TRIAL_WIDGET_DUO_PRO_EXPIRED,
  },
  [DUO_ENTERPRISE]: {
    name: TRIAL_WIDGET_DUO_ENTERPRISE_NAME,
    widgetTitle: TRIAL_WIDGET_DUO_ENTERPRISE_TITLE,
    widgetTitleExpiredTrial: TRIAL_WIDGET_DUO_ENTERPRISE_EXPIRED,
  },
  [ULTIMATE_WITH_DAP]: {
    name: TRIAL_WIDGET_ULTIMATE_DAP_NAME,
    widgetTitle: TRIAL_WIDGET_ULTIMATE_DAP_TITLE,
    widgetTitleExpiredTrial: TRIAL_WIDGET_ULTIMATE_DAP_EXPIRED,
  },
  [SELF_MANAGED_ULTIMATE]: {
    name: TRIAL_WIDGET_SELF_MANAGED_ULTIMATE_TRACKING_LABEL,
    widgetTitle: TRIAL_WIDGET_SELF_MANAGED_ULTIMATE_TITLE,
    widgetTitleExpiredTrial: TRIAL_WIDGET_SELF_MANAGED_ULTIMATE_EXPIRED,
  },
};
