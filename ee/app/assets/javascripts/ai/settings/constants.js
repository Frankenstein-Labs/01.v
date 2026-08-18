import { s__ } from '~/locale';
import { DOCS_URL } from '~/constants';
import {
  ACCESS_LEVEL_ADMIN_INTEGER,
  ACCESS_LEVELS_INTEGER_TO_STRING,
  ACCESS_LEVEL_ADMIN_STRING,
} from '~/access_level/constants';

export const AVAILABILITY_OPTIONS = {
  ALWAYS_ON: 'always_on',
  DEFAULT_ON: 'default_on',
  DEFAULT_OFF: 'default_off',
  NEVER_ON: 'never_on',
};

export const AVAILABILITY_OPTIONS_ENUMS = {
  ALWAYS_ON: 'ALWAYS_ON',
  DEFAULT_ON: 'DEFAULT_ON',
  DEFAULT_OFF: 'DEFAULT_OFF',
  NEVER_ON: 'NEVER_ON',
};

export const PROTECTION_LEVEL_OPTIONS = [
  {
    value: 'no_checks',
    text: s__('DuoWorkflowSettings|No checks'),
    description: s__(
      'DuoWorkflowSettings|Turn off scanning entirely. No prompt data is sent to third-party services.',
    ),
  },
  {
    value: 'log_only',
    text: s__('DuoWorkflowSettings|Log only'),
    description: s__('DuoWorkflowSettings|Scan and log results, but do not block requests.'),
  },
  {
    value: 'interrupt',
    text: s__('DuoWorkflowSettings|Interrupt'),
    description: s__('DuoWorkflowSettings|Scan and block detected prompt injection attempts.'),
  },
];

// eslint-disable-next-line @gitlab/no-hardcoded-urls
export const AI_CATALOG_SEED_EXTERNAL_AGENTS_PATH = '/api/v4/admin/ai_catalog/seed_external_agents';
// Exact error message from backend:
// https://gitlab.com/gitlab-org/gitlab/-/blob/8217d2663f0ee08de2829d59b9530c0688585b50/ee/lib/gitlab/ai/catalog/third_party_flows/seeder.rb#L188
export const AI_CATALOG_ALREADY_SEEDED_ERROR = 'Error: External agents already seeded';

export const ACCESS_LEVEL_EVERYONE_INTEGER = -1;
export const ACCESS_LEVELS_WITH_EVERYONE_AND_ADMIN = {
  [ACCESS_LEVEL_EVERYONE_INTEGER]: null,
  ...ACCESS_LEVELS_INTEGER_TO_STRING,
  [ACCESS_LEVEL_ADMIN_INTEGER]: ACCESS_LEVEL_ADMIN_STRING,
};

export const AI_USAGE_DATA_COLLECTION_DOCS_URL = `${DOCS_URL}/user/gitlab_duo/data_usage.html#telemetry`;
export const AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT = 60;
