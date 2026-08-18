import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const USAGE_BY_MONTH = s__('UsageQuota|Compute usage by month');
export const USAGE_BY_PROJECT = s__('UsageQuota|Compute usage by project');
export const X_AXIS_MONTH_LABEL = __('Month');
export const X_AXIS_PROJECT_LABEL = __('Projects');
export const Y_AXIS_SHARED_RUNNER_LABEL = __('Duration (min)');
export const Y_AXIS_PROJECT_LABEL = __('Compute minutes');
export const NO_CI_MINUTES_MSG = s__('UsageQuota|No compute usage data available.');
export const CI_CD_MINUTES_USAGE = s__('UsageQuota|Compute usage');
export const SHARED_RUNNER_USAGE = s__('UsageQuota|Instance runner duration');

export const X_AXIS_CATEGORY = 'category';
export const formatWithUtc = true;

export const SHARED_RUNNER_POPOVER_OPTIONS = {
  placement: 'top',
  content: s__(
    'CICDAnalytics|Instance runner duration is the total runtime of all jobs that ran on instance runners',
  ),
  title: s__('CICDAnalytics|What is instance runner duration?'),
};

export const PROJECTS_TABLE_LABEL_PROJECT = __('Project');
export const PROJECTS_TABLE_LABEL_SHARED_RUNNERS = s__('UsageQuota|Instance runner duration');
export const PROJECTS_TABLE_LABEL_MINUTES = s__('UsageQuota|Compute usage');
export const PROJECTS_TABLE_FIELDS = [
  {
    key: 'project',
    label: PROJECTS_TABLE_LABEL_PROJECT,
    sortable: true,
  },
  {
    key: 'shared_runners',
    label: PROJECTS_TABLE_LABEL_SHARED_RUNNERS,
    sortable: true,
  },
  {
    key: 'ci_minutes',
    label: PROJECTS_TABLE_LABEL_MINUTES,
    sortable: true,
  },
];

export const ERROR_MESSAGE = s__(
  'UsageQuota|Something went wrong while fetching pipeline statistics',
);

export const PROJECTS_NO_SHARED_RUNNERS = s__(
  'UsageQuota|This namespace has no projects which used instance runners in the current period',
);
export const PROJECTS_TABLE_OMITS_MESSAGE = s__(
  'UsageQuota|This table omits projects that used 0 compute minutes or 0 instance runners duration',
);
export const LABEL_BUY_ADDITIONAL_MINUTES = s__('UsageQuota|Buy additional compute minutes');
export const LABEL_CI_MINUTES_DISABLED = s__(
  'UsageQuota|No compute usage data because %{linkStart}Instance runners%{linkEnd} are disabled, or there are no projects in this group.',
);
export const SHARED_RUNNERS_DOC_LINK = helpPagePath('ci/runners/_index.md');
