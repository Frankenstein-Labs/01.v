import {
  addDefaultVariablesToManifest,
  addDefaultVariablesToPolicy,
  buildScannerAction,
  hasUniqueScans,
  hasOnlyAllowedScans,
  hasSimpleScans,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/actions';
import {
  REPORT_TYPE_DAST,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_SECRET_DETECTION,
  REPORT_TYPE_API_FUZZING,
} from '~/vue_shared/security_reports/constants';
import {
  mockCustomScanExecutionManifest,
  mockCustomScanExecutionWithDefaultVariablesManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

const actionId = 'action_0';
jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn().mockReturnValue(actionId),
}));

describe('buildScannerAction', () => {
  describe('DAST', () => {
    it('returns a DAST scanner action with empty profiles', () => {
      expect(buildScannerAction({ scanner: REPORT_TYPE_DAST })).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: '',
        scanner_profile: '',
        id: actionId,
      });
    });

    it('returns a DAST scanner action with filled profiles', () => {
      const siteProfile = 'test_site_profile';
      const scannerProfile = 'test_scanner_profile';

      expect(
        buildScannerAction({ scanner: REPORT_TYPE_DAST, siteProfile, scannerProfile }),
      ).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: siteProfile,
        scanner_profile: scannerProfile,
        id: actionId,
      });
    });
  });

  describe('non-DAST', () => {
    it('returns a non-DAST scanner action', () => {
      const scanner = 'sast';
      expect(buildScannerAction({ scanner })).toEqual({
        scan: scanner,
        id: actionId,
      });
    });
  });

  describe('optimized scanning', () => {
    it('adds template property when isOptimized is true', () => {
      expect(buildScannerAction({ scanner: 'sast', isOptimized: true })).toEqual({
        scan: 'sast',
        id: 'action_0',
        template: 'latest',
      });
    });

    it('uses v2 as the default template for dependency_scanning when isOptimized is true', () => {
      expect(
        buildScannerAction({ scanner: REPORT_TYPE_DEPENDENCY_SCANNING, isOptimized: true }),
      ).toEqual({
        scan: REPORT_TYPE_DEPENDENCY_SCANNING,
        id: 'action_0',
        template: 'v2',
      });
    });
  });
});

describe('addDefaultVariablesToPolicy', () => {
  const buildPayload = (scan, variables = undefined) => {
    return variables ? { actions: [{ scan, variables }] } : { actions: [{ scan }] };
  };

  it.each`
    policy                                                                                                   | expected
    ${buildPayload(REPORT_TYPE_SAST)}                                                                        | ${buildPayload(REPORT_TYPE_SAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}
    ${buildPayload(REPORT_TYPE_SAST_IAC)}                                                                    | ${buildPayload(REPORT_TYPE_SAST_IAC, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}
    ${buildPayload(REPORT_TYPE_SECRET_DETECTION)}                                                            | ${buildPayload(REPORT_TYPE_SECRET_DETECTION, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}
    ${buildPayload(REPORT_TYPE_DAST)}                                                                        | ${buildPayload(REPORT_TYPE_DAST)}
    ${buildPayload(REPORT_TYPE_DAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}                        | ${buildPayload(REPORT_TYPE_DAST)}
    ${buildPayload(REPORT_TYPE_API_FUZZING)}                                                                 | ${buildPayload(REPORT_TYPE_API_FUZZING)}
    ${buildPayload(REPORT_TYPE_API_FUZZING, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}                 | ${buildPayload(REPORT_TYPE_API_FUZZING)}
    ${buildPayload(REPORT_TYPE_API_FUZZING, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false', OTHER: 'value' })} | ${buildPayload(REPORT_TYPE_API_FUZZING, { OTHER: 'value' })}
    ${buildPayload(REPORT_TYPE_SAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'true' })}                         | ${buildPayload(REPORT_TYPE_SAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'true' })}
    ${buildPayload(REPORT_TYPE_SECRET_DETECTION, { SECURE_ENABLE_LOCAL_CONFIGURATION: undefined })}          | ${buildPayload(REPORT_TYPE_SECRET_DETECTION, { SECURE_ENABLE_LOCAL_CONFIGURATION: undefined })}
  `('adds default variable to a policy with specific scanners', ({ policy, expected }) => {
    expect(addDefaultVariablesToPolicy({ policy })).toEqual(expected);
  });
});

describe('addDefaultVariablesToManifest', () => {
  it('adds default variable to a policy manifest with specific scanners', () => {
    expect(
      addDefaultVariablesToManifest({
        manifest: mockCustomScanExecutionManifest,
      }),
    ).toBe(mockCustomScanExecutionWithDefaultVariablesManifest);
  });
});

describe('hasUniqueScans', () => {
  it('returns true when all actions have unique scan values', () => {
    const actions = [{ scan: 'sast_iac' }, { scan: 'sast' }, { scan: 'secret_detection' }];

    expect(hasUniqueScans(actions)).toBe(true);
  });

  it('returns false when actions contain duplicate scan values', () => {
    const actions = [
      { scan: 'secret_detection' },
      { scan: 'sast' },
      { scan: 'secret_detection' }, // Duplicate scan value
    ];

    expect(hasUniqueScans(actions)).toBe(false);
  });

  it('returns true for an empty actions array', () => {
    expect(hasUniqueScans([])).toBe(true);
  });

  it('handles actions with missing scan property', () => {
    const actions = [
      { scan: 'secret_detection' },
      { otherProp: 'value' }, // Missing scan property
      { scan: 'sast' },
    ];

    // This test assumes that actions with missing scan properties are considered unique
    // Adjust the expectation based on the actual intended behavior
    expect(hasUniqueScans(actions)).toBe(true);
  });
});

describe('hasOnlyAllowedScans', () => {
  it('returns true when no actions have DAST scan type', () => {
    const actions = [
      { scan: 'sast' },
      { scan: 'secret_detection' },
      { scan: 'container_scanning' },
    ];

    expect(hasOnlyAllowedScans(actions)).toBe(true);
  });

  it('returns false when at least one action has DAST scan type', () => {
    const actions = [{ scan: 'sast' }, { scan: REPORT_TYPE_DAST }, { scan: 'secret_detection' }];

    expect(hasOnlyAllowedScans(actions)).toBe(false);
  });

  it('returns true for an empty actions array', () => {
    expect(hasOnlyAllowedScans([])).toBe(true);
  });
});

describe('hasSimpleScans', () => {
  it('returns true when all actions have only template: latest besides id and scan', () => {
    const actions = [{ id: 1, scan: 'sast', template: 'latest' }];

    expect(hasSimpleScans(actions)).toBe(true);
  });

  it('returns true when dependency_scanning action uses the default template: v2', () => {
    const actions = [{ id: 1, scan: REPORT_TYPE_DEPENDENCY_SCANNING, template: 'v2' }];

    expect(hasSimpleScans(actions)).toBe(true);
  });

  it('returns false when dependency_scanning action uses template: latest', () => {
    const actions = [{ id: 1, scan: REPORT_TYPE_DEPENDENCY_SCANNING, template: 'latest' }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns false when any action has additional properties', () => {
    const actions = [{ id: 1, scan: REPORT_TYPE_DAST, template: 'latest', runners: ['value'] }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns false when any action has different template value', () => {
    const actions = [{ id: 1, scan: 'secret_detection', template: 'default' }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns false when any action is missing template property', () => {
    const actions = [{ id: 1, scan: 'sast' }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns true for an empty actions array', () => {
    expect(hasSimpleScans([])).toBe(true);
  });
});
