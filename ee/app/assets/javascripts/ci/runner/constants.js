import { s__ } from '~/locale';
import { DOCS_URL } from '~/constants';

// Filtered search parameter names
// - Used for URL params names
// - GlFilteredSearch tokens type

export const PARAM_KEY_UPGRADE_STATUS = 'upgrade_status';

// CiRunnerUpgradeStatus

export const UPGRADE_STATUS_AVAILABLE = 'AVAILABLE';
export const UPGRADE_STATUS_RECOMMENDED = 'RECOMMENDED';
export const UPGRADE_STATUS_NOT_AVAILABLE = 'NOT_AVAILABLE';

export const I18N_UPGRADE_STATUS_AVAILABLE = s__('Runners|Upgrade available');
export const I18N_UPGRADE_STATUS_RECOMMENDED = s__('Runners|Upgrade recommended');

export const I18N_UPGRADE_STATUS_AVAILABLE_TOOLTIP = s__('Runners|A new version is available');
export const I18N_UPGRADE_STATUS_RECOMMENDED_TOOLTIP = s__(
  'Runners|This runner is outdated, an upgrade is recommended',
);

export const I18N_MEDIAN = s__('Runners|Median');
export const I18N_P75 = s__('Runners|75th percentile');
export const I18N_P90 = s__('Runners|90th percentile');
export const I18N_P99 = s__('Runners|99th percentile');

// Help pages

// Runner install help page is external from this repo, must be
// hardcoded because is located at https://gitlab.com/gitlab-org/gitlab-runner
const RUNNER_HELP_PATH = `${DOCS_URL}/runner`;

// eslint-disable-next-line @gitlab/no-hardcoded-urls -- external docs URL for gitlab-runner project
export const RUNNER_UPGRADE_HELP_PATH = `${RUNNER_HELP_PATH}/install/#upgrading-gitlab-runner`;

export const RUNNER_VERSION_HELP_PATH = `${RUNNER_HELP_PATH}#gitlab-runner-versions`;
