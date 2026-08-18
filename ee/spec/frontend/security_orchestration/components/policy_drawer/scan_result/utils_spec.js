import {
  humanizeRules,
  mapApproversToArray,
} from 'ee/security_orchestration/components/policy_drawer/scan_result/utils';
import {
  anyMergeRequestBuildRule,
  securityScanBuildRule,
  licenseScanBuildRule,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';
import {
  ANY_UNSIGNED_COMMIT,
  ALL_PROTECTED_BRANCHES,
  HUMANIZED_BRANCH_TYPE_TEXT_DICT,
  INVALID_RULE_MESSAGE,
  NO_RULE_MESSAGE,
  PROJECT_DEFAULT_BRANCH,
  GREATER_THAN_OPERATOR,
  LESS_THAN_OPERATOR,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  AGE_MONTH,
  AGE_WEEK,
  ALLOWED,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

const { branch_type: defaultSecurityScanBranchType, ...securityScanBuildRuleWithoutBranchType } =
  securityScanBuildRule();

const { branch_type: defaultLicenseScanBranchType, ...licenseScanBuildRuleWithoutBranchType } =
  licenseScanBuildRule();

const singleValuedSecurityScannerRule = {
  rule: {
    ...securityScanBuildRuleWithoutBranchType,
    branches: ['main'],
    scanners: ['sast'],
    severity_levels: ['critical'],
    vulnerability_states: ['newly_detected'],
    vulnerability_attributes: { fix_available: true },
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary:
      'When SAST scanner finds any vulnerabilities in an open merge request targeting the main branch and all the following apply:',
    criteriaList: [
      'Severity is critical.',
      'Vulnerabilities are new and need triage or dismissed.',
      'Vulnerabilities have a fix available.',
    ],
  },
};

const noVulnerabilityStatesSecurityScannerRule = {
  rule: {
    ...securityScanBuildRuleWithoutBranchType,
    branches: ['main'],
    scanners: ['sast'],
    severity_levels: ['critical'],
    vulnerability_age: { operator: LESS_THAN_OPERATOR, value: 1, interval: AGE_WEEK },
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary:
      'When SAST scanner finds any vulnerabilities in an open merge request targeting the main branch and all the following apply:',
    criteriaList: ['Severity is critical.', 'Vulnerability age is less than 1 week.'],
  },
};

const multipleValuedSecurityScannerRule = {
  rule: {
    ...securityScanBuildRuleWithoutBranchType,
    branches: ['staging', 'main'],
    scanners: ['dast', 'sast'],
    vulnerabilities_allowed: 2,
    severity_levels: ['info', 'critical'],
    vulnerability_states: ['resolved'],
    vulnerability_age: { operator: GREATER_THAN_OPERATOR, value: 2, interval: AGE_MONTH },
    vulnerability_attributes: { fix_available: true, false_positive: false },
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary:
      'When DAST or SAST scanners find more than 2 vulnerabilities in an open merge request targeting the staging or main branches and all the following apply:',
    criteriaList: [
      'Severity is info or critical.',
      'Vulnerabilities are previously existing and resolved.',
      'Vulnerability age is greater than 2 months.',
      'Vulnerabilities have a fix available and are not false positives.',
    ],
  },
};

const noCriteriaSecurityScannerRule = {
  rule: {
    ...securityScanBuildRuleWithoutBranchType,
    branches: ['staging', 'main'],
    scanners: ['sast'],
    vulnerabilities_allowed: 1,
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary:
      'When SAST scanner finds more than 1 vulnerability in an open merge request targeting the staging or main branches.',
    criteriaList: [],
  },
};

const anyMergeRequestDefaultRule = {
  rule: {
    ...anyMergeRequestBuildRule(),
  },
  humanized: {
    branchExceptions: [],
    summary: 'For any merge request on targeting any protected branch for any commits.',
  },
};

const anyMergeRequestUnsignedCommitsWithExceptionsRule = {
  rule: {
    ...anyMergeRequestBuildRule(),
    commits: ANY_UNSIGNED_COMMIT,
    branch_exceptions: ['main', 'test'],
  },
  humanized: {
    branchExceptions: ['main', 'test'],
    summary:
      'For any merge request on targeting any protected branch for unsigned commits except branches:',
  },
};

const branchTypeSecurityScannerRule = (branchType = PROJECT_DEFAULT_BRANCH.value) => ({
  rule: {
    ...securityScanBuildRule(),
    branch_type: branchType,
    severity_levels: [],
    vulnerability_states: [],
    scanners: ['sast'],
    vulnerabilities_allowed: 1,
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary: `When SAST scanner finds more than 1 vulnerability in an open merge request targeting ${HUMANIZED_BRANCH_TYPE_TEXT_DICT[branchType]}.`,
    criteriaList: [],
  },
});

const branchExceptionsSecurityScannerRule = (branchExceptions = []) => ({
  rule: {
    ...securityScanBuildRule(),
    branch_type: PROJECT_DEFAULT_BRANCH.value,
    branch_exceptions: branchExceptions,
    severity_levels: [],
    vulnerability_states: [],
    scanners: ['sast'],
    vulnerabilities_allowed: 1,
  },
  humanized: {
    branchExceptions: ['test', 'test1'],
    criteriaList: [],
    criteriaMessage: '',
    summary: `When SAST scanner finds more than 1 vulnerability in an open merge request targeting ${
      HUMANIZED_BRANCH_TYPE_TEXT_DICT[PROJECT_DEFAULT_BRANCH.value]
    } except branches:`,
  },
});

const invalidBranchTypeSecurityScannerRule = {
  rule: {
    ...securityScanBuildRule(),
    scanners: [],
    branch_type: 'invalid',
  },
  humanized: {
    summary: INVALID_RULE_MESSAGE,
  },
};

const branchTypeAndBranchesSecurityScannerRule = {
  rule: {
    ...securityScanBuildRule(),
    scanners: [],
    branch_type: PROJECT_DEFAULT_BRANCH.value,
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary:
      'When any security scanner finds any vulnerabilities in an open merge request targeting the default branch.',
    criteriaList: [],
  },
};

const allValuedSecurityScannerRule = {
  rule: {
    ...securityScanBuildRule(),
    scanners: [],
    vulnerabilities_allowed: 2,
    severity_levels: ['info', 'critical'],
    vulnerability_states: ['new_needs_triage', 'resolved', 'confirmed'],
    vulnerability_attributes: { false_positive: true, fix_available: false },
  },
  humanized: {
    branchExceptions: [],
    criteriaMessage: '',
    summary:
      'When any security scanner finds more than 2 vulnerabilities in an open merge request targeting any protected branch and all the following apply:',
    criteriaList: [
      'Severity is info or critical.',
      'Vulnerabilities are new and need triage, or previously existing and resolved or confirmed.',
      'Vulnerabilities are false positives and have no fix available.',
    ],
  },
};

const singleValuedLicenseScanRule = {
  rule: {
    ...licenseScanBuildRuleWithoutBranchType,
    branches: ['main'],
    license_types: ['MIT License'],
    license_states: ['detected'],
  },
  humanized: {
    branchExceptions: [],
    licenses: ['MIT License'],
    denyAllowList: { [ALLOWED]: [] },
    licenseOverrides: [],
    summary:
      'When license scanner finds any license matching %{licenses} that is pre-existing and is in an open merge request targeting the main branch.',
  },
};

const singleValuedLicenseScanRuleWithAllowDenyList = (type = 'allowed') => ({
  rule: {
    ...licenseScanBuildRuleWithoutBranchType,
    branches: ['main'],
    license_types: ['MIT License'],
    license_states: ['detected'],
    licenses: {
      [type]: [
        { license: { text: 'MIT', value: 'mit' } },
        {
          license: { text: 'NPM', value: 'npm' },
          exceptions: ['pkg:npm40angular/animation@12.3.1', 'pkg:npm/foobar@12.3.1'],
        },
      ],
    },
  },
  humanized: {
    branchExceptions: [],
    licenses: ['MIT License'],
    denyAllowList: {
      [type]: [
        { license: { text: 'MIT', value: 'mit' } },
        {
          license: { text: 'NPM', value: 'npm' },
          exceptions: ['pkg:npm40angular/animation@12.3.1', 'pkg:npm/foobar@12.3.1'],
        },
      ],
    },
    licenseOverrides: [],
    summary:
      'When license scanner finds any license matching %{licenses} that is pre-existing and is in an open merge request targeting the main branch.',
  },
});

const multipleValuedLicenseScanRule = {
  rule: {
    ...licenseScanBuildRuleWithoutBranchType,
    branches: ['staging', 'main'],
    match_on_inclusion_license: false,
    license_types: ['CMU License', 'CNRI Jython License', 'CNRI Python License'],
    license_states: ['detected', 'newly_detected'],
  },
  humanized: {
    branchExceptions: [],
    denyAllowList: { [ALLOWED]: [] },
    licenseOverrides: [],
    licenses: ['CMU License', 'CNRI Jython License', 'CNRI Python License'],
    summary:
      'When license scanner finds any license except %{licenses} in an open merge request targeting the staging or main branches.',
  },
};

const branchTypeLicenseScanRule = (branchType = PROJECT_DEFAULT_BRANCH.value) => ({
  rule: {
    ...licenseScanBuildRule(),
    branch_type: branchType,
    match_on_inclusion_license: false,
    license_types: ['CMU License', 'CNRI Jython License', 'CNRI Python License'],
    license_states: ['detected', 'newly_detected'],
  },
  humanized: {
    branchExceptions: [],
    denyAllowList: { [ALLOWED]: [] },
    licenseOverrides: [],
    summary: `When license scanner finds any license except %{licenses} in an open merge request targeting ${HUMANIZED_BRANCH_TYPE_TEXT_DICT[branchType]}.`,
    licenses: ['CMU License', 'CNRI Jython License', 'CNRI Python License'],
  },
});

const branchExceptionLicenseScanRule = (branchExceptions = []) => ({
  rule: {
    ...licenseScanBuildRule(),
    branch_type: PROJECT_DEFAULT_BRANCH.value,
    branch_exceptions: branchExceptions,
    match_on_inclusion_license: false,
    license_types: ['CMU License', 'CNRI Jython License', 'CNRI Python License'],
    license_states: ['detected', 'newly_detected'],
  },
  humanized: {
    summary: `When license scanner finds any license except %{licenses} in an open merge request targeting ${
      HUMANIZED_BRANCH_TYPE_TEXT_DICT[PROJECT_DEFAULT_BRANCH.value]
    } except branches:`,
    branchExceptions: ['test', 'test1'],
    denyAllowList: { [ALLOWED]: [] },
    licenseOverrides: [],
    licenses: ['CMU License', 'CNRI Jython License', 'CNRI Python License'],
  },
});

describe('humanizeRules', () => {
  it('returns the empty rules message in an Array if no rules are specified', () => {
    expect(humanizeRules([])).toStrictEqual([{ summary: NO_RULE_MESSAGE }]);
  });

  describe('security scanner rules', () => {
    it('returns a single rule as a human-readable string for user approvers only', () => {
      expect(humanizeRules([singleValuedSecurityScannerRule.rule])).toStrictEqual([
        singleValuedSecurityScannerRule.humanized,
      ]);
    });

    it('returns multiple rules with different number of branches/scanners as human-readable strings', () => {
      expect(
        humanizeRules([
          singleValuedSecurityScannerRule.rule,
          multipleValuedSecurityScannerRule.rule,
          noVulnerabilityStatesSecurityScannerRule.rule,
          noCriteriaSecurityScannerRule.rule,
        ]),
      ).toStrictEqual([
        singleValuedSecurityScannerRule.humanized,
        multipleValuedSecurityScannerRule.humanized,
        noVulnerabilityStatesSecurityScannerRule.humanized,
        noCriteriaSecurityScannerRule.humanized,
      ]);
    });

    it('returns a single rule as a human-readable string for all scanners and all protected branches', () => {
      expect(humanizeRules([allValuedSecurityScannerRule.rule])).toStrictEqual([
        allValuedSecurityScannerRule.humanized,
      ]);
    });

    it.each([PROJECT_DEFAULT_BRANCH.value, ALL_PROTECTED_BRANCHES.value])(
      'returns a single rule as a human-readable string for rules with branch type',
      (branchType) => {
        expect(humanizeRules([branchTypeSecurityScannerRule(branchType).rule])).toStrictEqual([
          branchTypeSecurityScannerRule(branchType).humanized,
        ]);
      },
    );

    it('returns a single rule as a human-readable string for rules with branch exceptions', () => {
      expect(
        humanizeRules([branchExceptionsSecurityScannerRule(['test', 'test1']).rule]),
      ).toStrictEqual([branchExceptionsSecurityScannerRule(['test', 'test1']).humanized]);
    });

    it('returns a single rule as a human-readable string for rules with branch type and branches', () => {
      expect(humanizeRules([branchTypeAndBranchesSecurityScannerRule.rule])).toStrictEqual([
        branchTypeAndBranchesSecurityScannerRule.humanized,
      ]);
    });

    it('returns a default human-readable string for rules with invalid branch type', () => {
      expect(humanizeRules([invalidBranchTypeSecurityScannerRule.rule])).toStrictEqual([
        invalidBranchTypeSecurityScannerRule.humanized,
      ]);
    });
  });

  describe('license scanner rules', () => {
    it('returns a single rule as a human-readable string for user approvers only', () => {
      expect(humanizeRules([singleValuedLicenseScanRule.rule])).toStrictEqual([
        singleValuedLicenseScanRule.humanized,
      ]);
    });

    it.each(['allowed', 'denied'])(
      'returns a single rule as a human-readable string with allow deny list',
      (type) => {
        expect(
          humanizeRules([singleValuedLicenseScanRuleWithAllowDenyList(type).rule]),
        ).toStrictEqual([singleValuedLicenseScanRuleWithAllowDenyList(type).humanized]);
      },
    );

    it('returns multiple rules with different number of branches/scanners as human-readable strings', () => {
      expect(
        humanizeRules([singleValuedLicenseScanRule.rule, multipleValuedLicenseScanRule.rule]),
      ).toStrictEqual([
        singleValuedLicenseScanRule.humanized,
        multipleValuedLicenseScanRule.humanized,
      ]);
    });

    it.each([PROJECT_DEFAULT_BRANCH.value, ALL_PROTECTED_BRANCHES.value])(
      'returns a single rule as a human-readable string for rules with branch type',
      (branchType) => {
        expect(humanizeRules([branchTypeLicenseScanRule(branchType).rule])).toStrictEqual([
          branchTypeLicenseScanRule(branchType).humanized,
        ]);
      },
    );

    it('returns a single rule as a human-readable string for rules with branch exceptions', () => {
      expect(humanizeRules([branchExceptionLicenseScanRule(['test', 'test1']).rule])).toStrictEqual(
        [branchExceptionLicenseScanRule(['test', 'test1']).humanized],
      );
    });
  });

  describe('any merge request rule', () => {
    it.each`
      description                                          | expectedRule
      ${'rules with commit type'}                          | ${anyMergeRequestDefaultRule}
      ${'rules with unsigned commits and with exceptions'} | ${anyMergeRequestUnsignedCommitsWithExceptionsRule}
    `(
      'returns a single rule as a human-readable string for any merge request $description',
      ({ expectedRule }) => {
        expect(humanizeRules([expectedRule.rule])).toStrictEqual([expectedRule.humanized]);
      },
    );
  });

  describe('object-format scanners', () => {
    it('returns per-scanner details for object-format scanners', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'sast',
            vulnerabilities_allowed: 0,
            severity_levels: ['critical', 'high'],
            vulnerability_states: ['newly_detected'],
            vulnerability_attributes: { false_positive: false },
          },
          {
            type: 'secret_detection',
            vulnerabilities_allowed: 0,
            severity_levels: ['critical', 'high'],
            vulnerability_states: ['newly_detected'],
          },
          {
            type: 'dependency_scanning',
            vulnerabilities_allowed: 0,
            severity_levels: ['critical', 'high'],
            vulnerability_states: ['newly_detected'],
            vulnerability_attributes: {
              false_positive: false,
              fix_available: true,
              known_exploited: true,
              epss_score: { operator: 'greater_than', value: 0.1 },
            },
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails).toBeDefined();
      expect(result[0].scannerDetails).toHaveLength(3);
      expect(result[0].criteriaList).toEqual([]);
      expect(result[0].summary).toBe(
        'When the following scanners find any vulnerabilities in an open merge request targeting the default branch:',
      );

      expect(result[0].scannerDetails[0].name).toBe('SAST');
      expect(result[0].scannerDetails[0].criteriaList).toEqual([
        'No new vulnerabilities allowed',
        'Severity is critical or high',
        'New and need triage or dismissed',
        'Are not false positives',
      ]);

      expect(result[0].scannerDetails[1].name).toBe('Secret detection');
      expect(result[0].scannerDetails[1].criteriaList).toEqual([
        'No new vulnerabilities allowed',
        'Severity is critical or high',
        'New and need triage or dismissed',
      ]);

      expect(result[0].scannerDetails[2].name).toBe('Dependency scanning');
      expect(result[0].scannerDetails[2].criteriaList).toEqual([
        'No new vulnerabilities allowed',
        'Severity is critical or high',
        'New and need triage or dismissed',
        'Are not false positives and have a fix available and are in the KEV catalog',
        'EPSS score is greater than 10%',
      ]);
    });

    it('renders per-scanner vulnerabilities_allowed overrides', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'sast',
            vulnerabilities_allowed: 5,
            severity_levels: ['critical'],
            vulnerability_states: [],
          },
          {
            type: 'dependency_scanning',
            vulnerabilities_allowed: 1,
            severity_levels: ['high'],
            vulnerability_states: [],
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails[0].criteriaList).toContain(
        'Allows more than 5 vulnerabilities',
      );
      expect(result[0].scannerDetails[1].criteriaList).toContain(
        'Allows more than 1 vulnerability',
      );
    });

    it('does not return scannerDetails for string-format scanners', () => {
      const rule = {
        ...securityScanBuildRule(),
        scanners: ['sast', 'dast'],
        severity_levels: ['critical'],
        vulnerability_states: [],
        vulnerabilities_allowed: 0,
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails).toBeUndefined();
      expect(result[0].criteriaList).toContainEqual('Severity is critical.');
    });

    it('handles scanner objects with known_exploited attribute', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'container_scanning',
            severity_levels: [],
            vulnerability_states: [],
            vulnerability_attributes: { known_exploited: true },
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails[0].criteriaList).toEqual(['Are in the KEV catalog']);
    });

    it('handles scanner objects with epss_score only', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'dependency_scanning',
            severity_levels: [],
            vulnerability_states: [],
            vulnerability_attributes: {
              epss_score: { operator: 'greater_than', value: 0.5 },
            },
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails[0].criteriaList).toEqual(['EPSS score is greater than 50%']);
    });

    it('handles scanner objects with enrichment_data_unavailable block action', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'container_scanning',
            severity_levels: [],
            vulnerability_states: [],
            vulnerability_attributes: {
              enrichment_data_unavailable: { action: 'block' },
            },
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails[0].criteriaList).toEqual([
        'When KEV or EPSS data is unavailable, block merge requests based on the severity of the vulnerability',
      ]);
    });

    it('handles scanner objects with enrichment_data_unavailable ignore action', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'dependency_scanning',
            severity_levels: [],
            vulnerability_states: [],
            vulnerability_attributes: {
              enrichment_data_unavailable: { action: 'ignore' },
            },
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails[0].criteriaList).toEqual([
        'When KEV or EPSS data is unavailable, exclude the vulnerability from policy evaluation',
      ]);
    });

    it('renders enrichment_data_unavailable alongside other vulnerability attributes', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          {
            type: 'container_scanning',
            vulnerabilities_allowed: 0,
            severity_levels: ['critical', 'high'],
            vulnerability_states: ['newly_detected'],
            vulnerability_attributes: {
              known_exploited: true,
              fix_available: true,
              epss_score: { operator: 'greater_than', value: 0.5 },
              enrichment_data_unavailable: { action: 'ignore' },
            },
          },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].scannerDetails[0].criteriaList).toEqual([
        'No new vulnerabilities allowed',
        'Severity is critical or high',
        'New and need triage or dismissed',
        'Are in the KEV catalog and have a fix available',
        'EPSS score is greater than 50%',
        'When KEV or EPSS data is unavailable, exclude the vulnerability from policy evaluation',
      ]);
    });

    it('uses "the following scanners" summary and omits scanner list when using object-format scanners', () => {
      const rule = {
        type: 'scan_finding',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        vulnerabilities_allowed: 0,
        scanners: [
          { type: 'sast', severity_levels: ['critical'], vulnerability_states: [] },
          { type: 'dast', severity_levels: ['high'], vulnerability_states: [] },
        ],
      };

      const result = humanizeRules([rule]);

      expect(result[0].summary).toBe(
        'When the following scanners find any vulnerabilities in an open merge request targeting the default branch:',
      );
      expect(result[0].summary).not.toContain('SAST');
      expect(result[0].summary).not.toContain('DAST');
    });
  });

  describe('mapApproversToArray', () => {
    const user = { id: 1, name: 'user-1' };
    const group = { id: 1, name: 'group-1' };
    const customRole = { id: 'gid://gitlab/MemberRole/1', name: 'Custom (Gitlab Org - 24)' };

    it.each`
      approvers                                                       | expectedResult
      ${undefined}                                                    | ${[]}
      ${{}}                                                           | ${[]}
      ${{ allGroups: [group], customRoles: [customRole] }}            | ${[group, customRole]}
      ${{ roles: ['invalid-role'] }}                                  | ${[]}
      ${{ roles: ['MAINTAINER'], users: [user] }}                     | ${['Maintainer', user]}
      ${{ roles: undefined, users: undefined, allGroups: undefined }} | ${[]}
    `(
      'returns flat array of approvers when the approvers are $approvers',
      ({ approvers, expectedResult }) => {
        expect(mapApproversToArray(approvers)).toEqual(expectedResult);
      },
    );
  });
});
