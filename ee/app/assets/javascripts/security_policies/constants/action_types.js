import { s__ } from '~/locale';
import { idAsOption } from './helpers';

export const ACTION_TYPES = [
  {
    id: 'require_approval',
    category: s__('SecurityOrchestration|Approval Policy'),
    label: s__('SecurityOrchestration|Require Approval'),
    description: s__('SecurityOrchestration|Require additional approvals before merge'),
    icon: 'approval',
    fields: [
      {
        key: 'approverGroups',
        type: 'text',
        label: s__('SecurityOrchestration|Approver Groups / Users'),
        placeholder: s__('SecurityOrchestration|e.g., security-team, @username'),
      },
      {
        key: 'approvalCount',
        type: 'text',
        label: s__('SecurityOrchestration|Required Approvals'),
        placeholder: '1',
      },
      {
        key: 'requestMessage',
        type: 'textarea',
        label: s__('SecurityOrchestration|Approval Request Message'),
        placeholder: '',
      },
    ],
  },
  {
    id: 'send_bot_message',
    category: s__('SecurityOrchestration|Approval Policy'),
    label: s__('SecurityOrchestration|Send Bot Message'),
    description: s__(
      'SecurityOrchestration|Post a comment on the merge request when violations are detected',
    ),
    icon: 'comment',
    fields: [
      {
        key: 'enabled',
        type: 'toggle',
        label: s__('SecurityOrchestration|Enabled'),
      },
    ],
  },
  {
    id: 'auto_resolve',
    category: s__('SecurityOrchestration|Vulnerability Management'),
    label: s__('SecurityOrchestration|Auto Resolve'),
    description: s__(
      'SecurityOrchestration|Automatically resolve vulnerabilities that are no longer detected',
    ),
    icon: 'check-circle',
    fields: [],
  },
  {
    id: 'auto_dismiss',
    category: s__('SecurityOrchestration|Vulnerability Management'),
    label: s__('SecurityOrchestration|Auto Dismiss'),
    description: s__(
      'SecurityOrchestration|Automatically dismiss vulnerabilities that are no longer detected',
    ),
    icon: 'check-circle',
    fields: [
      {
        key: 'dismissal_reason',
        type: 'select',
        label: s__('SecurityOrchestration|Dismissal Reason'),
        options: [
          idAsOption('acceptable_risk'),
          idAsOption('false_positive'),
          idAsOption('mitigating_control'),
          idAsOption('used_in_tests'),
          idAsOption('not_applicable'),
        ],
      },
    ],
  },
  {
    id: 'severity_override',
    category: s__('SecurityOrchestration|Vulnerability Management'),
    label: s__('SecurityOrchestration|Severity Override'),
    description: s__('SecurityOrchestration|Override the severity of matched vulnerabilities'),
    icon: 'warning',
    fields: [
      {
        key: 'severity_override_operation',
        type: 'select',
        label: s__('SecurityOrchestration|Operation'),
        options: [idAsOption('set'), idAsOption('increase'), idAsOption('decrease')],
      },
      {
        key: 'severity_override_value',
        type: 'select',
        label: s__('SecurityOrchestration|Target Severity'),
        options: [
          idAsOption('critical'),
          idAsOption('high'),
          idAsOption('medium'),
          idAsOption('low'),
          idAsOption('info'),
        ],
      },
    ],
  },
  {
    id: 'sast',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|SAST'),
    description: s__('SecurityOrchestration|Run Static Application Security Testing'),
    icon: 'shield',
    fields: [],
  },
  {
    id: 'dast',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|DAST'),
    description: s__('SecurityOrchestration|Run Dynamic Application Security Testing'),
    icon: 'shield',
    fields: [
      {
        key: 'site_profile',
        type: 'text',
        label: s__('SecurityOrchestration|Site Profile'),
        placeholder: '',
      },
      {
        key: 'scanner_profile',
        type: 'text',
        label: s__('SecurityOrchestration|Scanner Profile'),
        placeholder: '',
      },
    ],
  },
  {
    id: 'secret_detection',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|Secret Detection'),
    description: s__('SecurityOrchestration|Run Secret Detection scanning'),
    icon: 'lock',
    fields: [],
  },
  {
    id: 'container_scanning',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|Container Scanning'),
    description: s__('SecurityOrchestration|Run Container Scanning'),
    icon: 'container-image',
    fields: [],
  },
  {
    id: 'dependency_scanning',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|Dependency Scanning'),
    description: s__('SecurityOrchestration|Run Dependency Scanning'),
    icon: 'package',
    fields: [],
  },
  {
    id: 'sast_iac',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|SAST IaC'),
    description: s__('SecurityOrchestration|Run Infrastructure as Code scanning'),
    icon: 'infrastructure-registry',
    fields: [],
  },
  {
    id: 'cluster_image_scanning',
    category: s__('SecurityOrchestration|Scan Execution'),
    label: s__('SecurityOrchestration|Cluster Image Scanning'),
    description: s__('SecurityOrchestration|Run Cluster Image Scanning'),
    icon: 'deployments',
    fields: [],
  },
];
