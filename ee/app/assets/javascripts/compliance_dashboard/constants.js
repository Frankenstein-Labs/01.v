import { GL_COLOR_NEUTRAL_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { __, s__ } from '~/locale';
import { DOCS_URL } from '~/constants';

export const INPUT_DEBOUNCE = 500;

export const CUSTODY_REPORT_PARAMETER = 'commit_sha';

export const DRAWER_AVATAR_SIZE = 24;

export const DRAWER_MAXIMUM_AVATARS = 20;

export const GRAPHQL_PAGE_SIZE = 20;

export const GRAPHQL_FRAMEWORK_TYPE = 'ComplianceManagement::Framework';

const APPROVED_BY_COMMITTER = 'APPROVED_BY_COMMITTER';
const APPROVED_BY_INSUFFICIENT_USERS = 'APPROVED_BY_INSUFFICIENT_USERS';
const APPROVED_BY_MERGE_REQUEST_AUTHOR = 'APPROVED_BY_MERGE_REQUEST_AUTHOR';

export const MERGE_REQUEST_VIOLATION_MESSAGES = {
  [APPROVED_BY_COMMITTER]: s__('ComplianceReport|Approved by committer'),
  [APPROVED_BY_INSUFFICIENT_USERS]: s__('ComplianceReport|Less than 2 approvers'),
  [APPROVED_BY_MERGE_REQUEST_AUTHOR]: s__('ComplianceReport|Approved by author'),
};

export const DEFAULT_SORT = 'SEVERITY_LEVEL_DESC';

export const DEFAULT_PAGINATION_CURSORS = {
  before: null,
  after: null,
  first: GRAPHQL_PAGE_SIZE,
};

export const BRANCH_FILTER_OPTIONS = {
  allBranches: __('All branches'),
  allProtectedBranches: __('All protected branches'),
};

export const ROUTE_DASHBOARD = 'dashboard';
export const ROUTE_STANDARDS_ADHERENCE = 'standards_adherence';
export const ROUTE_VIOLATIONS = 'violations';
export const ROUTE_PROJECTS = 'projects';
export const ROUTE_FRAMEWORKS = 'frameworks';
export const ROUTE_NEW_FRAMEWORK = 'new_framework';
export const ROUTE_NEW_FRAMEWORK_SUCCESS = 'new_framework_success';
export const ROUTE_BLANK_FRAMEWORK = 'blank_framework';
export const ROUTE_EDIT_FRAMEWORK = 'frameworks/:id';
export const ROUTE_EXPORT_FRAMEWORK = 'frameworks/:id.json';
export const FRAMEWORKS_LABEL_BACKGROUND = GL_COLOR_NEUTRAL_500;

export const FRAMEWORKS_FILTER_TYPE_PROJECT = 'project';
export const FRAMEWORKS_FILTER_TYPE_FRAMEWORK = 'framework';
export const FRAMEWORKS_FILTER_TYPE_GROUP = 'groupPath';
export const FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS = 'project_status';
export const FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK = {
  color: '#000000',
  default: false,
  description: s__('ComplianceFrameworks|No framework'),
  id: 'gid://gitlab/ComplianceManagement::Framework/0',
  name: s__('ComplianceFrameworks|No framework'),
  pipelineConfigurationFullPath: '',
  __typename: 'ComplianceFramework',
};

export const i18n = {
  newFramework: s__('ComplianceFrameworks|New framework'),
  newFrameworkButtonMessage: s__(
    'ComplianceFrameworks|You must create compliance frameworks in top-level group %{linkStart}namespace%{linkEnd}',
  ),
  tooltipMessageNoAccess: s__(
    'ComplianceFrameworks|You must have the Owner role for the top-level group %{strongStart}namespace%{strongEnd}',
  ),
  heading: __('Compliance center'),
  subheading: s__(
    'Compliance Center|Report and manage compliance status, violations, and compliance frameworks for the group. %{linkStart}Learn more%{linkEnd}.',
  ),
  overviewTab: s__('Compliance Center|Overview'),
  frameworksTab: s__('Compliance Center|Frameworks'),
  projectsTab: __('Projects'),
  projectTab: __('Project'),
  standardsAdherenceTab: s__('Compliance Center|Status'),
  violationsTab: s__('Compliance Center|Violations'),
};

export const POLICY_SCOPES_DOCS_URL = `${DOCS_URL}/user/application_security/policies/_index.html#scope`;

export const CREATE_FRAMEWORKS_DOCS_URL = `${DOCS_URL}/user/group/compliance_frameworks.html#prerequisites`;

export const FEEDBACK_ISSUE_URL_VIOLATIONS = 'https://gitlab.com/gitlab-org/gitlab/-/issues/547492';

export const GRAPHQL_FIELD_MISSING_ERROR_MESSAGE = __(
  'Your GitLab instance is currently being updated. Please try again later.',
);

export const EXTERNAL_CONTROL_LABEL = s__('ComplianceFrameworks|External');
export const UNKNOWN_CONTROL_LABEL = s__('ComplianceFrameworks|Unknown');
