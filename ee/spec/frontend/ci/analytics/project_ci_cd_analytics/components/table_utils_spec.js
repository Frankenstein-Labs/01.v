import {
  numericField,
  durationField,
} from 'ee/ci/analytics/project_ci_cd_analytics/components/table_utils';

describe('table_utils', () => {
  describe('numericField', () => {
    let field;

    beforeEach(() => {
      field = numericField();
    });

    it('returns an object with correct styling classes', () => {
      expect(field.thClass).toBe('gl-text-right');
      expect(field.tdClass).toBe('gl-text-right');
      expect(field.thAlignRight).toBe(true);
    });

    it('sets sortable to true', () => {
      expect(field.sortable).toBe(true);
    });

    it('calls formatNumber with correct options', () => {
      expect(field.formatter(1111.45)).toBe('1,111');
      expect(field.formatter(1111.99)).toBe('1,112');
    });

    it.each([null, undefined])("renders '-' for %p", (value) => {
      expect(field.formatter(value)).toBe('-');
    });
  });

  describe('durationField', () => {
    let field;

    beforeEach(() => {
      field = durationField();
    });

    it('returns an object with correct styling classes', () => {
      expect(field.thClass).toBe('gl-text-right');
      expect(field.tdClass).toBe('gl-text-right');
      expect(field.thAlignRight).toBe(true);
    });

    it('sets sortable to true', () => {
      expect(field.sortable).toBe(true);
    });

    it('calls formatNumber with correct options', () => {
      expect(field.formatter(60)).toBe('1m');
      expect(field.formatter(3600)).toBe('1h');
      expect(field.formatter(3600 * 24 * 7)).toBe('1w');
    });
  });
});
