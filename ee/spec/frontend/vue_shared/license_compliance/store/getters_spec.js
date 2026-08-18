import * as getters from 'ee/vue_shared/license_compliance/store/getters';
import createState from 'ee/vue_shared/license_compliance/store/state';
import { LICENSE_APPROVAL_STATUS } from 'ee/vue_shared/license_compliance/constants';

import { licenseReport as licenseReportMock } from '../mock_data';

describe('getters', () => {
  let state;

  describe('isLoading', () => {
    it('is true if `isLoadingManagedLicenses` is true OR `isLoadingLicenseReport` is true', () => {
      state = createState();
      state.isLoadingManagedLicenses = true;
      state.isLoadingLicenseReport = true;

      expect(getters.isLoading(state)).toBe(true);
      state.isLoadingManagedLicenses = false;
      state.isLoadingLicenseReport = true;

      expect(getters.isLoading(state)).toBe(true);
      state.isLoadingManagedLicenses = true;
      state.isLoadingLicenseReport = false;

      expect(getters.isLoading(state)).toBe(true);
      state.isLoadingManagedLicenses = false;
      state.isLoadingLicenseReport = false;

      expect(getters.isLoading(state)).toBe(false);
    });
  });

  describe('licenseReport', () => {
    it('should return the new licenses from the state', () => {
      const newLicenses = { test: 'foo' };
      state = { ...createState(), newLicenses };

      expect(getters.licenseReport(state)).toBe(newLicenses);
    });
  });

  describe('licenseReportGroups', () => {
    it('returns an array of objects containing information about the group and licenses', () => {
      const licensesSuccess = [
        { status: 'success', value: 'foo' },
        { status: 'success', value: 'bar' },
      ];
      const licensesNeutral = [
        { status: 'neutral', value: 'foo' },
        { status: 'neutral', value: 'bar' },
      ];
      const licensesFailed = [
        { status: 'failed', value: 'foo' },
        { status: 'failed', value: 'bar' },
      ];
      const newLicenses = [...licensesSuccess, ...licensesNeutral, ...licensesFailed];

      expect(getters.licenseReportGroups({ newLicenses })).toEqual([
        {
          name: 'Denied',
          description: `Out-of-compliance with this project's policies and should be removed`,
          status: 'failed',
          licenses: licensesFailed,
        },
        {
          name: 'Uncategorized',
          description: 'No policy matches this license',
          status: 'neutral',
          licenses: licensesNeutral,
        },
        {
          name: 'Allowed',
          description: 'Acceptable for use in this project',
          status: 'success',
          licenses: licensesSuccess,
        },
      ]);
    });

    it.each(['failed', 'neutral', 'success'])(
      `filters report-groups that don't have the given status: %s`,
      (status) => {
        const newLicenses = [{ status }];

        expect(getters.licenseReportGroups({ newLicenses })).toEqual([
          expect.objectContaining({
            status,
            licenses: newLicenses,
          }),
        ]);
      },
    );
  });

  describe('licenseSummaryText', () => {
    beforeEach(() => {
      state = {
        ...createState(),
        loadLicenseReportError: null,
        newLicenses: ['foo'],
        existingLicenses: ['bar'],
      };
    });

    it('should be `Loading License compliance report` text if isLoading', () => {
      const mockGetters = {};
      mockGetters.isLoading = true;

      expect(getters.licenseSummaryText(state, mockGetters)).toBe(
        'Loading License compliance report',
      );
    });

    it('should be `Failed to load License compliance report` text if an error has happened', () => {
      const mockGetters = {};
      state.loadLicenseReportError = new Error('Test');

      expect(getters.licenseSummaryText(state, mockGetters)).toBe(
        'Failed to load License compliance report',
      );
    });

    it('should call summaryTextWithLicenseCheck if new license are detected and license-check approval group is enabled', () => {
      const mockGetters = {
        hasReportItems: true,
        summaryTextWithLicenseCheck: 'summary text with license check',
      };
      expect(
        getters.licenseSummaryText({ state, hasLicenseCheckApprovalRule: true }, mockGetters),
      ).toBe('summary text with license check');
    });

    it('should call summaryTextWithOutLicenseCheck if new license are detected and license-check approval group is disabled', () => {
      const mockGetters = {
        hasReportItems: true,
        summaryTextWithoutLicenseCheck: 'summary text without license check',
      };

      expect(
        getters.licenseSummaryText({ state, hasLicenseCheckApprovalRule: false }, mockGetters),
      ).toBe('summary text without license check');
    });

    it('should show "License compliance detected no licenses for the source branch only" if there are no existing licenses', () => {
      const mockGetters = {
        baseReportHasLicenses: false,
      };
      expect(getters.licenseSummaryText(state, mockGetters)).toBe(
        'License compliance detected no licenses for the source branch only',
      );
    });

    it('should show "License compliance detected no new licenses" if there are no new licenses, but existing licenses', () => {
      const mockGetters = {
        baseReportHasLicenses: true,
      };
      expect(getters.licenseSummaryText(state, mockGetters)).toBe(
        'License compliance detected no new licenses',
      );
    });
  });

  describe('summaryTextWithLicenseCheck', () => {
    describe('when licenses exist on both the HEAD and the BASE', () => {
      beforeEach(() => {
        state = {
          ...createState(),
        };
      });

      describe('when denied licenses exist on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 new license and policy violation; approval required"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: true,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 new license and policy violation; approval required',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return License compliance detected 2 new licenses and policy violations; approval required', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: true,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 new licenses and policy violations; approval required',
            );
          });
        });
      });

      describe('when denied licenses are not detected on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 new license"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: true,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 new license',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 new licenses"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: true,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 new licenses',
            );
          });
        });
      });
    });

    describe('when there are no licenses on the BASE', () => {
      beforeEach(() => {
        state = {
          ...createState(),
        };
      });

      describe('when denied licenses exist on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 license and policy violation for the source branch only; approval required"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: false,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 license and policy violation for the source branch only; approval required',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 licenses and policy violations for the source branch only; approval required"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: false,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 licenses and policy violations for the source branch only; approval required',
            );
          });
        });
      });

      describe('when denied licenses are not detected on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 license for the source branch only"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: false,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 license for the source branch only',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 licenses for the source branch only"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: false,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 licenses for the source branch only',
            );
          });
        });
      });
    });
  });

  describe('summaryTextWithoutLicenseCheck', () => {
    describe('when licenses exist on both the HEAD and the BASE', () => {
      beforeEach(() => {
        state = {
          ...createState(),
        };
      });

      describe('when denied licenses exist on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 new license and policy violation"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: true,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 new license and policy violation',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 new licenses and policy violations"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: true,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 new licenses and policy violations',
            );
          });
        });
      });

      describe('when denied licenses are not detected on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 new license"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: true,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 new license',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 new licenses"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: true,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 new licenses',
            );
          });
        });
      });
    });

    describe('when there are no licenses on the BASE', () => {
      beforeEach(() => {
        state = {
          ...createState(),
        };
      });

      describe('when denied licenses exist on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 license and policy violation"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: false,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 license and policy violation',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 licenses and policy violations"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: true,
              baseReportHasLicenses: false,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 licenses and policy violations',
            );
          });
        });
      });

      describe('when denied licenses are not detected on the HEAD', () => {
        describe('when a single license is detected', () => {
          it('should return "License compliance detected 1 license"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: false,
              licenseReportLength: 1,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 1 license',
            );
          });
        });

        describe('when multiple licenses are detected', () => {
          it('should return "License compliance detected 2 licenses"', () => {
            const mockGetters = {
              reportContainsDeniedLicense: false,
              baseReportHasLicenses: false,
              licenseReportLength: 2,
            };

            expect(getters.summaryTextWithoutLicenseCheck(state, mockGetters)).toBe(
              'License compliance detected 2 licenses',
            );
          });
        });
      });
    });
  });

  describe('reportContainsDeniedLicense', () => {
    it('should be false if the report does not contain denied licenses', () => {
      const mockGetters = {
        licenseReport: [licenseReportMock[0], licenseReportMock[0]],
      };

      expect(getters.reportContainsDeniedLicense(state, mockGetters)).toBe(false);
    });

    it('should be true if the report contains denied licenses', () => {
      const mockGetters = {
        licenseReport: [
          licenseReportMock[0],
          { ...licenseReportMock[0], approvalStatus: LICENSE_APPROVAL_STATUS.DENIED },
        ],
      };

      expect(getters.reportContainsDeniedLicense(state, mockGetters)).toBe(true);
    });
  });
});
