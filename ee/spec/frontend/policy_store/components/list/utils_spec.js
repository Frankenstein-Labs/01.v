import {
  modeLabel,
  modeVariant,
  statusLabel,
  statusVariant,
  scopeLabel,
} from 'ee/policy_store/components/list/utils';

describe('policy store list utils', () => {
  describe('mode', () => {
    it.each`
      mode         | label        | variant
      ${'enforce'} | ${'Enforce'} | ${'danger'}
      ${'warn'}    | ${'Warn'}    | ${'warning'}
      ${'audit'}   | ${'Audit'}   | ${'neutral'}
    `('maps $mode to "$label" and the $variant variant', ({ mode, label, variant }) => {
      expect(modeLabel(mode)).toBe(label);
      expect(modeVariant(mode)).toBe(variant);
    });

    it('falls back to the raw value and neutral variant for unknown modes', () => {
      expect(modeLabel('unknown')).toBe('unknown');
      expect(modeVariant('unknown')).toBe('neutral');
    });
  });

  describe('status', () => {
    it.each`
      status        | label         | variant
      ${'active'}   | ${'Active'}   | ${'success'}
      ${'disabled'} | ${'Disabled'} | ${'neutral'}
    `('maps $status to "$label" and the $variant variant', ({ status, label, variant }) => {
      expect(statusLabel(status)).toBe(label);
      expect(statusVariant(status)).toBe(variant);
    });

    it('falls back to the raw value and neutral variant for unknown statuses', () => {
      expect(statusLabel('archived')).toBe('archived');
      expect(statusVariant('archived')).toBe('neutral');
    });
  });

  describe('scopeLabel', () => {
    it('pluralizes the project count', () => {
      expect(scopeLabel(1)).toBe('1 project');
      expect(scopeLabel(3)).toBe('3 projects');
    });

    it('labels an unscoped policy as applying to all projects', () => {
      expect(scopeLabel(0)).toBe('All projects');
      expect(scopeLabel(undefined)).toBe('All projects');
    });
  });
});
