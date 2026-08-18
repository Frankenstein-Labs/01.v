import {
  addIdsToPolicy,
  checkForPerformanceRisk,
  hasScheduledRule,
  isDefaultMode,
  isPolicyInherited,
  policyHasNamespace,
  isProject,
  isGroup,
  isScanningReport,
  extractPolicyContent,
  extractPolicyContentFromRootTypeProperty,
  createSpepTestRunSubscription,
} from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  APPROVAL_POLICY_TYPE,
  POLICY_TYPE_COMPONENT_OPTIONS,
  SCAN_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { DEFAULT_SCAN_EXECUTION_POLICY } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import {
  mockDastScanExecutionObject,
  mockDastScanExecutionManifest,
  mockScheduleScanExecutionObject,
  mockScheduleScanExecutionManifest,
} from '../mocks/mock_scan_execution_policy_data';

describe('addIdsToPolicy', () => {
  it('adds ids to a policy with actions and rules', () => {
    expect(addIdsToPolicy({ actions: [{}], rules: [{}] })).toStrictEqual({
      actions: [{ id: 'action_1' }],
      rules: [{ id: 'rule_2' }],
    });
  });

  it('does not add ids to a policy with no actions and no rules', () => {
    expect(addIdsToPolicy({ name: 'the best' })).toStrictEqual({ name: 'the best' });
  });
});

describe(isPolicyInherited, () => {
  it.each`
    input                   | output
    ${undefined}            | ${false}
    ${{}}                   | ${false}
    ${{ inherited: false }} | ${false}
    ${{ inherited: true }}  | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isPolicyInherited(input)).toBe(output);
  });
});

describe(policyHasNamespace, () => {
  it.each`
    input                              | output
    ${undefined}                       | ${false}
    ${{}}                              | ${false}
    ${{ namespace: undefined }}        | ${false}
    ${{ namespace: {} }}               | ${true}
    ${{ namespace: { name: 'name' } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyHasNamespace(input)).toBe(output);
  });
});

describe(isProject, () => {
  it.each`
    input                      | output
    ${NAMESPACE_TYPES.PROJECT} | ${true}
    ${NAMESPACE_TYPES.GROUP}   | ${false}
    ${null}                    | ${false}
    ${undefined}               | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isProject(input)).toEqual(output);
  });
});

describe(isGroup, () => {
  it.each`
    input                      | output
    ${NAMESPACE_TYPES.PROJECT} | ${false}
    ${NAMESPACE_TYPES.GROUP}   | ${true}
    ${null}                    | ${false}
    ${undefined}               | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isGroup(input)).toEqual(output);
  });
});

describe(isScanningReport, () => {
  it.each`
    input                    | output
    ${'container_scanning'}  | ${true}
    ${'dependency_scanning'} | ${true}
    ${'sast'}                | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isScanningReport(input)).toEqual(output);
  });
});

describe(isDefaultMode, () => {
  it.each`
    input                                                                                                                   | output
    ${undefined}                                                                                                            | ${true}
    ${null}                                                                                                                 | ${true}
    ${{}}                                                                                                                   | ${true}
    ${{ complianceFrameworks: { nodes: [] }, excludingProjects: { nodes: [] }, includingProjects: { nodes: [] } }}          | ${true}
    ${{ complianceFrameworks: { nodes: [] } }}                                                                              | ${true}
    ${{ excludingProjects: { nodes: [] } }}                                                                                 | ${true}
    ${{ includingProjects: { nodes: [] } }}                                                                                 | ${true}
    ${{ complianceFrameworks: { nodes: [{ id: 1 }] }, excludingProjects: { nodes: [] }, includingProjects: { nodes: [] } }} | ${false}
    ${{ complianceFrameworks: { nodes: [] }, excludingProjects: { nodes: [{ id: 1 }] }, includingProjects: { nodes: [] } }} | ${false}
    ${{ complianceFrameworks: { nodes: [] }, excludingProjects: { nodes: [] }, includingProjects: { nodes: [{ id: 1 }] } }} | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isDefaultMode(input)).toBe(output);
  });
});

