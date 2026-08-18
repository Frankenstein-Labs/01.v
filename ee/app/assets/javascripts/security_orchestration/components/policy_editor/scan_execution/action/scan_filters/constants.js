import { s__ } from '~/locale';
import { REPORT_TYPE_DEPENDENCY_SCANNING } from '~/vue_shared/security_reports/constants';

export const CI_VARIABLE = 'ci_variable';

export const TEMPLATE = 'template';

export const SCAN_SETTINGS = 'scan_settings';

export const DEFAULT_TEMPLATE = 'default';

export const LATEST_TEMPLATE = 'latest';

export const NONVERSIONED_TEMPLATES = [
  { text: s__('SecurityOrchestration|latest'), value: LATEST_TEMPLATE },
  { text: s__('SecurityOrchestration|default'), value: DEFAULT_TEMPLATE },
];

export const VERSIONED_TEMPLATES = {
  [REPORT_TYPE_DEPENDENCY_SCANNING]: [
    { text: s__('SecurityOrchestration|v2'), value: 'v2' },
    { text: s__('SecurityOrchestration|latest'), value: LATEST_TEMPLATE },
    { text: s__('SecurityOrchestration|default'), value: DEFAULT_TEMPLATE },
  ],
};

export const FILTERS = [
  {
    text: s__('ScanResultPolicy|Customized CI Variables'),
    value: CI_VARIABLE,
    tooltip: s__('ScanExecutionPolicy|Maximum number of CI-criteria is one'),
  },
];

export const DAST_PROFILE_I18N = {
  selectedScannerProfilePlaceholder: s__('ScanExecutionPolicy|Select scanner profile'),
  selectedSiteProfilePlaceholder: s__('ScanExecutionPolicy|Select site profile'),
  scanCreate: s__('ScanExecutionPolicy|Create new scan profile'),
  scanLabel: s__('ScanExecutionPolicy|DAST scan profiles'),
  siteCreate: s__('ScanExecutionPolicy|Create new site profile'),
  siteLabel: s__('ScanExecutionPolicy|DAST site profiles'),
};
