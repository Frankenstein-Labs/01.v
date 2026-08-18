import { s__ } from '~/locale';
import { JOB_SOURCES as CE_JOB_SOURCES } from '~/ci/common/private/jobs_filtered_search/tokens/constants';

const EE_JOB_SOURCES = [
  {
    text: s__('JobSource|On-Demand DAST Scan'),
    value: 'ONDEMAND_DAST_SCAN',
  },
  {
    text: s__('JobSource|On-Demand DAST Validation'),
    value: 'ONDEMAND_DAST_VALIDATION',
  },
  {
    text: s__('JobSource|Scheduled Scan Execution Policy'),
    value: 'SECURITY_ORCHESTRATION_POLICY',
  },
  {
    text: s__('JobSource|Pipeline Execution Policy'),
    value: 'PIPELINE_EXECUTION_POLICY',
  },
  {
    text: s__('JobSource|Scheduled Pipeline Execution Policy'),
    value: 'PIPELINE_EXECUTION_POLICY_SCHEDULE',
  },
  {
    text: s__('JobSource|Scan Execution Policy'),
    value: 'SCAN_EXECUTION_POLICY',
  },
  {
    text: s__('JobSource|Duo Agent Platform'),
    value: 'DUO_WORKFLOW',
  },
];

export const JOB_SOURCES = [...CE_JOB_SOURCES, ...EE_JOB_SOURCES];
