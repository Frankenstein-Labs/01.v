import { __, s__ } from '~/locale';
import { DOCS_URL } from '~/constants';

export const GROUP_BY = {
  NONE: null,
  // Values should be in sync with ProjectComplianceRequirementStatusOrderBy graphql enum
  REQUIREMENTS: 'REQUIREMENT',
  FRAMEWORKS: 'FRAMEWORK',
  PROJECTS: 'PROJECT',
};

// Checks and proper values sourced from:
// https://gitlab.com/gitlab-org/gitlab/-/blob/ea5e2706045c51ea2a2e408e39093da0aca3eec7/doc/api/graphql/reference/index.md#L25792
const PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR = 'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR';
const PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS = 'PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS';
const AT_LEAST_TWO_APPROVALS = 'AT_LEAST_TWO_APPROVALS';
const AT_LEAST_ONE_NON_AUTHOR_APPROVAL = 'AT_LEAST_ONE_NON_AUTHOR_APPROVAL';
const SAST = 'SAST';
const DAST = 'DAST';

export const NONE = s__('ComplianceStandardsAdherence|None');
export const CHECKS = s__('ComplianceStandardsAdherence|Checks');
export const PROJECTS = s__('ComplianceStandardsAdherence|Projects');
export const STANDARDS = s__('ComplianceStandardsAdherence|Standards');

export const FAIL_STATUS = 'FAIL';
export const NO_STANDARDS_ADHERENCES_FOUND = s__(
  'ComplianceStandardsAdherence|No projects with standards adherence checks found',
);
export const STANDARDS_ADHERENCE_FETCH_ERROR = s__(
  'ComplianceStandardsAdherence|Unable to load the standards adherence report. Refresh the page and try again.',
);

export const STANDARDS_ADHERENCE_CHECK_LABELS = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: s__(
    'ComplianceStandardsAdherence|Prevent authors as approvers',
  ),
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: s__(
    'ComplianceStandardsAdherence|Prevent committers as approvers',
  ),
  [AT_LEAST_TWO_APPROVALS]: s__('ComplianceStandardsAdherence|At least two approvals'),
  [AT_LEAST_ONE_NON_AUTHOR_APPROVAL]: s__(
    'ComplianceStandardsAdherence|At least one non-author approval',
  ),
  [SAST]: s__('ComplianceStandardsAdherence|SAST scan'),
  [DAST]: s__('ComplianceStandardsAdherence|DAST scan'),
};

export const STANDARDS_ADHERENCE_CHECK_DESCRIPTIONS = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: s__(
    'ComplianceStandardsAdherence|Have a valid rule that prevents author-approved merge requests from being merged',
  ),
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: s__(
    "ComplianceStandardsAdherence|Have a valid rule that prevents users from approving merge requests that they've added commits to",
  ),
  [AT_LEAST_TWO_APPROVALS]: s__(
    'ComplianceStandardsAdherence|Have a valid rule that prevents merge requests with fewer than two approvals from being merged',
  ),
  [AT_LEAST_ONE_NON_AUTHOR_APPROVAL]: s__(
    'ComplianceStandardsAdherence|Have a valid rule that prevents merge requests with fewer than one non-author approval from being merged',
  ),
  [SAST]: s__(
    'ComplianceStandardsAdherence|Have SAST scanner configured in pipeline configuration',
  ),
  [DAST]: s__(
    'ComplianceStandardsAdherence|Have DAST scanner configured in pipeline configuration',
  ),
};

export const STANDARDS_ADHERENCE_CHECK_FAILURE_REASONS = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: s__(
    'ComplianceStandardsAdherence|No rule is configured to prevent author approved merge requests.',
  ),
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: s__(
    'ComplianceStandardsAdherence|No rule is configured to prevent merge requests approved by committers.',
  ),
  [AT_LEAST_TWO_APPROVALS]: s__(
    'ComplianceStandardsAdherence|No rule is configured to require two approvals.',
  ),
  [AT_LEAST_ONE_NON_AUTHOR_APPROVAL]: s__(
    'ComplianceStandardsAdherence|No rule is configured to require at least one non-author approval.',
  ),
  [SAST]: s__(
    'ComplianceStandardsAdherence|SAST scanner is not configured in the pipeline configuration for the default branch.',
  ),
  [DAST]: s__(
    'ComplianceStandardsAdherence|DAST scanner is not configured in the pipeline configuration for the default branch.',
  ),
};

