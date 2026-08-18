import MockAdapter from 'axios-mock-adapter';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import axios from '~/lib/utils/axios_utils';
import { SEVERITY_LEVEL_CRITICAL, SEVERITY_LEVEL_HIGH } from 'ee/security_dashboard/constants';
import {
  buildDefaultScannerObject,
  DEFAULT_EPSS_VALUE,
  getInvalidBranches,
  hasInvalidRules,
  humanizeInvalidBranchesError,
  invalidScanners,
  invalidSeverities,
  invalidVulnerabilitiesAllowed,
  invalidVulnerabilityStates,
  invalidBranchType,
  invalidVulnerabilityAge,
  invalidVulnerabilityAttributes,
  isDefaultScannerConfiguration,
  isRecommendedScannersSelection,
  migrateEmptyScannersToAllScanners,
  resolveScannersFromSelection,
  RECOMMENDED_SCANNERS_KEY,
  DEFAULT_SCANNERS,
  SCANNER_DEFAULT_ATTRIBUTES,
  SCANNER_VALID_KEYS,
  licenseScanBuildRule,
  securityScanBuildRule,
  VULNERABILITY_STATE_KEYS,
  isMaliciousScanner,
  isMalwareEligibleScanner,
  hasMalwareEligibleScanner,
  hasMalwareBlockingEnabled,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';
import {
  APPROVAL_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  NEW_NEEDS_TRIAGE,
  PREVIOUSLY_EXISTING,
  AGE_DAY,
  ALLOWED,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  ANY_OPERATOR,
  GREATER_THAN_OPERATOR,
  MATCH_ON_INCLUSION_LICENSE,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('securityScanBuildRule', () => {
  it('returns default scanners as objects with per-scanner vulnerability attributes', () => {
    const { scanners } = securityScanBuildRule();

    expect(scanners).toHaveLength(3);
    expect(scanners[0]).toEqual(buildDefaultScannerObject('sast'));
    expect(scanners[1]).toEqual(buildDefaultScannerObject('secret_detection'));
    expect(scanners[2]).toEqual(buildDefaultScannerObject('dependency_scanning'));
  });

  it('returns independent scanner instances with no shared references', () => {
    const ruleA = securityScanBuildRule();
    const ruleB = securityScanBuildRule();

    ruleA.scanners[0].severity_levels.push('critical');

    expect(ruleB.scanners[0].severity_levels).toEqual(['critical', 'high']);
  });
});

describe('SCANNER_DEFAULT_ATTRIBUTES', () => {
  it('exports default attributes for supported scanner types', () => {
    expect(SCANNER_DEFAULT_ATTRIBUTES).toHaveProperty('sast');
    expect(SCANNER_DEFAULT_ATTRIBUTES).toHaveProperty('dependency_scanning');
    expect(SCANNER_DEFAULT_ATTRIBUTES).toHaveProperty('container_scanning');
    expect(SCANNER_DEFAULT_ATTRIBUTES).not.toHaveProperty('secret_detection');
    expect(SCANNER_DEFAULT_ATTRIBUTES).not.toHaveProperty('dast');
  });

  it('exports DEFAULT_EPSS_VALUE as a number', () => {
    expect(typeof DEFAULT_EPSS_VALUE).toBe('number');
    expect(DEFAULT_EPSS_VALUE).toBe(0.1);
  });

  it('provides independent objects for dependency_scanning and container_scanning', () => {
    const depAttrs = SCANNER_DEFAULT_ATTRIBUTES.dependency_scanning;
    const csAttrs = SCANNER_DEFAULT_ATTRIBUTES.container_scanning;

    expect(depAttrs).not.toBe(csAttrs);
    expect(depAttrs).toEqual(csAttrs);
  });
});

describe('buildDefaultScannerObject', () => {
  const defaultSeverityLevels = [SEVERITY_LEVEL_CRITICAL, SEVERITY_LEVEL_HIGH];
  const defaultVulnerabilityStates = [NEW_NEEDS_TRIAGE];

  it('returns sast scanner with false_positive attribute', () => {
    const scanner = buildDefaultScannerObject('sast');

    expect(scanner).toEqual({
      type: 'sast',
      vulnerabilities_allowed: 0,
      severity_levels: defaultSeverityLevels,
      vulnerability_states: defaultVulnerabilityStates,
      vulnerability_attributes: {
        false_positive: false,
      },
    });
  });

  it('returns secret_detection scanner without vulnerability_attributes', () => {
    const scanner = buildDefaultScannerObject('secret_detection');

    expect(scanner).toEqual({
      type: 'secret_detection',
      vulnerabilities_allowed: 0,
      severity_levels: defaultSeverityLevels,
      vulnerability_states: defaultVulnerabilityStates,
    });
    expect(scanner).not.toHaveProperty('vulnerability_attributes');
  });

  it('returns dependency_scanning scanner with full vulnerability_attributes', () => {
    const scanner = buildDefaultScannerObject('dependency_scanning');

    expect(scanner).toEqual({
      type: 'dependency_scanning',
      vulnerabilities_allowed: 0,
      severity_levels: defaultSeverityLevels,
      vulnerability_states: defaultVulnerabilityStates,
      vulnerability_attributes: {
        false_positive: false,
        fix_available: true,
        known_exploited: true,
        epss_score: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
        enrichment_data_unavailable: { action: 'block' },
      },
    });
  });

  it('returns container_scanning scanner with full vulnerability_attributes', () => {
    const scanner = buildDefaultScannerObject('container_scanning');

    expect(scanner).toEqual({
      type: 'container_scanning',
      vulnerabilities_allowed: 0,
      severity_levels: defaultSeverityLevels,
      vulnerability_states: defaultVulnerabilityStates,
      vulnerability_attributes: {
        false_positive: false,
        fix_available: true,
        known_exploited: true,
        epss_score: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
        enrichment_data_unavailable: { action: 'block' },
      },
    });
  });

  it('returns dast scanner without vulnerability_attributes', () => {
    const scanner = buildDefaultScannerObject('dast');

    expect(scanner).toEqual({
      type: 'dast',
      vulnerabilities_allowed: 0,
      severity_levels: defaultSeverityLevels,
      vulnerability_states: defaultVulnerabilityStates,
    });
    expect(scanner).not.toHaveProperty('vulnerability_attributes');
  });

  it('exports SCANNER_DEFAULT_ATTRIBUTES for each supported scanner type', () => {
    expect(SCANNER_DEFAULT_ATTRIBUTES).toHaveProperty('sast');
    expect(SCANNER_DEFAULT_ATTRIBUTES).toHaveProperty('dependency_scanning');
    expect(SCANNER_DEFAULT_ATTRIBUTES).toHaveProperty('container_scanning');
    expect(SCANNER_DEFAULT_ATTRIBUTES).not.toHaveProperty('secret_detection');
    expect(SCANNER_DEFAULT_ATTRIBUTES).not.toHaveProperty('dast');
  });

  it('returns independent instances with no shared references between calls', () => {
    // Verify cloneDeep is working — mutating one instance must not affect another.
    // Without deep cloning, the nested epss_score object would be shared by reference.
    const a = buildDefaultScannerObject('dependency_scanning');
    const b = buildDefaultScannerObject('dependency_scanning');

    a.vulnerability_attributes.epss_score.value = 999;

    expect(b.vulnerability_attributes.epss_score.value).toBe(DEFAULT_EPSS_VALUE);
  });

  it('does not mutate SCANNER_DEFAULT_ATTRIBUTES when instance is modified', () => {
    const scanner = buildDefaultScannerObject('dependency_scanning');
    scanner.vulnerability_attributes.known_exploited = false;
    scanner.vulnerability_attributes.epss_score.value = 0;

    // The module-level constant must remain untouched
    const freshScanner = buildDefaultScannerObject('dependency_scanning');
    expect(freshScanner.vulnerability_attributes.known_exploited).toBe(true);
    expect(freshScanner.vulnerability_attributes.epss_score.value).toBe(DEFAULT_EPSS_VALUE);
  });

  describe('is_malicious attribute (securityPoliciesMalwareAttribute flag)', () => {
    const originalGon = window.gon;

    afterEach(() => {
      window.gon = originalGon;
    });

    describe('when the flag is off', () => {
      it.each(['dependency_scanning', 'container_scanning', 'sast', 'secret_detection', 'dast'])(
        'does not add is_malicious to the %s scanner when gon is unset',
        (type) => {
          window.gon = {};
          expect(buildDefaultScannerObject(type)).not.toHaveProperty('is_malicious');
        },
      );

      it.each(['dependency_scanning', 'container_scanning'])(
        'does not add is_malicious to the %s scanner when the flag is explicitly false',
        (type) => {
          window.gon = { features: { securityPoliciesMalwareAttribute: false } };
          expect(buildDefaultScannerObject(type)).not.toHaveProperty('is_malicious');
        },
      );
    });

    describe('when the flag is on', () => {
      beforeEach(() => {
        window.gon = { features: { securityPoliciesMalwareAttribute: true } };
      });

      it.each(['dependency_scanning', 'container_scanning'])(
        'adds is_malicious: true to the %s scanner',
        (type) => {
          expect(buildDefaultScannerObject(type)).toMatchObject({ is_malicious: true });
        },
      );

      it.each(['sast', 'secret_detection', 'dast'])(
        'does not add is_malicious to the non-DS/CS %s scanner',
        (type) => {
          expect(buildDefaultScannerObject(type)).not.toHaveProperty('is_malicious');
        },
      );
    });
  });
});

describe('SCANNER_VALID_KEYS', () => {
  it('includes is_malicious', () => {
    expect(SCANNER_VALID_KEYS).toContain('is_malicious');
  });
});

describe('isDefaultScannerConfiguration', () => {
  const modifiedDepScanner = () => {
    const scanner = buildDefaultScannerObject('dependency_scanning');
    scanner.vulnerability_attributes.known_exploited = false;
    return scanner;
  };

  const depScannerWithoutAttributes = () => {
    const { vulnerability_attributes, ...scanner } =
      buildDefaultScannerObject('dependency_scanning');
    return scanner;
  };

  it.each`
    title                                                          | scanner                                                                         | expectedResult
    ${'default sast scanner'}                                      | ${buildDefaultScannerObject('sast')}                                            | ${true}
    ${'default dependency_scanning scanner with full attributes'}  | ${buildDefaultScannerObject('dependency_scanning')}                             | ${true}
    ${'default container_scanning scanner with full attributes'}   | ${buildDefaultScannerObject('container_scanning')}                              | ${true}
    ${'scanner with an id property'}                               | ${{ ...buildDefaultScannerObject('sast'), id: '123' }}                          | ${true}
    ${'scanner with a branch_type property'}                       | ${{ ...buildDefaultScannerObject('sast'), branch_type: 'protected' }}           | ${true}
    ${'scanner with modified severity_levels'}                     | ${{ ...buildDefaultScannerObject('sast'), severity_levels: ['critical'] }}      | ${false}
    ${'scanner with modified vulnerability_states'}                | ${{ ...buildDefaultScannerObject('sast'), vulnerability_states: ['detected'] }} | ${false}
    ${'scanner with modified vulnerabilities_allowed'}             | ${{ ...buildDefaultScannerObject('sast'), vulnerabilities_allowed: 5 }}         | ${false}
    ${'dependency scanner with modified vulnerability_attributes'} | ${modifiedDepScanner()}                                                         | ${false}
    ${'dependency scanner missing vulnerability_attributes'}       | ${depScannerWithoutAttributes()}                                                | ${false}
  `('returns $expectedResult for $title', ({ scanner, expectedResult }) => {
    expect(isDefaultScannerConfiguration(scanner)).toBe(expectedResult);
  });
});

describe('isRecommendedScannersSelection', () => {
  const defaultScannerObjects = [
    buildDefaultScannerObject('sast'),
    buildDefaultScannerObject('secret_detection'),
    buildDefaultScannerObject('dependency_scanning'),
  ];

  it.each`
    title                                       | scanners                                               | expectedResult
    ${'object scanners matching default types'} | ${defaultScannerObjects}                               | ${true}
    ${'string scanners matching default types'} | ${['sast', 'secret_detection', 'dependency_scanning']} | ${true}
    ${'scanners that do not match'}             | ${[buildDefaultScannerObject('sast')]}                 | ${false}
    ${'empty array'}                            | ${[]}                                                  | ${false}
    ${'undefined'}                              | ${undefined}                                           | ${false}
  `('returns $expectedResult for $title', ({ scanners, expectedResult }) => {
    expect(isRecommendedScannersSelection(scanners)).toBe(expectedResult);
  });
});

describe('migrateEmptyScannersToAllScanners', () => {
  it('migrates empty scanners to all available scanner types', () => {
    const rule = { type: 'scan_finding', scanners: [], severity_levels: ['critical'] };
    const result = migrateEmptyScannersToAllScanners(rule);

    expect(result.scanners).toHaveLength(7);
    expect(result.scanners.map((s) => s.type)).toEqual([
      'api_fuzzing',
      'container_scanning',
      'coverage_fuzzing',
      'dast',
      'dependency_scanning',
      'sast',
      'secret_detection',
    ]);
    expect(result.severity_levels).toEqual(['critical']);
  });

  it('creates each scanner with default configuration', () => {
    const rule = { type: 'scan_finding', scanners: [] };
    const result = migrateEmptyScannersToAllScanners(rule);

    result.scanners.forEach((scanner) => {
      expect(scanner).toEqual(buildDefaultScannerObject(scanner.type));
    });
  });

  it('does not modify rules with existing scanners', () => {
    const rule = { type: 'scan_finding', scanners: [{ type: 'sast' }] };
    const result = migrateEmptyScannersToAllScanners(rule);

    expect(result).toBe(rule);
  });

  it('does not modify rules without scanners array', () => {
    const rule = { type: 'scan_finding' };
    const result = migrateEmptyScannersToAllScanners(rule);

    expect(result).toBe(rule);
  });

  it('does not modify rules with null scanners', () => {
    const rule = { type: 'scan_finding', scanners: null };
    const result = migrateEmptyScannersToAllScanners(rule);

    expect(result).toBe(rule);
  });
});

describe('resolveScannersFromSelection', () => {
  const allScannerKeys = [
    'api_fuzzing',
    'container_scanning',
    'coverage_fuzzing',
    'dast',
    'dependency_scanning',
    'sast',
    'secret_detection',
  ];

  const recommendedTypes = ['sast', 'secret_detection', 'dependency_scanning'];

  const existingSastScanner = {
    type: 'sast',
    vulnerabilities_allowed: 0,
    severity_levels: ['critical'],
    vulnerability_states: [],
  };

  const allScannerObjects = allScannerKeys.map((type) => buildDefaultScannerObject(type));

  it.each`
    title                                                                   | values                                                                           | currentScanners       | existingScannerObjects   | expectedLength             | expectedTypes
    ${'returns recommended when recommended is newly selected'}             | ${[RECOMMENDED_SCANNERS_KEY, 'sast']}                                            | ${[{ type: 'sast' }]} | ${[existingSastScanner]} | ${DEFAULT_SCANNERS.length} | ${recommendedTypes}
    ${'selects all when select all is triggered with recommended key'}      | ${[RECOMMENDED_SCANNERS_KEY, ...allScannerKeys]}                                 | ${[{ type: 'sast' }]} | ${[existingSastScanner]} | ${allScannerKeys.length}   | ${allScannerKeys}
    ${'switches to recommended when all scanners were previously selected'} | ${[RECOMMENDED_SCANNERS_KEY, ...allScannerKeys]}                                 | ${allScannerObjects}  | ${allScannerObjects}     | ${DEFAULT_SCANNERS.length} | ${recommendedTypes}
    ${'deselects recommended when recommended was previously selected'}     | ${[RECOMMENDED_SCANNERS_KEY, 'sast', 'secret_detection', 'dependency_scanning']} | ${DEFAULT_SCANNERS}   | ${DEFAULT_SCANNERS}      | ${3}                       | ${recommendedTypes}
    ${'returns selected scanners without recommended key'}                  | ${['sast', 'dast']}                                                              | ${[]}                 | ${[]}                    | ${2}                       | ${['sast', 'dast']}
  `(
    '$title',
    ({ values, currentScanners, existingScannerObjects, expectedLength, expectedTypes }) => {
      const result = resolveScannersFromSelection(values, currentScanners, existingScannerObjects);

      expect(result).toHaveLength(expectedLength);
      expect(result.map((s) => s.type)).toEqual(expect.arrayContaining(expectedTypes));
    },
  );

  it('preserves existing scanner objects with custom configuration', () => {
    const result = resolveScannersFromSelection(
      ['sast', 'dast'],
      [existingSastScanner],
      [existingSastScanner],
    );

    expect(result[0]).toEqual(existingSastScanner);
    expect(result[0].severity_levels).toEqual(['critical']);
  });

  it('creates default scanner object for newly added scanners', () => {
    const result = resolveScannersFromSelection(
      ['sast', 'dast'],
      [existingSastScanner],
      [existingSastScanner],
    );

    expect(result[1]).toEqual(buildDefaultScannerObject('dast'));
  });

  it('deep-clones existing scanner objects so mutations do not corrupt the source', () => {
    const values = ['sast'];
    const result = resolveScannersFromSelection(
      values,
      [existingSastScanner],
      [existingSastScanner],
    );

    result[0].severity_levels.push('high');

    expect(existingSastScanner.severity_levels).toEqual(['critical']);
  });
});

describe('invalidScanners', () => {
  describe('with undefined rules', () => {
    it('returns false', () => {
      expect(invalidScanners(undefined)).toBe(false);
    });
  });

  describe('with empty rules', () => {
    it('returns false', () => {
      expect(invalidScanners([])).toBe(false);
    });
  });

  describe('with rules with valid string scanners', () => {
    it('returns false', () => {
      expect(invalidScanners([{ scanners: ['sast'] }])).toBe(false);
    });
  });

  describe('with rules with valid object scanners', () => {
    it('returns false', () => {
      expect(invalidScanners([{ scanners: [{ type: 'sast' }] }])).toBe(false);
    });
  });

  describe('with rules with mixed valid string and object scanners', () => {
    it('returns false', () => {
      expect(invalidScanners([{ scanners: ['sast', { type: 'dast' }] }])).toBe(false);
    });
  });

  describe('with rules without scanners', () => {
    it('returns false', () => {
      expect(invalidScanners([{ anotherKey: 'anotherValue' }])).toBe(false);
    });
  });

  describe('with rules with invalid string scanners', () => {
    it('returns true', () => {
      expect(invalidScanners([{ scanners: ['notValid'] }])).toBe(true);
    });
  });

  describe('with rules with invalid object scanners', () => {
    it('returns true', () => {
      expect(invalidScanners([{ scanners: [{ type: 'notValid' }] }])).toBe(true);
    });
  });

  describe('with rules with invalid scanner type', () => {
    it('returns true', () => {
      expect(invalidScanners([{ scanners: [123] }])).toBe(true);
    });
  });
});

describe('invalidSeverities', () => {
  it('returns false with undefined rules', () => {
    expect(invalidSeverities(undefined)).toBe(false);
  });

  it('returns false with empty rules', () => {
    expect(invalidSeverities([])).toBe(false);
  });

  it('returns false with rules with valid severities', () => {
    expect(invalidSeverities([{ severity_levels: ['high'] }])).toBe(false);
  });

  it('returns false with multiple rules with the same severities', () => {
    expect(invalidSeverities([{ severity_levels: ['high'] }, { severity_levels: ['high'] }])).toBe(
      false,
    );
  });

  it('returns true with rules with duplicate severities', () => {
    expect(invalidSeverities([{ severity_levels: ['critical', 'critical'] }])).toBe(true);
  });

  it('returns true with rules with invalid severities', () => {
    expect(invalidSeverities([{ severity_levels: ['invalid'] }])).toBe(true);
  });
});

describe('hasInvalidRules', () => {
  it('creates an error when policy scanners are invalid', () => {
    expect(hasInvalidRules([{ scanners: ['cluster_image_scanning'] }])).toBe(true);
  });

  it('creates an error when policy severity_levels are invalid', () => {
    expect(hasInvalidRules([{ severity_levels: ['non-existent'] }])).toBe(true);
  });

  it('creates an error when vulnerabilities_allowed are invalid', () => {
    expect(hasInvalidRules([{ vulnerabilities_allowed: 'invalid' }])).toBe(true);
  });

  it('creates an error when vulnerability_states are invalid', () => {
    expect(hasInvalidRules([{ vulnerability_states: ['invalid'] }])).toBe(true);
  });

  it('creates an error when vulnerability_age is invalid', () => {
    expect(hasInvalidRules([{ vulnerability_age: { operator: 'invalid' } }])).toBe(true);
  });

  it('creates an error when vulnerability_attributes are invalid', () => {
    expect(hasInvalidRules([{ vulnerability_attributes: [{ invalid: true }] }])).toBe(true);
  });
});

describe('getInvalidBranches', () => {
  const projectId = 3;
  const branches = {
    valid: {
      name: 'main',
      endpoint: `/api/undefined/projects/${projectId}/protected_branches/main`,
      response: HTTP_STATUS_OK,
    },
    invalid: {
      name: 'invalidBranch',
      endpoint: `/api/undefined/projects/${projectId}/protected_branches/invalidBranch`,
      response: HTTP_STATUS_NOT_FOUND,
    },
  };
  const getBranchesValues = (types, property) => {
    return types.map((type) => branches[type][property]);
  };

  let mock;

  beforeAll(() => {
    mock = new MockAdapter(axios);
    mock
      .onGet(branches.valid.endpoint)
      .reply(branches.valid.response)
      .onGet(branches.invalid.endpoint)
      .reply(branches.invalid.response);
  });

  afterAll(() => {
    mock.restore();
  });

  it.each`
    title                                                                                          | input                     | output
    ${'returns [] passed only valid branches names'}                                               | ${['valid', 'valid']}     | ${[]}
    ${'returns invalid branch names when passed only invalid branch names'}                        | ${['invalid']}            | ${[branches.invalid.name]}
    ${'returns only one invalid branch name when passed a non-unique set of invalid branch names'} | ${['invalid', 'invalid']} | ${[branches.invalid.name]}
    ${'returns invalid branch names when passed a mix of valid and invalid branch names'}          | ${['invalid', 'valid']}   | ${[branches.invalid.name]}
  `('$title', async ({ input, output }) => {
    const response = await getInvalidBranches({
      branches: getBranchesValues(input, 'name'),
      projectId,
    });
    expect(response).toStrictEqual(output);
  });
});

describe('invalidVulnerabilitiesAllowed', () => {
  it.each`
    rules                                    | expectedResult
    ${null}                                  | ${false}
    ${[]}                                    | ${false}
    ${[{}]}                                  | ${false}
    ${[{ vulnerabilities_allowed: 0 }]}      | ${false}
    ${[{ vulnerabilities_allowed: 'test' }]} | ${true}
    ${[{ vulnerabilities_allowed: 1.1 }]}    | ${true}
    ${[{ vulnerabilities_allowed: -1 }]}     | ${true}
    ${[{ scanners: [] }]}                    | ${false}
  `('returns $expectedResult when rules are set to $rules', ({ rules, expectedResult }) => {
    expect(invalidVulnerabilitiesAllowed(rules)).toBe(expectedResult);
  });
});

describe('invalidVulnerabilityStates', () => {
  const newlyDetectedStates = Object.keys(APPROVAL_VULNERABILITY_STATES[NEWLY_DETECTED]);
  const previouslyExistingStates = Object.keys(APPROVAL_VULNERABILITY_STATES[PREVIOUSLY_EXISTING]);

  it.each`
    rules                                                                                             | expectedResult
    ${null}                                                                                           | ${false}
    ${[]}                                                                                             | ${false}
    ${[{}]}                                                                                           | ${false}
    ${[{ vulnerability_states: [] }]}                                                                 | ${false}
    ${[{ vulnerability_states: newlyDetectedStates }]}                                                | ${false}
    ${[{ vulnerability_states: previouslyExistingStates }]}                                           | ${false}
    ${[{ vulnerability_states: VULNERABILITY_STATE_KEYS }]}                                           | ${false}
    ${[{ vulnerability_states: newlyDetectedStates }, { vulnerability_states: newlyDetectedStates }]} | ${false}
    ${[{ vulnerability_states: [newlyDetectedStates[0], newlyDetectedStates[0]] }]}                   | ${true}
    ${[{ vulnerability_states: ['invalid'] }]}                                                        | ${true}
    ${[{ vulnerability_states: [...newlyDetectedStates, 'invalid'] }]}                                | ${true}
    ${[{ vulnerability_states: [...previouslyExistingStates, 'invalid'] }]}                           | ${true}
  `('returns $expectedResult with $rules', ({ rules, expectedResult }) => {
    expect(invalidVulnerabilityStates(rules)).toStrictEqual(expectedResult);
  });

  describe('invalidBranchType', () => {
    it.each`
      rules                                                                                 | expectedResult
      ${null}                                                                               | ${false}
      ${[]}                                                                                 | ${false}
      ${''}                                                                                 | ${false}
      ${[{}]}                                                                               | ${false}
      ${[{ branches: [] }]}                                                                 | ${false}
      ${[{ branch_type: 'protected' }, { branch_type: 'default' }]}                         | ${false}
      ${[{ branch_type: 'invalid' }]}                                                       | ${true}
      ${[{ branch_type: 'protected' }, { branch_type: 'default' }, { branch_type: 'all' }]} | ${true}
    `('returns $expectedResult with $rules', ({ rules, expectedResult }) => {
      expect(invalidBranchType(rules)).toBe(expectedResult);
    });
  });
});

describe('invalidVulnerabilityAge', () => {
  const validStates = { vulnerability_states: ['detected'] };
  const validAge = {
    vulnerability_age: { operator: GREATER_THAN_OPERATOR, value: 1, interval: AGE_DAY },
  };

  it.each`
    rules                                                                                                                         | expectedResult
    ${null}                                                                                                                       | ${false}
    ${[]}                                                                                                                         | ${false}
    ${[{}]}                                                                                                                       | ${false}
    ${[{ ...validStates, ...validAge }]}                                                                                          | ${false}
    ${[{ vulnerability_states: ['new_needs_triage', 'detected'], ...validAge }]}                                                  | ${false}
    ${[{ vulnerability_states: ['new_needs_triage'], ...validAge }]}                                                              | ${true}
    ${[{ vulnerability_states: [], ...validAge }]}                                                                                | ${true}
    ${[{ ...validAge }]}                                                                                                          | ${true}
    ${[{ ...validStates, vulnerability_age: {} }]}                                                                                | ${true}
    ${[{ ...validStates, vulnerability_age: { operator: ANY_OPERATOR } }]}                                                        | ${true}
    ${[{ ...validStates, vulnerability_age: { value: 1 } }]}                                                                      | ${true}
    ${[{ ...validStates, vulnerability_age: { interval: AGE_DAY } }]}                                                             | ${true}
    ${[{ ...validStates, vulnerability_age: { operator: 'invalid', value: 1, interval: AGE_DAY } }]}                              | ${true}
    ${[{ ...validStates, vulnerability_age: { operator: GREATER_THAN_OPERATOR, value: -1, interval: AGE_DAY } }]}                 | ${true}
    ${[{ ...validStates, vulnerability_age: { operator: GREATER_THAN_OPERATOR, value: 'invalid', interval: AGE_DAY } }]}          | ${true}
    ${[{ ...validStates, vulnerability_age: { operator: GREATER_THAN_OPERATOR, value: 1, interval: 'invalid' } }]}                | ${true}
    ${[{ ...validStates, vulnerability_age: { operator: GREATER_THAN_OPERATOR, value: 1, interval: AGE_DAY, invalidKey: 'a' } }]} | ${true}
  `('returns $expectedResult with $rules', ({ rules, expectedResult }) => {
    expect(invalidVulnerabilityAge(rules)).toStrictEqual(expectedResult);
  });
});

describe('humanizeInvalidBranchesError', () => {
  it('returns message without any branch name for an empty array', () => {
    expect(humanizeInvalidBranchesError([])).toEqual(
      'The following branches do not exist on this development project: . Please review all protected branches to ensure the values are accurate before updating this policy.',
    );
  });

  it('returns message with a single branch name for an array with single element', () => {
    expect(humanizeInvalidBranchesError(['main'])).toEqual(
      'The following branches do not exist on this development project: main. Please review all protected branches to ensure the values are accurate before updating this policy.',
    );
  });

  it('returns message with multiple branch names for array with multiple elements', () => {
    expect(humanizeInvalidBranchesError(['main', 'protected', 'master'])).toEqual(
      'The following branches do not exist on this development project: main, protected and master. Please review all protected branches to ensure the values are accurate before updating this policy.',
    );
  });
});

describe('invalidVulnerabilityAttributes', () => {
  it.each`
    rules                                                                                                            | expectedResult
    ${null}                                                                                                          | ${false}
    ${[]}                                                                                                            | ${false}
    ${[{}]}                                                                                                          | ${false}
    ${[{ vulnerability_attributes: {} }]}                                                                            | ${false}
    ${[{ vulnerability_attributes: { false_positive: true } }]}                                                      | ${false}
    ${[{ vulnerability_attributes: { fix_available: false } }]}                                                      | ${false}
    ${[{ vulnerability_attributes: { false_positive: true, fix_available: false } }]}                                | ${false}
    ${[{ vulnerability_attributes: 'invalid' }]}                                                                     | ${true}
    ${[{ vulnerability_attributes: { invalid: true } }]}                                                             | ${true}
    ${[{ vulnerability_attributes: { fix_available: true, false_positive: 'invalid' } }]}                            | ${true}
    ${[{ vulnerability_attributes: { false_positive: 1 } }]}                                                         | ${true}
    ${[{ vulnerability_attributes: { epss_score: { operator: 'greater_than', value: 1 } } }]}                        | ${false}
    ${[{ vulnerability_attributes: { epss_score: { operator: 'greater_than', value: 1 }, known_exploited: true } }]} | ${false}
    ${[{ vulnerability_attributes: { epss_score: 'string', known_exploited: true } }]}                               | ${true}
    ${[{ vulnerability_attributes: { false_positive: [] } }]}                                                        | ${true}
    ${[{ vulnerability_attributes: { false_positive: {} } }]}                                                        | ${true}
    ${[{ vulnerability_attributes: { fix_available: [] } }]}                                                         | ${true}
    ${[{ vulnerability_attributes: { fix_available: {} } }]}                                                         | ${true}
  `('returns $expectedResult', ({ rules, expectedResult }) => {
    expect(invalidVulnerabilityAttributes(rules)).toStrictEqual(expectedResult);
  });

  describe('licenseScanBuildRule', () => {
    it('creates license rule', () => {
      expect(licenseScanBuildRule()).toEqual(
        expect.objectContaining({ [MATCH_ON_INCLUSION_LICENSE]: true }),
      );
    });

    it('creates license rule with allow/deny list', () => {
      expect(licenseScanBuildRule()).toEqual(
        expect.objectContaining({ licenses: { [ALLOWED]: [] } }),
      );
    });
  });

  describe('malware helpers', () => {
    describe('isMaliciousScanner', () => {
      it.each`
        scanner                                                 | expected
        ${{ type: 'dependency_scanning', is_malicious: true }}  | ${true}
        ${{ type: 'dependency_scanning', is_malicious: false }} | ${false}
        ${{ type: 'dependency_scanning' }}                      | ${false}
        ${'dependency_scanning'}                                | ${false}
        ${null}                                                 | ${false}
      `('returns $expected for $scanner', ({ scanner, expected }) => {
        expect(isMaliciousScanner(scanner)).toBe(expected);
      });
    });

    describe('isMalwareEligibleScanner', () => {
      it.each`
        scanner                            | expected
        ${{ type: 'dependency_scanning' }} | ${true}
        ${{ type: 'container_scanning' }}  | ${true}
        ${'container_scanning'}            | ${true}
        ${{ type: 'sast' }}                | ${false}
        ${'sast'}                          | ${false}
      `('returns $expected for $scanner', ({ scanner, expected }) => {
        expect(isMalwareEligibleScanner(scanner)).toBe(expected);
      });
    });

    const rulesWith = (scanners) => [{ type: 'scan_finding', scanners }];

    describe('hasMalwareEligibleScanner', () => {
      it('is true when any rule has a dependency/container scanner', () => {
        expect(hasMalwareEligibleScanner(rulesWith([{ type: 'dependency_scanning' }]))).toBe(true);
      });

      it('is false for non-eligible scanners and empty input', () => {
        expect(hasMalwareEligibleScanner(rulesWith([{ type: 'sast' }]))).toBe(false);
        expect(hasMalwareEligibleScanner([])).toBe(false);
      });
    });

    describe('hasMalwareBlockingEnabled', () => {
      it('is true when any scanner enables is_malicious', () => {
        expect(
          hasMalwareBlockingEnabled(
            rulesWith([{ type: 'dependency_scanning', is_malicious: true }]),
          ),
        ).toBe(true);
      });

      it('is false when no scanner enables is_malicious', () => {
        expect(hasMalwareBlockingEnabled(rulesWith([{ type: 'dependency_scanning' }]))).toBe(false);
        expect(hasMalwareBlockingEnabled([])).toBe(false);
      });
    });
  });
});
