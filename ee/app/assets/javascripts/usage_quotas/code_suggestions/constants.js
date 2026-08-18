import { PROMO_URL } from '~/constants';
import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE, DUO_AMAZON_Q, DUO_TITLES } from 'ee/constants/duo';
import { __, s__ } from '~/locale';

export const codeSuggestionsLearnMoreLink = `${PROMO_URL}/gitlab-duo/`;

export const DUO_BADGE_TITLES = {
  [DUO_CORE]: '',
  [DUO_PRO]: s__('CodeSuggestions|Pro'),
  [DUO_ENTERPRISE]: s__('CodeSuggestions|Enterprise'),
  [DUO_AMAZON_Q]: __('Amazon Q'),
};

export const DUO_ADD_ONS = {
  [DUO_PRO]: 'codeSuggestionsAddon',
  [DUO_ENTERPRISE]: 'duoEnterpriseAddon',
  [DUO_AMAZON_Q]: 'duoAmazonQAddon',
};

export const DUO_CSS_IDENTIFIERS = {
  [DUO_PRO]: 'duo_pro',
  [DUO_ENTERPRISE]: 'duo_enterprise',
  [DUO_AMAZON_Q]: 'duo_amazon_q',
};

export const DUO_HEALTH_CHECK_CATEGORIES = [
  {
    values: ['ai_gateway_url_presence_probe'],
    title: __('AI Gateway'),
    description: s__(
      'CodeSuggestions|The AI gateway URL must be set up as an environment variable.',
    ),
  },
  {
    values: ['host_probe'],
    title: __('Network'),
    description: s__(
      'CodeSuggestions|Outbound and inbound connections from clients to the GitLab instance must be allowed.',
    ),
  },
  {
    values: ['license_probe', 'access_probe', 'token_probe'],
    title: __('Synchronization'),
    description: s__(
      'CodeSuggestions|The active subscription must sync with customers.gitlab.com every 72 hours.',
    ),
  },
  {
    values: ['code_suggestions_license_probe'],
    title: __('Code Suggestions'),
    description: s__('CodeSuggestions|The Code Suggestions feature is available.'),
  },
  {
    values: ['duo_agent_platform_probe'],
    title: __('GitLab Duo Agent Platform'),
    description: s__(
      'CodeSuggestions|The GitLab Duo Agent Platform service must be accessible for agentic workflows.',
    ),
  },
  {
    values: ['end_to_end_probe'],
    title: __('System exchange'),
    description: s__(
      'CodeSuggestions|A code snippet must be passable to the AI-gateway for users to utilize GitLab Duo in their IDE.',
    ),
  },
  {
    values: [
      'allow_flow_execution_probe',
      'allow_foundational_flows_probe',
      'compatible_runner_probe',
    ],
    title: __('Foundational flows'),
    description: s__(
      'CodeSuggestions|Foundational flows and flow execution must be enabled, and a compatible runner must be available.',
    ),
  },
  {
    values: [
      'billing_customers_dot_probe',
      'billing_cloud_ai_gateway_probe',
      'billing_duo_workflow_service_probe',
    ],
    title: s__('HealthCheck|Self-hosted GitLab Duo usage billing prerequisites'),
    description: s__(
      'HealthCheck|These cloud services must be reachable for self-hosted GitLab Duo usage billing to work.',
    ),
  },
];

export const addOnEligibleUserListTableFields = {
  codeSuggestionsAddon: {
    key: 'codeSuggestionsAddon',
    label: DUO_TITLES[DUO_PRO],
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  duoEnterpriseAddon: {
    key: 'codeSuggestionsAddon',
    label: DUO_TITLES[DUO_ENTERPRISE],
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  duoAmazonQAddon: {
    key: 'codeSuggestionsAddon',
    label: DUO_TITLES[DUO_AMAZON_Q],
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  codeSuggestionsAddonWide: {
    key: 'codeSuggestionsAddon',
    label: DUO_TITLES[DUO_PRO],
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  duoEnterpriseAddonWide: {
    key: 'codeSuggestionsAddon',
    label: DUO_TITLES[DUO_ENTERPRISE],
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  duoAmazonQAddonWide: {
    key: 'codeSuggestionsAddon',
    label: DUO_TITLES[DUO_AMAZON_Q],
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  email: {
    key: 'email',
    label: __('Email'),
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  emailWide: {
    key: 'email',
    label: __('Email'),
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  lastActivityTime: {
    key: 'lastActivityTime',
    label: __('Last GitLab activity'),
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  lastDuoActivityTime: {
    key: 'lastDuoActivityTime',
    label: __('Last GitLab Duo activity'),
    thClass: 'gl-w-3/20 !gl-pr-2',
    tdClass: '!gl-align-middle',
  },
  maxRole: {
    key: 'maxRole',
    label: __('Max role'),
    thClass: 'gl-w-2/20',
    tdClass: '!gl-align-middle',
  },
  user: {
    key: 'user',
    label: __('User'),
    thClass: 'gl-w-5/20 !gl-pl-2',
    tdClass: '!gl-align-middle !gl-pl-2',
  },
  checkbox: {
    key: 'checkbox',
    label: '',
    headerTitle: __('Checkbox'),
    thClass: 'gl-w-1/20 !gl-pl-2',
    tdClass: '!gl-align-middle !gl-pl-2',
  },
};

export const SORT_OPTIONS = [
  {
    id: 10,
    title: __('Last activity'),
    sortDirection: {
      descending: 'LAST_ACTIVITY_ON_DESC',
      ascending: 'LAST_ACTIVITY_ON_ASC',
    },
  },
  {
    id: 20,
    title: __('Name'),
    sortDirection: {
      descending: 'NAME_DESC',
      ascending: 'NAME_ASC',
    },
  },
];

export const DEFAULT_SORT_OPTION = 'ID_ASC';
export const ASSIGN_SEATS_BULK_ACTION = 'ASSIGN_BULK_ACTION';
export const UNASSIGN_SEATS_BULK_ACTION = 'UNASSIGN_BULK_ACTION';
export const VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD = 'view_admin_code_suggestions_pageload';