export const STANDARDS_ADHERENCE_CHECK_SUCCESS_REASONS = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: s__(
    'ComplianceStandardsAdherence|A rule is configured to prevent author approved merge requests.',
  ),
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: s__(
    'ComplianceStandardsAdherence|A rule is configured to prevent merge requests approved by committers.',
  ),
  [AT_LEAST_TWO_APPROVALS]: s__(
    'ComplianceStandardsAdherence|A rule is configured to require two approvals.',
  ),
  [SAST]: s__(
    'ComplianceStandardsAdherence|SAST scanner is configured in the pipeline configuration for the default branch.',
  ),
  [DAST]: s__(
    'ComplianceStandardsAdherence|DAST scanner is configured in the pipeline configuration for the default branch.',
  ),
};

export const STANDARDS_ADHERENCE_CHECK_FIX_FEATURES = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: [
    {
      title: s__('ComplianceStandardsAdherence|Merge request approval rules'),
      description: s__(
        "ComplianceStandardsAdherence|Update approval settings in the project's merge request settings to satisfy this requirement.",
      ),
    },
  ],
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: [
    {
      title: s__('ComplianceStandardsAdherence|Merge request approval rules'),
      description: s__(
        "ComplianceStandardsAdherence|Update approval settings in the project's merge request settings to satisfy this requirement.",
      ),
    },
  ],
  [AT_LEAST_TWO_APPROVALS]: [
    {
      title: s__('ComplianceStandardsAdherence|Merge request approval rules'),
      description: s__(
        "ComplianceStandardsAdherence|Update approval settings in the project's merge request settings to satisfy this requirement.",
      ),
    },
  ],
  [SAST]: [
    {
      title: s__('ComplianceStandardsAdherence|Enable SAST scanner'),
      description: s__(
        "ComplianceStandardsAdherence|Enable SAST scanner in the project's security configuration to satisfy this requirement.",
      ),
    },
  ],
  [DAST]: [
    {
      title: s__('ComplianceStandardsAdherence|Enable DAST scanner'),
      description: s__(
        "ComplianceStandardsAdherence|Enable DAST scanner in the project's security configuration to satisfy this requirement.",
      ),
    },
  ],
};

export const STANDARDS_ADHERENCE_CHECK_FIX_LEARN_MORE_DOCS_LINKS = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#prevent-authors-as-approvers`,
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#prevent-committers-as-approvers`,
  [AT_LEAST_TWO_APPROVALS]: `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#at-least-two-approvals`,
  [AT_LEAST_ONE_NON_AUTHOR_APPROVAL]: `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#at-least-one-non-author-approval`,
  [SAST]: `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#sast-scanner-artifact`,
  [DAST]: `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#dast-scanner-artifact`,
};

export const STANDARDS_ADHERENCE_CHECK_FIX_BUTTON_TEXT = {
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR]: __('Manage rules'),
  [PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS]: __('Manage rules'),
  [AT_LEAST_TWO_APPROVALS]: __('Manage rules'),
  [AT_LEAST_ONE_NON_AUTHOR_APPROVAL]: __('Manage rules'),
  [SAST]: __('Manage configuration'),
  [DAST]: __('Manage configuration'),
};

const GITLAB = 'GITLAB';
const SOC2 = __('SOC2');

export const STANDARDS_ADHERENCE_STANARD_LABELS = {
  [GITLAB]: __('GitLab'),
  [SOC2]: __('SOC 2'),
};

export const ALLOWED_FILTER_TOKENS = {
  checks: [
    PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR,
    PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS,
    AT_LEAST_TWO_APPROVALS,
    AT_LEAST_ONE_NON_AUTHOR_APPROVAL,
    SAST,
    DAST,
  ],
  standards: [GITLAB, SOC2],
};