describe('hasScheduledRule', () => {
  it.each`
    title                                                      | policy                                                                                                           | output
    ${'returns false for a non-schedule policy list policy'}   | ${{ __typename: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.typeName, yaml: mockDastScanExecutionManifest }}     | ${false}
    ${'returns true for a schedule policy list policy'}        | ${{ __typename: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.typeName, yaml: mockScheduleScanExecutionManifest }} | ${true}
    ${'returns false for a non-schedule policy editor policy'} | ${mockDastScanExecutionObject}                                                                                   | ${false}
    ${'returns true for a schedule policy editor policy'}      | ${mockScheduleScanExecutionObject}                                                                               | ${true}
  `('$title', ({ policy, output }) => {
    expect(hasScheduledRule(policy)).toBe(output);
  });
});

describe('checkForPerformanceRisk', () => {
  it.each`
    policyDesc                         | namespaceType              | policy                             | projectsCount | output
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.PROJECT} | ${mockDastScanExecutionObject}     | ${0}          | ${false}
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.GROUP}   | ${mockDastScanExecutionObject}     | ${0}          | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.PROJECT} | ${mockScheduleScanExecutionObject} | ${0}          | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.GROUP}   | ${mockScheduleScanExecutionObject} | ${0}          | ${false}
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.PROJECT} | ${mockDastScanExecutionObject}     | ${1001}       | ${false}
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.GROUP}   | ${mockDastScanExecutionObject}     | ${1001}       | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.PROJECT} | ${mockScheduleScanExecutionObject} | ${1001}       | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.GROUP}   | ${mockScheduleScanExecutionObject} | ${1001}       | ${true}
  `(
    'returns $output when namespaceType is $namespaceType, the policy $policyDesc, and projectsCount is $projectsCount',
    ({ namespaceType, policy, projectsCount, output }) => {
      expect(checkForPerformanceRisk({ namespaceType, policy, projectsCount })).toBe(output);
    },
  );

  describe('extractPolicyContent', () => {
    const defaultPayload = {};
    const extractedPolicyContent = {
      actions: [{ scan: 'secret_detection', template: 'latest' }],
      description: '',
      enabled: true,
      name: '',
      rules: [
        { branch_type: 'default', type: 'pipeline' },
        {
          branch_type: 'target_default',
          pipeline_sources: { including: ['merge_request_event'] },
          type: 'pipeline',
        },
      ],
      skip_ci: {
        allowed: true,
      },
    };

    it.each`
      type                          | manifest                         | withType | expectedManifest
      ${SCAN_EXECUTION_POLICY_TYPE} | ${DEFAULT_SCAN_EXECUTION_POLICY} | ${false} | ${extractedPolicyContent}
      ${SCAN_EXECUTION_POLICY_TYPE} | ${DEFAULT_SCAN_EXECUTION_POLICY} | ${true}  | ${{ ...extractedPolicyContent, type: SCAN_EXECUTION_POLICY_TYPE }}
      ${SCAN_EXECUTION_POLICY_TYPE} | ${''}                            | ${true}  | ${defaultPayload}
    `(
      'returns output without type wrapper for $type and withType $withType',
      ({ type, manifest, withType, expectedManifest }) => {
        expect(extractPolicyContent({ manifest, type, withType })).toEqual(expectedManifest);
      },
    );

    describe('when root key differs from type parameter', () => {
      const policyManifestWithUnknownRootKey = `
        unknown_policy_type:
          - name: test-policy
            enabled: true
      `;

      const testPolicyContent = {
        name: 'test-policy',
        enabled: true,
      };

      it.each`
        type                    | manifest                            | withType | expectedManifest
        ${APPROVAL_POLICY_TYPE} | ${policyManifestWithUnknownRootKey} | ${false} | ${testPolicyContent}
        ${APPROVAL_POLICY_TYPE} | ${policyManifestWithUnknownRootKey} | ${true}  | ${{ ...testPolicyContent, type: APPROVAL_POLICY_TYPE }}
        ${APPROVAL_POLICY_TYPE} | ${''}                               | ${true}  | ${defaultPayload}
      `(
        'ignores unknown root key and returns output without type wrapper for $type and withType $withType',
        ({ type, manifest, withType, expectedManifest }) => {
          expect(extractPolicyContent({ manifest, type, withType })).toEqual(expectedManifest);
        },
      );
    });
  });

  describe('extractPolicyContentFromRootTypeProperty', () => {
    const policyWithTypeRootKey = {
      scan_execution_policy: {
        name: 'Scan execution policy',
        enabled: true,
      },
    };

    const policyWithDifferentRootKey = {
      unknown_policy: {
        name: 'Scan execution policy',
        enabled: true,
      },
    };

    const policyWithoutTypeRootKey = {
      name: 'Scan execution policy',
      enabled: true,
    };

    const policyWrappedinArray = {
      unknown_policy: [policyWithoutTypeRootKey],
    };

    it.each`
      type                          | parsedYaml                    | expectedPolicyContent
      ${SCAN_EXECUTION_POLICY_TYPE} | ${policyWithTypeRootKey}      | ${policyWithoutTypeRootKey}
      ${SCAN_EXECUTION_POLICY_TYPE} | ${policyWithDifferentRootKey} | ${policyWithoutTypeRootKey}
      ${SCAN_EXECUTION_POLICY_TYPE} | ${policyWithoutTypeRootKey}   | ${policyWithoutTypeRootKey}
      ${SCAN_EXECUTION_POLICY_TYPE} | ${policyWrappedinArray}       | ${[policyWithoutTypeRootKey]}
    `(
      'returns payload without wrapper for $type',
      ({ type, parsedYaml, expectedPolicyContent }) => {
        expect(extractPolicyContentFromRootTypeProperty(parsedYaml, type)).toEqual(
          expectedPolicyContent,
        );
      },
    );
  });

  describe('createSpepTestRunSubscription', () => {
    const subscription = createSpepTestRunSubscription('currentRun', 'currentRun');

    it('returns the subscription query', () => {
      expect(subscription.query).toBeDefined();
    });

    describe('variables', () => {
      it('returns testRunId from the getter property', () => {
        expect(subscription.variables.call({ currentRun: { id: 'run-1' } })).toEqual({
          testRunId: 'run-1',
        });
      });

      it('returns undefined testRunId when getter property is null', () => {
        expect(subscription.variables.call({ currentRun: null })).toEqual({
          testRunId: undefined,
        });
      });
    });

    describe('result', () => {
      it('writes the subscription payload to the setter property', () => {
        const ctx = { currentRun: null };
        const updated = { id: 'run-1', state: 'COMPLETE' };
        subscription.result.call(ctx, {
          data: { securityPolicyScheduleTestRunUpdated: updated },
        });
        expect(ctx.currentRun).toEqual(updated);
      });

      it('does not write when payload is falsy', () => {
        const ctx = { currentRun: { id: 'run-1' } };
        subscription.result.call(ctx, { data: { securityPolicyScheduleTestRunUpdated: null } });
        expect(ctx.currentRun).toEqual({ id: 'run-1' });
      });
    });

    describe('skip', () => {
      it.each`
        testRun                                             | expected | label
        ${null}                                             | ${true}  | ${'null'}
        ${{ state: 'RUNNING', completed: false }}           | ${true}  | ${'no id'}
        ${{ id: '1', state: 'COMPLETE', completed: true }}  | ${true}  | ${'completed'}
        ${{ id: '1', state: 'FAILED', completed: true }}    | ${true}  | ${'failed state'}
        ${{ id: '1', state: 'RUNNING', completed: false }}  | ${false} | ${'active run'}
        ${{ id: '1', state: 'CREATING', completed: false }} | ${false} | ${'creating state'}
        ${{ id: '1', state: 'PENDING', completed: false }}  | ${false} | ${'pending state'}
      `('returns $expected when testRun is $label', ({ testRun, expected }) => {
        expect(subscription.skip.call({ currentRun: testRun })).toBe(expected);
      });
    });
  });
});
