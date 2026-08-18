import { s__ } from '~/locale';
import { idAsOption } from './helpers';

const SCANNERS = [
  idAsOption('sast'),
  idAsOption('dast'),
  idAsOption('dependency_scanning'),
  idAsOption('container_scanning'),
  idAsOption('secret_detection'),
  idAsOption('coverage_fuzzing'),
  idAsOption('api_fuzzing'),
  idAsOption('sarif'),
];

const SEVERITY_LEVELS = [
  idAsOption('critical'),
  idAsOption('high'),
  idAsOption('medium'),
  idAsOption('low'),
  idAsOption('info'),
  idAsOption('unknown'),
];

export const RULE_TYPES = [
  {
    id: 'scan_finding',
    category: s__('SecurityOrchestration|Approval Policy'),
    label: s__('SecurityOrchestration|Scan Finding'),
    description: s__(
      'SecurityOrchestration|Require approval when scan findings match severity and state criteria',
    ),
    icon: 'shield',
    fields: [
      {
        key: 'scanners',
        type: 'multi_badge',
        label: s__('SecurityOrchestration|Scanners'),
        options: SCANNERS,
      },
      {
        key: 'severity_levels',
        type: 'multi_badge',
        label: s__('SecurityOrchestration|Severity Levels'),
        options: SEVERITY_LEVELS,
      },
      {
        key: 'vulnerability_states',
        type: 'multi_badge',
        label: s__('SecurityOrchestration|Vulnerability States'),
        options: [
          idAsOption('detected'),
          idAsOption('confirmed'),
          idAsOption('resolved'),
          idAsOption('dismissed'),
          idAsOption('new_needs_triage'),
          idAsOption('new_dismissed'),
        ],
      },
      {
        key: 'vulnerabilities_allowed',
        type: 'text',
        label: s__('SecurityOrchestration|Vulnerabilities Allowed'),
        placeholder: '0',
      },
      {
        key: 'branches',
        type: 'text',
        label: s__('SecurityOrchestration|Branches'),
        placeholder: s__('SecurityOrchestration|e.g., main, release/*'),
      },
      {
        key: 'branch_type',
        type: 'select',
        label: s__('SecurityOrchestration|Branch Type'),
        options: [idAsOption('default'), idAsOption('protected')],
      },
    ],
  },
  {
    id: 'license_finding',
    category: s__('SecurityOrchestration|Approval Policy'),
    label: s__('SecurityOrchestration|License Finding'),
    description: s__(
      'SecurityOrchestration|Require approval when dependency licenses match criteria',
    ),
    icon: 'license',
    fields: [
      {
        key: 'license_types',
        type: 'text',
        label: s__('SecurityOrchestration|License Types'),
        placeholder: s__('SecurityOrchestration|e.g., GPL-3.0, AGPL'),
      },
      {
        key: 'license_states',
        type: 'multi_badge',
        label: s__('SecurityOrchestration|License States'),
        options: [idAsOption('newly_detected'), idAsOption('detected')],
      },
      {
        key: 'match_on_inclusion_license',
        type: 'toggle',
        label: s__('SecurityOrchestration|Match on Inclusion'),
      },
    ],
  },
  {
    id: 'any_merge_request',
    category: s__('SecurityOrchestration|Approval Policy'),
    label: s__('SecurityOrchestration|Any Merge Request'),
    description: s__('SecurityOrchestration|Require approval for any merge request'),
    icon: 'git-merge',
    fields: [
      {
        key: 'commits',
        type: 'select',
        label: s__('SecurityOrchestration|Commits'),
        options: [idAsOption('any'), idAsOption('unsigned')],
      },
    ],
  },
  {
    id: 'pipeline',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|Pipeline'),
    description: s__('SecurityOrchestration|Run scans when a pipeline is triggered'),
    icon: 'pipeline',
    fields: [
      {
        key: 'branches',
        type: 'text',
        label: s__('SecurityOrchestration|Branches'),
        placeholder: s__('SecurityOrchestration|e.g., main, release/*'),
      },
      {
        key: 'branch_type',
        type: 'select',
        label: s__('SecurityOrchestration|Branch Type'),
        options: [
          idAsOption('default'),
          idAsOption('protected'),
          idAsOption('all'),
          idAsOption('target_default'),
          idAsOption('target_protected'),
        ],
      },
    ],
  },
  {
    id: 'schedule',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|Schedule'),
    description: s__('SecurityOrchestration|Run scans on a cron schedule'),
    icon: 'clock',
    fields: [
      {
        key: 'cadence',
        type: 'text',
        label: s__('SecurityOrchestration|Cadence'),
        placeholder: '0 22 * * 1-5',
      },
      {
        key: 'timezone',
        type: 'text',
        label: s__('SecurityOrchestration|Timezone'),
        placeholder: 'UTC',
      },
    ],
  },
  {
    id: 'no_longer_detected',
    category: s__('SecurityOrchestration|Vulnerability Management'),
    label: s__('SecurityOrchestration|No Longer Detected'),
    description: s__(
      'SecurityOrchestration|Trigger when vulnerabilities are no longer present in scan results',
    ),
    icon: 'check-circle',
    fields: [
      {
        key: 'scanners',
        type: 'multi_badge',
        label: s__('SecurityOrchestration|Scanners'),
        options: SCANNERS,
      },
      {
        key: 'severity_levels',
        type: 'multi_badge',
        label: s__('SecurityOrchestration|Severity Levels'),
        options: SEVERITY_LEVELS,
      },
    ],
  },
  {
    id: 'detected',
    category: s__('SecurityOrchestration|Vulnerability Management'),
    label: s__('SecurityOrchestration|Detected'),
    description: s__('SecurityOrchestration|Trigger on newly detected vulnerabilities'),
    icon: 'warning-solid',
    fields: [],
  },
  {
    id: 'rego',
    category: s__('SecurityOrchestration|Approval Policy'),
    label: s__('SecurityOrchestration|Custom Rego Rule'),
    description: s__(
      'SecurityOrchestration|Validate scan reports against custom OPA/Rego policy code',
    ),
    icon: 'code',
    fields: [
      {
        key: 'name',
        type: 'text',
        label: s__('SecurityOrchestration|Rule Name'),
        placeholder: s__('SecurityOrchestration|e.g., no_critical_vulnerabilities'),
      },
      {
        key: 'policy',
        type: 'code',
        label: s__('SecurityOrchestration|Rego Policy'),
        description: s__(
          'SecurityOrchestration|Evaluated server-side when scan reports are published. Maximum 32 KB.',
        ),
        maxLength: 32768,
        placeholder:
          'new_uuids := {f.uuid |\n    some f in input.security.findings\n    f.new\n    f.severity in {"critical", "high"}\n    not f.dismissed\n}\n\nmatch contains sprintf("New critical or high findings: %d", [count(new_uuids)]) if {\n    count(new_uuids) > 0\n}\n\nreport_new_findings := new_uuids',
      },
    ],
  },
];
