import {
  validateSourceFilter,
  validateTypeFilter,
  extractTypeParameter,
  extractSourceParameter,
  buildPolicyViolationList,
  exceedsActionLimit,
  exceedsScheduleRulesLimit,
  flattenPolicies,
  getTestRunsForProject,
} from 'ee/security_orchestration/components/policies/utils';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import {
  APPROVAL_POLICY_TYPE,
  POLICY_TYPE_COMPONENT_OPTIONS,
} from 'ee/security_orchestration/components/constants';
import {
  mockDastScanExecutionManifest,
  mockMultipleScheduleScanExecutionManifest,
  mockMultipleActionsScanExecutionManifest,
  mockScheduleScanExecutionManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

describe('utils', () => {
  describe('validateSourceFilter', () => {
    it.each`
      value                                                  | valid
      ${POLICY_SOURCE_OPTIONS.ALL.value}                     | ${true}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value}               | ${true}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value}                  | ${true}
      ${'invalid key'}                                       | ${false}
      ${''}                                                  | ${false}
      ${undefined}                                           | ${false}
      ${null}                                                | ${false}
      ${{}}                                                  | ${false}
      ${0}                                                   | ${false}
      ${POLICY_SOURCE_OPTIONS.ALL.value.toLowerCase()}       | ${true}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value.toLowerCase()} | ${true}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value.toLowerCase()}    | ${true}
    `('should validate source filters for $value', ({ value, valid }) => {
      expect(validateSourceFilter(value)).toBe(valid);
    });
  });

  describe('validateTypeFilter', () => {
    it.each`
      value                                                                      | valid
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}                                    | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}                         | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value}                               | ${true}
      ${''}                                                                      | ${true}
      ${'invalid key'}                                                           | ${false}
      ${undefined}                                                               | ${false}
      ${null}                                                                    | ${false}
      ${{}}                                                                      | ${false}
      ${0}                                                                       | ${false}
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value.toLowerCase()}                      | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()}           | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value.toLowerCase()}                 | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value.toLowerCase()}       | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value.toLowerCase()} | ${true}
    `('should validate type filters for $value', ({ value, valid }) => {
      expect(validateTypeFilter(value)).toBe(valid);
    });
  });

  describe('extractTypeParameter', () => {
    it.each`
      type                                                             | output
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}                          | ${''}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}               | ${'SCAN_EXECUTION'}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value}                     | ${'APPROVAL'}
      ${''}                                                            | ${''}
      ${'invalid key'}                                                 | ${''}
      ${undefined}                                                     | ${''}
      ${null}                                                          | ${''}
      ${{}}                                                            | ${''}
      ${0}                                                             | ${''}
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value.toLowerCase()}            | ${''}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()} | ${'SCAN_EXECUTION'}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value.toLowerCase()}       | ${'APPROVAL'}
      ${'scan_result'}                                                 | ${'APPROVAL'}
    `('should extract valid type parameter for $type', ({ type, output }) => {
      expect(extractTypeParameter(type)).toBe(output);
    });
  });

  describe('extractSourceParameter', () => {
    it.each`
      source                                                 | output
      ${POLICY_SOURCE_OPTIONS.ALL.value}                     | ${'INHERITED'}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value}               | ${'INHERITED_ONLY'}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value}                  | ${'DIRECT'}
      ${'invalid key'}                                       | ${'INHERITED'}
      ${''}                                                  | ${'INHERITED'}
      ${undefined}                                           | ${'INHERITED'}
      ${null}                                                | ${'INHERITED'}
      ${{}}                                                  | ${'INHERITED'}
      ${0}                                                   | ${'INHERITED'}
      ${POLICY_SOURCE_OPTIONS.ALL.value.toLowerCase()}       | ${'INHERITED'}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value.toLowerCase()} | ${'INHERITED_ONLY'}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value.toLowerCase()}    | ${'DIRECT'}
    `('should validate source filters for $source', ({ source, output }) => {
      expect(extractSourceParameter(source)).toBe(output);
    });
  });

  describe('exceedsActionLimit', () => {
    it.each`
      policyType                                              | yaml                             | maxScanExecutionPolicyActions | output
      ${POLICY_TYPE_COMPONENT_OPTIONS.approval.text}          | ${''}                            | ${5}                          | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.text} | ${''}                            | ${5}                          | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}     | ${mockDastScanExecutionManifest} | ${5}                          | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}     | ${''}                            | ${5}                          | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}     | ${mockDastScanExecutionManifest} | ${0}                          | ${false}
    `(
      'should validate if action count exceeds allowed number for policy type $policyType',
      ({ policyType, yaml, maxScanExecutionPolicyActions, output }) => {
        expect(exceedsActionLimit({ policyType, yaml, maxScanExecutionPolicyActions })).toBe(
          output,
        );
      },
    );
  });

  describe('exceedsScheduleRulesLimit', () => {
    it.each`
      policyType                                                    | yaml                                 | output
      ${POLICY_TYPE_COMPONENT_OPTIONS.approval.text}                | ${''}                                | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.text}       | ${''}                                | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}           | ${mockScheduleScanExecutionManifest} | ${false}
      ${POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.text} | ${''}                                | ${false}
    `(
      'should validate scheduled rules only for scan execution policy',
      ({ policyType, yaml, output }) => {
        expect(
          exceedsScheduleRulesLimit({
            policyType,
            yaml,
            maxScanExecutionPolicySchedules: 0,
          }),
        ).toBe(output);
      },
    );
  });

  describe('buildPolicyViolationList', () => {
    const approvalPolicyDeprecatedViolation = [
      {
        content:
          'You must edit the policy and replace the deprecated syntax (invalid). For details on its replacement, see the %{linkStart}policy documentation%{linkEnd}.',
        link: '/help/user/application_security/policies/merge_request_approval_policies#merge-request-approval-policies-schema',
      },
    ];
    const scanExecutionDeprecatedViolation = [
      {
        content: 'Policy contains %{linkStart}deprecated syntax%{linkEnd} (invalid).',
        link: '/help/user/application_security/policies/scan_execution_policies#scan-execution-policies-schema',
      },
    ];
    const scanExecutionExceedingLimit = [
      {
        content: 'Policy contains %{linkStart}deprecated syntax%{linkEnd} (invalid).',
        link: '/help/user/application_security/policies/scan_execution_policies#scan-execution-policies-schema',
      },
      {
        content: 'Scan actions exceed the limit of 1 actions per policy.',
        link: '/help/user/application_security/policies/scan_execution_policies#scan-execution-policies-schema',
      },
    ];
    it.each`
      policyType                                              | yaml                                        | deprecatedProperties | maxScanExecutionPolicyActions | output
      ${POLICY_TYPE_COMPONENT_OPTIONS.approval.text}          | ${''}                                       | ${[]}                | ${5}                          | ${[]}
      ${POLICY_TYPE_COMPONENT_OPTIONS.approval.text}          | ${''}                                       | ${['invalid']}       | ${5}                          | ${approvalPolicyDeprecatedViolation}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}     | ${''}                                       | ${['invalid']}       | ${5}                          | ${scanExecutionDeprecatedViolation}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}     | ${mockDastScanExecutionManifest}            | ${['invalid']}       | ${0}                          | ${scanExecutionDeprecatedViolation}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text}     | ${mockMultipleActionsScanExecutionManifest} | ${['invalid']}       | ${1}                          | ${scanExecutionExceedingLimit}
      ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.text} | ${''}                                       | ${[]}                | ${5}                          | ${[]}
    `(
      'renders violation list for policy with type $policyType',
      ({ policyType, yaml, deprecatedProperties, maxScanExecutionPolicyActions, output }) => {
        expect(
          buildPolicyViolationList({
            policyType,
            yaml,
            deprecatedProperties,
            maxScanExecutionPolicyActions,
          }),
        ).toEqual(output);
      },
    );

    it('renders violation list for policy with type exceeded number of scheduled rules', () => {
      expect(
        buildPolicyViolationList({
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text,
          yaml: mockMultipleScheduleScanExecutionManifest,
          deprecatedProperties: [],
          maxScanExecutionPolicyActions: 5,
          maxScanExecutionPolicySchedules: 1,
        }),
      ).toEqual([
        {
          content:
            'A scan execution policy exceeds the limit of 1 scheduled rules per policy. Remove or consolidate rules across policies to reduce the total number of rules.',
          link: '/help/user/application_security/policies/scan_execution_policies',
        },
      ]);
    });
  });

  describe('flattenPolicies', () => {
    it.each`
      policies                                                                                                                         | expectedResult
      ${[]}                                                                                                                            | ${[]}
      ${{}}                                                                                                                            | ${[]}
      ${undefined}                                                                                                                     | ${[]}
      ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE, policyAttributes: { actionApprovers: [], deprecatedProperties: ['test'] } }]} | ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE, actionApprovers: [], deprecatedProperties: ['test'] }]}
      ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE }]}                                                                            | ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE }]}
      ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE }, null]}                                                                      | ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE }]}
      ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE, policyAttributes: {} }]}                                                      | ${[{ name: 'policy-1', type: APPROVAL_POLICY_TYPE }]}
    `('spreads policy attributes into a flat policy structure', ({ policies, expectedResult }) => {
      expect(flattenPolicies(policies)).toEqual(expectedResult);
    });
  });

  describe('getTestRunsForProject', () => {
    const namespacePath = 'group/project';
    const inheritedSource = {
      inherited: true,
      namespace: { id: '1', fullPath: 'group', name: 'Group' },
    };
    const directSource = null;
    const runForCurrentProject = {
      id: '1',
      state: 'COMPLETE',
      project: { fullPath: namespacePath },
    };
    const runForOtherProject = {
      id: '2',
      state: 'RUNNING',
      project: { fullPath: 'other/project' },
    };
    const testRuns = { nodes: [runForCurrentProject, runForOtherProject] };

    it('returns test runs as-is for group context', () => {
      expect(
        getTestRunsForProject(testRuns, { isGroup: true, source: inheritedSource, namespacePath }),
      ).toBe(testRuns);
    });

    it('returns null when testRuns is undefined in group context', () => {
      expect(
        getTestRunsForProject(undefined, { isGroup: true, source: inheritedSource, namespacePath }),
      ).toBeNull();
    });

    it('returns test runs as-is for direct (non-inherited) policies', () => {
      expect(
        getTestRunsForProject(testRuns, { isGroup: false, source: directSource, namespacePath }),
      ).toBe(testRuns);
    });

    it('returns null when testRuns is undefined for direct policies', () => {
      expect(
        getTestRunsForProject(undefined, { isGroup: false, source: directSource, namespacePath }),
      ).toBeNull();
    });

    it('filters test runs to current project for inherited project-level policies', () => {
      expect(
        getTestRunsForProject(testRuns, { isGroup: false, source: inheritedSource, namespacePath }),
      ).toEqual({
        nodes: [runForCurrentProject],
      });
    });

    it('returns null when no test runs match current project', () => {
      const noMatchRuns = { nodes: [runForOtherProject] };
      expect(
        getTestRunsForProject(noMatchRuns, {
          isGroup: false,
          source: inheritedSource,
          namespacePath,
        }),
      ).toBeNull();
    });
  });
});
