import { schemaNodeValidator, schemaEdgeValidator } from 'ee/orbit/api/schema_types';

describe('schema_types validators', () => {
  describe('schemaNodeValidator', () => {
    it('returns true for valid node', () => {
      expect(schemaNodeValidator({ name: 'User', domain: 'core' })).toBe(true);
    });

    it('returns false when name is missing', () => {
      expect(schemaNodeValidator({ domain: 'core' })).toBe(false);
    });

    it('returns false when domain is missing', () => {
      expect(schemaNodeValidator({ name: 'User' })).toBe(false);
    });

    it('returns false for null', () => {
      expect(schemaNodeValidator(null)).toBe(false);
    });

    it('returns false for undefined', () => {
      expect(schemaNodeValidator(undefined)).toBe(false);
    });
  });

  describe('schemaEdgeValidator', () => {
    it('returns true for valid edge', () => {
      expect(schemaEdgeValidator({ name: 'AUTHORED' })).toBe(true);
    });

    it('returns false when name is missing', () => {
      expect(schemaEdgeValidator({})).toBe(false);
    });

    it('returns false for null', () => {
      expect(schemaEdgeValidator(null)).toBe(false);
    });
  });
});
