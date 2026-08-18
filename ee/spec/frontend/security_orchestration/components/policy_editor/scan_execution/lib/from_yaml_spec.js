import {
  createPolicyObject,
  hasInvalidScanners,
  hasInvalidTemplate,
  validatePolicy,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/from_yaml';
import {
  actionId,
  invalidPolicyActions,
  invalidPolicyRules,
  unsupportedManifest,
  invalidYaml,
  unsupportedManifestObjectScanExecution,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
  mockInvalidCadenceScanExecutionObject,
  mockInvalidCadenceScanExecutionManifest,
  mockBranchExceptionsScanExecutionObject,
  mockBranchExceptionsExecutionManifest,
  mockTemplateScanExecutionObject,
  mockInvalidTemplateScanExecutionManifest,
  mockInvalidTemplateScanExecutionObject,
  mockScanSettingsScanExecutionManifest,
  mockScanSettingsScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { SCAN_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { REPORT_TYPE_DEPENDENCY_SCANNING } from '~/vue_shared/security_reports/constants';

jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn((prefix) => `${prefix}0`),
}));

describe('fromYaml', () => {
  it.each`
    title                                                              | manifest                                   | output
    ${'policy object for an unsupported attribute'}                    | ${unsupportedManifest}                     | ${unsupportedManifestObjectScanExecution}
    ${'policy object for an invalid yaml'}                             | ${invalidYaml}                             | ${{}}
    ${'policy object for a branch exceptions'}                         | ${mockBranchExceptionsExecutionManifest}   | ${mockBranchExceptionsScanExecutionObject}
    ${'policy object with an error for an invalid cadence cron value'} | ${mockInvalidCadenceScanExecutionManifest} | ${mockInvalidCadenceScanExecutionObject}
    ${'policy object for a manifest with settings'}                    | ${mockScanSettingsScanExecutionManifest}   | ${mockScanSettingsScanExecutionObject}
  `('returns the $title', ({ manifest, output }) => {
    expect(fromYaml({ manifest, type: SCAN_EXECUTION_POLICY_TYPE })).toStrictEqual(output);
  });

  describe('validatePolicy', () => {
    it.each`
      title                                             | policy                                    | output
      ${'a valid policy'}                               | ${mockDastScanExecutionObject}            | ${{}}
      ${'policy object with a valid template value'}    | ${mockTemplateScanExecutionObject}        | ${{}}
      ${'policy object with an invalid template value'} | ${mockInvalidTemplateScanExecutionObject} | ${{ actions: true }}
      ${'a invalid policy with invalid actions'}        | ${invalidPolicyActions}                   | ${{ actions: true }}
      ${'a invalid policy with invalid rules'}          | ${invalidPolicyRules}                     | ${{ rules: true }}
    `('returns the error object for $title', ({ policy, output }) => {
      expect(validatePolicy(policy)).toStrictEqual(output);
    });
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                          | input                                         | output
    ${'returns the policy object and no errors for a supported manifest'}          | ${[mockDastScanExecutionManifest]}            | ${{ parsingError: {}, policy: mockDastScanExecutionObject }}
    ${'returns the error policy object and the error for an unsupported manifest'} | ${[mockInvalidTemplateScanExecutionManifest]} | ${{ parsingError: { actions: true, rules: true }, policy: {} }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('hasInvalidScanners', () => {
  it.each`
    title                                                    | input                                                                                  | output
    ${'return false when all scanners are supported'}        | ${[{ scan: 'sast', id: actionId }, { scan: 'dast', id: actionId }]}                    | ${false}
    ${'return true when not all scanners are supported'}     | ${[{ scan: 'sast', id: actionId }, { scan: 'cluster_image_scanning', id: actionId }]}  | ${true}
    ${'return true for fuzzing scanners unsupported by SEP'} | ${[{ scan: 'api_fuzzing', id: actionId }, { scan: 'coverage_fuzzing', id: actionId }]} | ${true}
    ${'return true when no valid scanners'}                  | ${[{ scan2: 'sast' }, { scan3: 'cluster_image_scanning' }]}                            | ${true}
  `('$title', ({ input, output }) => {
    expect(hasInvalidScanners(input)).toBe(output);
  });
});

describe('hasInvalidTemplate', () => {
  it.each`
    title                                                               | input                                                                                                | output
    ${'returns false for default template'}                             | ${[{ template: 'default', scan: 'sast' }]}                                                           | ${false}
    ${'returns false for latest template'}                              | ${[{ template: 'latest', scan: 'sast' }]}                                                            | ${false}
    ${'returns true for invalid template with non-versioned scan type'} | ${[{ template: 'v1', scan: 'sast' }]}                                                                | ${true}
    ${'returns false for versioned template with dependency_scanning'}  | ${[{ template: 'v2', scan: REPORT_TYPE_DEPENDENCY_SCANNING }]}                                       | ${false}
    ${'returns false for mixed valid templates'}                        | ${[{ template: 'latest', scan: 'sast' }, { template: 'v2', scan: REPORT_TYPE_DEPENDENCY_SCANNING }]} | ${false}
    ${'returns true if any template is invalid'}                        | ${[{ template: 'v1', scan: REPORT_TYPE_DEPENDENCY_SCANNING }, { template: 'v3', scan: 'sast' }]}     | ${true}
  `('$title', ({ input, output }) => {
    expect(hasInvalidTemplate(input)).toBe(output);
  });
});
