import {
  isManagedAiFlag,
  isManualFlag,
  isScannerFp,
  hasActiveAiFpDetection,
  isAiDetectedAsFalsePositive,
  isPendingFpDetection,
  isFailedFpDetection,
  isCompletedFpDetection,
  isSastVrApplicable,
  eligibleSastVrVulnerabilities,
  isSastFpDetectionApplicable,
  eligibleSastFpVulnerabilities,
  isScaVrApplicable,
  fpConfidenceLabel,
  fpConfidenceTextClass,
} from 'ee/vulnerabilities/flag_helpers';
import { FLAG_STATUSES } from 'ee/vulnerabilities/constants';
import { SECURITY_REPORT_TYPE_ENUM_DEPENDENCY_SCANNING } from '~/vue_shared/security_reports/constants';

describe('Vulnerability flag helpers', () => {
  describe('isManagedAiFlag', () => {
    it.each`
      origin                                | expected
      ${'ai_sast_fp_detection'}             | ${true}
      ${'ai_secret_detection_fp_detection'} | ${true}
      ${'ai_something_else'}                | ${false}
      ${'ai_'}                              | ${false}
      ${'manual_user'}                      | ${false}
      ${'vet'}                              | ${false}
      ${''}                                 | ${false}
      ${undefined}                          | ${false}
    `('returns $expected for origin "$origin"', ({ origin, expected }) => {
      expect(isManagedAiFlag({ origin })).toBe(expected);
    });

    it('returns false for null/undefined flag', () => {
      expect(isManagedAiFlag(null)).toBe(false);
      expect(isManagedAiFlag(undefined)).toBe(false);
    });
  });

  describe('isManualFlag', () => {
    it.each`
      origin                    | expected
      ${'manual_user'}          | ${true}
      ${'manual_'}              | ${true}
      ${'ai_sast_fp_detection'} | ${false}
      ${'vet'}                  | ${false}
      ${''}                     | ${false}
      ${undefined}              | ${false}
    `('returns $expected for origin "$origin"', ({ origin, expected }) => {
      expect(isManualFlag({ origin })).toBe(expected);
    });

    it('returns false for null/undefined flag', () => {
      expect(isManualFlag(null)).toBe(false);
      expect(isManualFlag(undefined)).toBe(false);
    });
  });

  describe('isScannerFp', () => {
    it.each`
      origin                    | expected
      ${'vet'}                  | ${true}
      ${'gitleaks'}             | ${true}
      ${'gitlab-dast'}          | ${true}
      ${'ai_sast_fp_detection'} | ${false}
      ${'manual_user'}          | ${false}
    `('returns $expected for origin "$origin"', ({ origin, expected }) => {
      expect(isScannerFp({ origin })).toBe(expected);
    });

    it('returns true when there is no flag record', () => {
      expect(isScannerFp(null)).toBe(true);
      expect(isScannerFp(undefined)).toBe(true);
    });
  });

  describe('hasActiveAiFpDetection', () => {
    it.each`
      flag                                                                            | expected
      ${{ status: FLAG_STATUSES.IN_PROGRESS, origin: 'ai_sast_fp_detection' }}        | ${true}
      ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'ai_sast_fp_detection' }}     | ${true}
      ${{ status: FLAG_STATUSES.DETECTED_AS_NOT_FP, origin: 'ai_sast_fp_detection' }} | ${true}
      ${{ status: FLAG_STATUSES.FAILED, origin: 'ai_sast_fp_detection' }}             | ${true}
      ${{ status: FLAG_STATUSES.NOT_STARTED, origin: 'ai_sast_fp_detection' }}        | ${true}
      ${{ status: FLAG_STATUSES.DISMISSED, origin: 'ai_sast_fp_detection' }}          | ${false}
      ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'manual_user' }}              | ${false}
      ${{ status: FLAG_STATUSES.NOT_STARTED, origin: 'vet' }}                         | ${false}
      ${{ status: null, origin: 'ai_sast_fp_detection' }}                             | ${false}
      ${null}                                                                         | ${false}
      ${undefined}                                                                    | ${false}
    `('returns $expected for flag $flag', ({ flag, expected }) => {
      expect(hasActiveAiFpDetection(flag)).toBe(expected);
    });
  });

  describe('isAiDetectedAsFalsePositive', () => {
    it.each`
      flag                                                                            | expected
      ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'ai_sast_fp_detection' }}     | ${true}
      ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'manual_user' }}              | ${false}
      ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'vet' }}                      | ${false}
      ${{ status: FLAG_STATUSES.DETECTED_AS_NOT_FP, origin: 'ai_sast_fp_detection' }} | ${false}
      ${{ status: FLAG_STATUSES.IN_PROGRESS, origin: 'ai_sast_fp_detection' }}        | ${false}
      ${null}                                                                         | ${false}
      ${undefined}                                                                    | ${false}
    `('returns $expected for flag $flag', ({ flag, expected }) => {
      expect(isAiDetectedAsFalsePositive(flag)).toBe(expected);
    });
  });

  describe('isPendingFpDetection', () => {
    it.each`
      status                          | expected
      ${FLAG_STATUSES.NOT_STARTED}    | ${true}
      ${FLAG_STATUSES.IN_PROGRESS}    | ${true}
      ${FLAG_STATUSES.DETECTED_AS_FP} | ${false}
      ${FLAG_STATUSES.FAILED}         | ${false}
      ${FLAG_STATUSES.DISMISSED}      | ${false}
      ${undefined}                    | ${false}
    `('returns $expected for status $status', ({ status, expected }) => {
      expect(isPendingFpDetection({ status })).toBe(expected);
    });

    it('returns false for null/undefined flag', () => {
      expect(isPendingFpDetection(null)).toBe(false);
      expect(isPendingFpDetection(undefined)).toBe(false);
    });
  });

  describe('isFailedFpDetection', () => {
    it('returns true only for FAILED status', () => {
      expect(isFailedFpDetection({ status: FLAG_STATUSES.FAILED })).toBe(true);
      expect(isFailedFpDetection({ status: FLAG_STATUSES.IN_PROGRESS })).toBe(false);
      expect(isFailedFpDetection(null)).toBe(false);
      expect(isFailedFpDetection(undefined)).toBe(false);
    });
  });

  describe('isSastVrApplicable', () => {
    const baseVulnerability = {
      aiResolutionAvailable: true,
      duoSastVrWorkflowEnabled: true,
      latestFlag: null,
    };
    const baseContext = { duoAgentPlatformAvailable: true, agenticSastVrUi: true };

    it('returns true when all conditions are met', () => {
      expect(isSastVrApplicable({ vulnerability: baseVulnerability, ...baseContext })).toBe(true);
    });

    it.each`
      override                                                                                                       | expected
      ${{ context: { agenticSastVrUi: false } }}                                                                     | ${false}
      ${{ context: { duoAgentPlatformAvailable: false } }}                                                           | ${false}
      ${{ vulnerability: { aiResolutionAvailable: false } }}                                                         | ${false}
      ${{ vulnerability: { duoSastVrWorkflowEnabled: false } }}                                                      | ${false}
      ${{ vulnerability: { latestFlag: { status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'ai_sast_fp_detection' } } }} | ${false}
      ${{ vulnerability: { latestFlag: { status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'manual_user' } } }}          | ${true}
    `('returns $expected when $override', ({ override, expected }) => {
      expect(
        isSastVrApplicable({
          vulnerability: { ...baseVulnerability, ...(override.vulnerability ?? {}) },
          ...baseContext,
          ...(override.context ?? {}),
        }),
      ).toBe(expected);
    });

    it('returns false when vulnerability is null', () => {
      expect(isSastVrApplicable({ vulnerability: null, ...baseContext })).toBe(false);
    });
  });

  describe('eligibleSastVrVulnerabilities', () => {
    const eligible = {
      aiResolutionAvailable: true,
      duoSastVrWorkflowEnabled: true,
      latestFlag: null,
    };
    const ineligible = {
      aiResolutionAvailable: false,
      duoSastVrWorkflowEnabled: true,
      latestFlag: null,
    };
    const context = { duoAgentPlatformAvailable: true, agenticSastVrUi: true };

    it('returns only the vulnerabilities for which SAST VR applies', () => {
      expect(eligibleSastVrVulnerabilities([eligible, ineligible], context)).toEqual([eligible]);
    });

    it('returns an empty array when none are eligible', () => {
      expect(eligibleSastVrVulnerabilities([ineligible], context)).toEqual([]);
    });

    it('returns an empty array when the context disables SAST VR', () => {
      expect(
        eligibleSastVrVulnerabilities([eligible], { ...context, agenticSastVrUi: false }),
      ).toEqual([]);
    });
  });

  describe('isSastFpDetectionApplicable', () => {
    const baseVulnerability = {
      reportType: 'SAST',
      severity: 'CRITICAL',
      latestFlag: null,
    };
    const baseContext = { duoAgentPlatformAvailable: true, duoSastFpDetectionEnabled: true };

    it('returns true when all conditions are met', () => {
      expect(
        isSastFpDetectionApplicable({ vulnerability: baseVulnerability, ...baseContext }),
      ).toBe(true);
    });

    it.each`
      override                                                                                                       | expected
      ${{ context: { duoSastFpDetectionEnabled: false } }}                                                           | ${false}
      ${{ context: { duoAgentPlatformAvailable: false } }}                                                           | ${false}
      ${{ vulnerability: { reportType: 'DEPENDENCY_SCANNING' } }}                                                    | ${false}
      ${{ vulnerability: { severity: 'HIGH' } }}                                                                     | ${true}
      ${{ vulnerability: { severity: 'MEDIUM' } }}                                                                   | ${true}
      ${{ vulnerability: { severity: 'UNKNOWN' } }}                                                                  | ${true}
      ${{ vulnerability: { latestFlag: { status: FLAG_STATUSES.IN_PROGRESS, origin: 'ai_sast_fp_detection' } } }}    | ${false}
      ${{ vulnerability: { latestFlag: { status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'ai_sast_fp_detection' } } }} | ${false}
      ${{ vulnerability: { latestFlag: { status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'manual_user' } } }}          | ${true}
      ${{ vulnerability: { latestFlag: { status: FLAG_STATUSES.DISMISSED, origin: 'ai_sast_fp_detection' } } }}      | ${true}
    `('returns $expected when $override', ({ override, expected }) => {
      expect(
        isSastFpDetectionApplicable({
          vulnerability: { ...baseVulnerability, ...(override.vulnerability ?? {}) },
          ...baseContext,
          ...(override.context ?? {}),
        }),
      ).toBe(expected);
    });

    it('returns false when vulnerability is null', () => {
      expect(isSastFpDetectionApplicable({ vulnerability: null, ...baseContext })).toBe(false);
    });

    // The bulk API takes severity from the caller, so the report must not filter it out.
    it.each(['CRITICAL', 'critical', 'HIGH', 'high', 'MEDIUM', 'LOW', 'INFO', 'UNKNOWN'])(
      'applies regardless of the %s severity',
      (severity) => {
        expect(
          isSastFpDetectionApplicable({
            vulnerability: { ...baseVulnerability, severity },
            ...baseContext,
          }),
        ).toBe(true);
      },
    );
  });

  describe('eligibleSastFpVulnerabilities', () => {
    const eligible = { reportType: 'SAST', severity: 'CRITICAL', latestFlag: null };
    const ineligible = {
      reportType: 'DEPENDENCY_SCANNING',
      severity: 'CRITICAL',
      latestFlag: null,
    };
    const context = { duoAgentPlatformAvailable: true, duoSastFpDetectionEnabled: true };

    it('returns only the vulnerabilities for which SAST FP detection applies', () => {
      expect(eligibleSastFpVulnerabilities([eligible, ineligible], context)).toEqual([eligible]);
    });

    it('keeps SAST vulnerabilities below high severity', () => {
      const lowSeverity = { reportType: 'SAST', severity: 'LOW', latestFlag: null };

      expect(eligibleSastFpVulnerabilities([lowSeverity], context)).toEqual([lowSeverity]);
    });

    it('returns an empty array when none are eligible', () => {
      expect(eligibleSastFpVulnerabilities([ineligible], context)).toEqual([]);
    });

    it('returns an empty array when the project has FP detection disabled', () => {
      expect(
        eligibleSastFpVulnerabilities([eligible], { ...context, duoSastFpDetectionEnabled: false }),
      ).toEqual([]);
    });
  });

  describe('isScaVrApplicable', () => {
    it.each`
      reportType                                       | securityRemediationProfiles | expected
      ${SECURITY_REPORT_TYPE_ENUM_DEPENDENCY_SCANNING} | ${true}                     | ${true}
      ${SECURITY_REPORT_TYPE_ENUM_DEPENDENCY_SCANNING} | ${false}                    | ${false}
      ${'SAST'}                                        | ${true}                     | ${false}
      ${undefined}                                     | ${true}                     | ${false}
    `(
      'returns $expected for reportType $reportType with securityRemediationProfiles $securityRemediationProfiles',
      ({ reportType, securityRemediationProfiles, expected }) => {
        expect(
          isScaVrApplicable({ vulnerability: { reportType }, securityRemediationProfiles }),
        ).toBe(expected);
      },
    );

    it('returns false when vulnerability is null', () => {
      expect(isScaVrApplicable({ vulnerability: null, securityRemediationProfiles: true })).toBe(
        false,
      );
    });
  });

  describe('isCompletedFpDetection', () => {
    it.each`
      status                              | expected
      ${FLAG_STATUSES.DETECTED_AS_FP}     | ${true}
      ${FLAG_STATUSES.DETECTED_AS_NOT_FP} | ${true}
      ${FLAG_STATUSES.IN_PROGRESS}        | ${false}
      ${FLAG_STATUSES.FAILED}             | ${false}
      ${FLAG_STATUSES.DISMISSED}          | ${false}
      ${undefined}                        | ${false}
    `('returns $expected for status $status', ({ status, expected }) => {
      expect(isCompletedFpDetection({ status })).toBe(expected);
    });
  });

  describe('fpConfidenceLabel and fpConfidenceTextClass', () => {
    it.each`
      confidenceScore | label       | textClass
      ${0.9}          | ${'High'}   | ${'gl-text-success'}
      ${0.8}          | ${'High'}   | ${'gl-text-success'}
      ${0.7}          | ${'Medium'} | ${'gl-text-warning'}
      ${0.6}          | ${'Low'}    | ${'gl-text-danger'}
      ${0.12}         | ${'Low'}    | ${'gl-text-danger'}
      ${0.01}         | ${'Low'}    | ${'gl-text-danger'}
      ${0}            | ${'None'}   | ${'gl-text-subtle'}
    `('maps a $confidenceScore score to "$label"', ({ confidenceScore, label, textClass }) => {
      expect(fpConfidenceLabel({ confidenceScore })).toBe(label);
      expect(fpConfidenceTextClass({ confidenceScore })).toBe(textClass);
    });

    it('treats a missing score as "None"', () => {
      expect(fpConfidenceLabel(null)).toBe('None');
      expect(fpConfidenceTextClass(undefined)).toBe('gl-text-subtle');
    });
  });
});
