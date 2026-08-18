import {
  getVulnerabilityTotal,
  securityScannerOfProjectValidator,
  itemValidator,
  securityScannerOfGroupValidator,
} from 'ee/security_inventory/utils';

jest.mock('ee/security_inventory/utils', () => {
  const originalModule = jest.requireActual('ee/security_inventory/utils');
  return {
    ...originalModule,
    securityScannerOfProjectValidator: jest.fn(originalModule.securityScannerOfProjectValidator),
  };
});

describe('getVulnerabilityTotal', () => {
  it('should return 0 when no vulnerabilities are provided', () => {
    const result = getVulnerabilityTotal();
    expect(result).toBe(0);
  });

  it('should return the correct total when given specific vulnerability counts', () => {
    const vulnerabilityCounts = {
      critical: 3,
      high: 5,
      medium: 2,
      low: 1,
      info: 0,
      unknown: 4,
    };
    const result = getVulnerabilityTotal(vulnerabilityCounts);
    expect(result).toBe(15);
  });

  it('should handle missing fields by defaulting to 0', () => {
    const vulnerabilityCounts = {
      critical: 3,
      high: 2,
      medium: 1,
    };
    const result = getVulnerabilityTotal(vulnerabilityCounts);
    expect(result).toBe(6);
  });

  it('should return 0 when passed an empty object', () => {
    const result = getVulnerabilityTotal({});
    expect(result).toBe(0);
  });
});

describe('securityScannerOfGroupValidator', () => {
  const item = {
    analyzerType: 'DEPENDENCY_SCANNING',
    failure: 1,
    notConfigured: 3,
    success: 2,
    updatedAt: undefined,
  };

  describe('basic object validation', () => {
    it('returns false for non-object types', () => {
      expect(securityScannerOfGroupValidator(123)).toBe(false);
      expect(securityScannerOfGroupValidator('string')).toBe(false);
      expect(securityScannerOfGroupValidator([])).toBe(false);
      expect(securityScannerOfGroupValidator(null)).toBe(false);
      expect(securityScannerOfGroupValidator('')).toBe(false);
      expect(securityScannerOfGroupValidator({})).toBe(false);
    });
  });

  describe('props validation', () => {
    it.each`
      description                     | value                                | expected
      ${'analyzerType is a number'}   | ${{ ...item, analyzerType: 5 }}      | ${false}
      ${'analyzerType is undefined'}  | ${{ ...item, analyzerType: {} }}     | ${false}
      ${'analyzerType is a string'}   | ${{ ...item, analyzerType: 'SAST' }} | ${true}
      ${'analyzerType is a null'}     | ${{ ...item, analyzerType: null }}   | ${false}
      ${'failure is a number'}        | ${{ ...item, failure: 5 }}           | ${true}
      ${'failure is undefined'}       | ${{ ...item, failure: {} }}          | ${false}
      ${'failure is a string'}        | ${{ ...item, failure: '5' }}         | ${false}
      ${'failure is a null'}          | ${{ ...item, failure: null }}        | ${false}
      ${'notConfigured is a number'}  | ${{ ...item, notConfigured: 5 }}     | ${true}
      ${'notConfigured is undefined'} | ${{ ...item, notConfigured: {} }}    | ${false}
      ${'notConfigured is a string'}  | ${{ ...item, notConfigured: '5' }}   | ${false}
      ${'notConfigured is a null'}    | ${{ ...item, notConfigured: null }}  | ${false}
      ${'success is a number'}        | ${{ ...item, success: 5 }}           | ${true}
      ${'success is undefined'}       | ${{ ...item, success: {} }}          | ${false}
      ${'success is a string'}        | ${{ ...item, success: '5' }}         | ${false}
      ${'success is a null'}          | ${{ ...item, success: null }}        | ${false}
    `('$description', ({ value, expected }) => {
      const result = securityScannerOfGroupValidator(value);
      expect(result).toBe(expected);
    });
  });

  describe('complex scenarios', () => {
    it('returns false when any validation fails', () => {
      const invalidItems = [
        { analyzerType: 'SAST' },
        {
          analyzerType: 'SAST',
          notConfigured: 3,
          success: 2,
        },
        {
          failure: 1,
          notConfigured: 3,
          success: 2,
        },
        {
          analyzerType: 2,
          failure: 1,
          notConfigured: 3,
          success: 2,
        },
      ];
      invalidItems.forEach((invalidItem) => {
        expect(securityScannerOfGroupValidator(invalidItem)).toBe(false);
      });
    });

    it('allows additional properties', () => {
      const itemWithUnexpectedProps = {
        analyzerType: 'SAST',
        failure: 1,
        notConfigured: 3,
        success: 2,
        unexpectedProp: 'value',
      };
      expect(securityScannerOfGroupValidator(itemWithUnexpectedProps)).toBe(true);
    });
  });
});

