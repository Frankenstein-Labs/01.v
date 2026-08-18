import { s__, n__ } from '~/locale';

export const DEFAULT_DESCRIPTION_LABEL = s__('SecurityOrchestration|No description');

export const DESCRIPTION_TITLE = s__('SecurityOrchestration|Description');

export const ENABLED_LABEL = s__('SecurityOrchestration|Enabled');

export const NOT_ENABLED_LABEL = s__('SecurityOrchestration|Not enabled');

export const TYPE_TITLE = s__('SecurityOrchestration|Policy Type');

export const SOURCE_TITLE = s__('SecurityOrchestration|Source');
export const SCOPE_TITLE = s__('SecurityOrchestration|Scope');
export const DEFAULT_SCOPE_LABEL = s__('SecurityOrchestration|No scope');
export const DEFAULT_PROJECT_TEXT = s__(
  'SecurityOrchestration|This policy is applied to current project.',
);
export const COMPLIANCE_FRAMEWORKS_DESCRIPTION = (projectsCount) =>
  n__(
    'SecurityOrchestration|%d project which has compliance framework:',
    'SecurityOrchestration|%d projects which have compliance framework:',
    projectsCount,
  );

export const COMPLIANCE_FRAMEWORKS_DESCRIPTION_OVER_MAX_NUMBER_OF_PROJECTS = s__(
  `SecurityOrchestration|%{pageSize}+ projects which have compliance framework:`,
);

export const COMPLIANCE_FRAMEWORKS_DESCRIPTION_NO_PROJECTS = s__(
  'SecurityOrchestration|This applies to following compliance frameworks:',
);

export const STATUS_TITLE = s__('SecurityOrchestration|Status');

export const SUMMARY_TITLE = s__('SecurityOrchestration|Summary');
export const CONFIGURATION_TITLE = s__('SecurityOrchestration|Configuration');

export const INHERITED_SHORT_LABEL = s__('SecurityOrchestration|This policy is inherited');
