import {
  highlightsFromReport,
  transformToEnabledScans,
  updateFindingState,
} from 'ee/vue_merge_request_widget/widgets/security_reports/utils';

describe('MR Widget Security Reports Utils', () => {
  describe('highlightsFromReport', () => {
    it('should compute the highlights properly', () => {
      expect(
        highlightsFromReport({
          full: {
            added: [
              { severity: 'high' },
              { severity: 'high' },
              { severity: 'critical' },
              { severity: 'critical' },
              { severity: 'critical' },
              { severity: 'medium' },
              { severity: 'low' },
              { severity: 'info' },
              { severity: 'unknown' },
            ],
          },
        }),
      ).toEqual({
        critical: 3,
        high: 2,
        other: 4,
      });
    });

    it('should sum full and partial results', () => {
      expect(
        highlightsFromReport({
          full: { added: [{ severity: 'high' }, { severity: 'critical' }, { severity: 'medium' }] },
          partial: { added: [{ severity: 'high' }, { severity: 'critical' }] },
        }),
      ).toEqual({
        critical: 2,
        high: 2,
        other: 1,
      });
    });

    it('should receive an object and modify it', () => {
      const highlights = {
        critical: 1,
        high: 0,
        other: 5,
      };

      expect(
        highlightsFromReport(
          { full: { added: [{ severity: 'high' }, { severity: 'critical' }] } },
          highlights,
        ),
      ).toEqual({
        critical: 2,
        high: 1,
        other: 5,
      });
    });
  });

  describe('transformToEnabledScans', () => {
    it.each`
      scans
      ${{ enabledSecurityScans: { sast: false, dast: false, secretDetection: false } }}
      ${{ enabledSecurityScans: null }}
      ${{ enabledSecurityScans: undefined }}
      ${{}}
    `('should return empty array when no scans enabled: $scans', ({ scans }) => {
      expect(transformToEnabledScans(scans)).toEqual([]);
    });

    it('should ignore unknown scan types', () => {
      const scans = {
        enabledSecurityScans: { sast: true, unknownType: true, anotherUnknown: true },
      };
      expect(transformToEnabledScans(scans)).toEqual([{ reportType: 'SAST', scanMode: 'FULL' }]);
    });

    it('should ignore non-report type fields like "ready"', () => {
      const scans = {
        enabledSecurityScans: {
          ready: true,
          sast: true,
        },
      };
      expect(transformToEnabledScans(scans)).toEqual([{ reportType: 'SAST', scanMode: 'FULL' }]);
    });

    it.each`
      value
      ${'enabled'}
      ${1}
      ${{}}
      ${[]}
    `('should ignore non-boolean value: $value', ({ value }) => {
      const scans = { enabledSecurityScans: { sast: true, dast: value } };
      expect(transformToEnabledScans(scans)).toEqual([{ reportType: 'SAST', scanMode: 'FULL' }]);
    });

    describe('scan modes', () => {
      it('should transform both full and partial scans', () => {
        const scans = {
          enabledSecurityScans: {
            sast: true,
            dast: true,
          },
          enabledPartialSecurityScans: {
            sast: true,
            secretDetection: true,
          },
        };

        const result = transformToEnabledScans(scans);

        expect(result).toEqual([
          { reportType: 'SAST', scanMode: 'FULL' },
          { reportType: 'DAST', scanMode: 'FULL' },
          { reportType: 'SAST', scanMode: 'PARTIAL' },
          { reportType: 'SECRET_DETECTION', scanMode: 'PARTIAL' },
        ]);
      });

      describe.each`
        scanMode     | scanField
        ${'FULL'}    | ${'enabledSecurityScans'}
        ${'PARTIAL'} | ${'enabledPartialSecurityScans'}
      `('$scanMode scans', ({ scanMode, scanField }) => {
        it('should transform multiple enabled security scans', () => {
          const scans = {
            [scanField]: {
              sast: true,
              dast: false,
              secretDetection: true,
            },
          };

          const result = transformToEnabledScans(scans);

          expect(result).toEqual([
            { reportType: 'SAST', scanMode },
            { reportType: 'SECRET_DETECTION', scanMode },
          ]);
        });

        it.each`
          scanType                  | expectedReportType
          ${'sast'}                 | ${'SAST'}
          ${'dast'}                 | ${'DAST'}
          ${'secretDetection'}      | ${'SECRET_DETECTION'}
          ${'apiFuzzing'}           | ${'API_FUZZING'}
          ${'coverageFuzzing'}      | ${'COVERAGE_FUZZING'}
          ${'dependencyScanning'}   | ${'DEPENDENCY_SCANNING'}
          ${'containerScanning'}    | ${'CONTAINER_SCANNING'}
          ${'clusterImageScanning'} | ${'CLUSTER_IMAGE_SCANNING'}
        `(
          'should transform $scanType to $expectedReportType',
          ({ scanType, expectedReportType }) => {
            const scans = { [scanField]: { [scanType]: true } };

            expect(transformToEnabledScans(scans)).toEqual([
              { reportType: expectedReportType, scanMode },
            ]);
          },
        );
      });
    });
  });

  describe('updateFindingState', () => {
    it.each`
      scanMode
      ${'full'}
      ${'partial'}
    `('updates the state of a finding in $scanMode reports', ({ scanMode }) => {
      const finding = { uuid: 'abc-123', state: 'DETECTED' };
      const reportsByScanType = {
        full: {},
        partial: {},
        [scanMode]: { SAST: { findings: [finding] } },
      };

      updateFindingState(reportsByScanType, 'abc-123', 'dismissed');

      expect(finding.state).toBe('dismissed');
    });

    it('does not change other findings', () => {
      const finding1 = { uuid: 'abc-123', state: 'DETECTED' };
      const finding2 = { uuid: 'def-456', state: 'DETECTED' };
      const reportsByScanType = {
        full: { SAST: { findings: [finding1, finding2] } },
        partial: {},
      };

      updateFindingState(reportsByScanType, 'abc-123', 'dismissed');

      expect(finding1.state).toBe('dismissed');
      expect(finding2.state).toBe('DETECTED');
    });

    it('does nothing when uuid is not found', () => {
      const finding = { uuid: 'abc-123', state: 'DETECTED' };
      const reportsByScanType = {
        full: { SAST: { findings: [finding] } },
        partial: {},
      };

      updateFindingState(reportsByScanType, 'nonexistent', 'dismissed');

      expect(finding.state).toBe('DETECTED');
    });
  });
});