describe('securityScannerOfProjectValidator', () => {
  describe('valid scenarios', () => {
    it('returns true for an array with minimal valid objects', () => {
      const validInput = [{ analyzerType: 'SAST' }];
      expect(securityScannerOfProjectValidator(validInput)).toBe(true);
    });

    it('returns true for an array with complete valid objects', () => {
      const validInput = [
        {
          analyzerType: 'SAST',
          status: 'SUCCESS',
          buildId: 'gid://git/path/123',
          lastCall: '2025-01-01T00:00:00Z',
          updatedAt: '2025-01-01T00:00:00Z',
        },
      ];
      expect(securityScannerOfProjectValidator(validInput)).toBe(true);
    });

    it('returns true for an array with multiple valid objects', () => {
      const validInput = [
        { analyzerType: 'SAST' },
        {
          analyzerType: 'DAST',
          status: 'FAILED',
          buildId: 'gid://git/path/123',
        },
      ];
      expect(securityScannerOfProjectValidator(validInput)).toBe(true);
    });

    it('handles objects with additional unexpected properties', () => {
      const inputWithExtraProps = [
        {
          analyzerType: 'SAST',
          unexpectedProp: 'value',
          status: 'SUCCESS',
        },
      ];
      expect(securityScannerOfProjectValidator(inputWithExtraProps)).toBe(true);
    });

    it('returns true for an empty array', () => {
      expect(securityScannerOfProjectValidator([])).toBe(true);
    });
  });

  describe('invalid scenarios', () => {
    it('returns false when object is missing analyzerType', () => {
      const invalidInput = [{ status: 'SUCCESS' }];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('returns false when analyzerType is not a string', () => {
      const invalidInput = [{ analyzerType: 123 }];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('returns false when status is not a string', () => {
      const invalidInput = [
        {
          analyzerType: 'SAST',
          status: 123,
        },
      ];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('returns false when buildId is not a string', () => {
      const invalidInput = [
        {
          analyzerType: 'SAST',
          buildId: 123,
        },
      ];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('returns false when lastCall is not a string', () => {
      const invalidInput = [
        {
          analyzerType: 'SAST',
          lastCall: 123,
        },
      ];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('returns false when updatedAt is not a string', () => {
      const invalidInput = [
        {
          analyzerType: 'SAST',
          updatedAt: 123,
        },
      ];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('returns false for non-object items', () => {
      const invalidInput = ['not an object', { analyzerType: 'SAST' }];
      expect(securityScannerOfProjectValidator(invalidInput)).toBe(false);
    });

    it('handles multiple objects with mixed validity', () => {
      const mixedInput = [{ analyzerType: 'SAST' }, { status: 'SUCCESS' }];
      expect(securityScannerOfProjectValidator(mixedInput)).toBe(false);
    });
  });
});

describe('itemValidator', () => {
  describe('basic object validation', () => {
    it('returns false for non-object types', () => {
      expect(itemValidator(123)).toBe(false);
      expect(itemValidator('string')).toBe(false);
      expect(itemValidator([])).toBe(false);
      expect(itemValidator(null)).toBe(false);
    });

    it('returns true for an empty object', () => {
      expect(itemValidator({})).toBe(true);
    });
  });

  describe('analyzerStatuses validation', () => {
    it('returns true when analyzerStatuses is a valid array', () => {
      const validAnalyzerStatuses = [{ analyzerType: 'SAST' }];
      securityScannerOfProjectValidator.mockReturnValue(true);
      const item = { analyzerStatuses: validAnalyzerStatuses };
      expect(itemValidator(item)).toBe(true);
    });

    it('returns false when analyzerStatuses is not an array', () => {
      const item = { analyzerStatuses: 'not an array' };
      expect(itemValidator(item)).toBe(false);
    });

    it('returns false when securityScannerOfProjectValidator fails', () => {
      const invalidAnalyzerStatuses = [{ invalid: 'object' }];
      securityScannerOfProjectValidator.mockReturnValue(false);
      const item = { analyzerStatuses: invalidAnalyzerStatuses };
      expect(itemValidator(item)).toBe(false);
    });
  });

  describe('path validation', () => {
    it('returns true when path is a string', () => {
      const item = { path: 'valid/path' };
      expect(itemValidator(item)).toBe(true);
    });

    it('returns false when path is not a string', () => {
      const invalidItems = [{ path: 123 }, { path: null }, { path: {} }];
      invalidItems.forEach((item) => {
        expect(itemValidator(item)).toBe(false);
      });
    });
  });

  describe('webUrl validation', () => {
    it('returns true when webUrl is a string', () => {
      const item = { webUrl: 'https://example.com' };
      expect(itemValidator(item)).toBe(true);
    });

    it('returns false when webUrl is not a string', () => {
      const invalidItems = [{ webUrl: 123 }, { webUrl: null }, { webUrl: {} }];
      invalidItems.forEach((item) => {
        expect(itemValidator(item)).toBe(false);
      });
    });
  });

  describe('complex scenarios', () => {
    it('returns true for an object with multiple valid properties', () => {
      const validItem = {
        path: 'valid/path',
        webUrl: 'https://example.com',
        analyzerStatuses: [{ analyzerType: 'SAST' }],
      };
      securityScannerOfProjectValidator.mockReturnValue(true);
      expect(itemValidator(validItem)).toBe(true);
    });

    it('returns false when any validation fails', () => {
      const invalidItems = [
        { path: 123, webUrl: 'https://example.com' },
        { path: 'valid/path', webUrl: 123 },
        {
          path: 'valid/path',
          webUrl: 'https://example.com',
          analyzerStatuses: [{ invalid: 'object' }],
        },
      ];
      invalidItems.forEach((item) => {
        if (item.analyzerStatuses) {
          securityScannerOfProjectValidator.mockReturnValue(false);
        }
        expect(itemValidator(item)).toBe(false);
      });
    });

    it('allows additional properties', () => {
      const itemWithUnexpectedProps = {
        path: 'valid/path',
        webUrl: 'https://example.com',
        unexpectedProp: 'value',
      };
      expect(itemValidator(itemWithUnexpectedProps)).toBe(true);
    });
  });
});
