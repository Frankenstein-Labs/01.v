import { s__ } from '~/locale';

export const ExclusionType = {
  PATH: 'PATH',
  RAW: 'RAW_VALUE',
  REGEX: 'REGEX_PATTERN',
  RULE: 'RULE',
};

export const StatusType = {
  ENABLE: true,
  DISABLE: false,
};

export const ExclusionScannerEnum = {
  SECRET_PUSH_PROTECTION: 'SECRET_PUSH_PROTECTION',
};

export const EXCLUSION_TYPE_MAP = {
  [ExclusionType.PATH]: {
    text: s__('SecurityExclusions|Path'),
    value: ExclusionType.PATH,
    description: s__('SecurityExclusions|File or directory location'),
    contentDescription: s__(
      'SecurityExclusions|Enter one or more paths to exclude, separated by line breaks.',
    ),
    contentPlaceholder: s__('SecurityExclusions|ex: spec/**/*.rb'),
  },
  [ExclusionType.RAW]: {
    text: s__('SecurityExclusions|Raw value'),
    value: ExclusionType.RAW,
    description: s__('SecurityExclusions|Unprocessed data'),
    contentDescription: s__(
      'SecurityExclusions|Enter one or more raw values to ignore, separated by line breaks.',
    ),
    contentPlaceholder: s__('SecurityExclusions|ex: glpat-1234567890'),
  },
  [ExclusionType.RULE]: {
    text: s__('SecurityExclusions|Rule'),
    value: ExclusionType.RULE,
    description: s__('SecurityExclusions|Scanner rule identifier'),
    contentDescription: s__(
      'SecurityExclusions|Enter one or more rules to ignore, separated by line breaks.',
    ),
    contentPlaceholder: s__('SecurityExclusions|ex: gitlab_personal_access_token'),
  },
};

export const STATUS_TYPES = [
  { text: s__('SecurityExclusions|Enable'), value: StatusType.ENABLE },
  { text: s__('SecurityExclusions|Disable'), value: StatusType.DISABLE },
];

export const DRAWER_MODES = {
  VIEW: 'view',
  ADD: 'add',
  EDIT: 'edit',
};
