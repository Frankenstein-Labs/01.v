import { SCAN_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { SCAN_EXECUTION_DEFAULT } from '../mocks/mocks';

export const mockScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
${SCAN_EXECUTION_DEFAULT.rules}
${SCAN_EXECUTION_DEFAULT.actions}
${SCAN_EXECUTION_DEFAULT.skip}
`;

export const mockAllBranchesScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branch_type: all
      - type: pipeline
        branch_type: target_default
        pipeline_sources:
          including:
            - merge_request_event
${SCAN_EXECUTION_DEFAULT.actions}
${SCAN_EXECUTION_DEFAULT.skip}
`;

export const mockDastActionScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
${SCAN_EXECUTION_DEFAULT.rules}
    actions:
      - scan: dast
        site_profile: ''
        scanner_profile: ''
${SCAN_EXECUTION_DEFAULT.skip}
`;

export const mockGroupDastActionScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding: []
${SCAN_EXECUTION_DEFAULT.rules}
    actions:
      - scan: dast
        site_profile: ''
        scanner_profile: ''
${SCAN_EXECUTION_DEFAULT.skip}
`;

export const mockActionsVariablesScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
${SCAN_EXECUTION_DEFAULT.rules}
    actions:
      - scan: secret_detection
        variables:
          a: b
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
${SCAN_EXECUTION_DEFAULT.skip}
`;

export const createScanActionScanExecutionManifest = (scanType) => {
  return mockScanExecutionManifest
    .replace('scan: secret_detection', `scan: ${scanType}`)
    .replace('\n        template: latest', '');
};

export const mockScheduleScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: schedule
        branches: []
        cadence: 0 0 * * *
        time_window:
          distribution: random
          value: 36000
      - type: pipeline
        branch_type: target_default
        pipeline_sources:
          including:
            - merge_request_event
${SCAN_EXECUTION_DEFAULT.actions}
${SCAN_EXECUTION_DEFAULT.skip}
`;

export const mockSkipCiScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
${SCAN_EXECUTION_DEFAULT.rules}
${SCAN_EXECUTION_DEFAULT.actions}
    skip_ci:
      allowed: true
`;

export const mockScanExecutionObject = fromYaml({
  manifest: mockScanExecutionManifest,
  type: SCAN_EXECUTION_POLICY_TYPE,
});
