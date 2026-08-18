import {
  removeIds,
  createSourceBranchPatternObject,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';

describe('removeIds', () => {
  it.each`
    items                                                       | expected
    ${undefined}                                                | ${[]}
    ${[]}                                                       | ${[]}
    ${[{ name: 'name1', id: '1' }]}                             | ${[{ name: 'name1' }]}
    ${[{ name: 'name1', id: '1' }, { name: 'name2', id: '2' }]} | ${[{ name: 'name1' }, { name: 'name2' }]}
    ${[{ name: 'name1' }]}                                      | ${[{ name: 'name1' }]}
  `('remove ids from objects with ids', ({ items, expected }) => {
    expect(removeIds(items)).toEqual(expected);
  });
});

describe('createSourceBranchPatternObject', () => {
  it('creates object with generated id when no id provided', () => {
    const result = createSourceBranchPatternObject();
    expect(result.id).toMatch(/^pattern_/);
    expect(result.source).toEqual({});
    expect(result.target).toEqual({});
  });

  it('uses provided id', () => {
    const result = createSourceBranchPatternObject({ id: 'custom_id' });
    expect(result.id).toBe('custom_id');
  });

  it('preserves source and target with pattern', () => {
    const result = createSourceBranchPatternObject({
      source: { pattern: 'feature/*' },
      target: { pattern: 'main' },
    });
    expect(result.source).toEqual({ pattern: 'feature/*' });
    expect(result.target).toEqual({ pattern: 'main' });
  });

  it('converts target.name to target.pattern for backward compatibility', () => {
    const result = createSourceBranchPatternObject({
      source: { pattern: 'feature/*' },
      target: { name: 'main' },
    });
    expect(result.source).toEqual({ pattern: 'feature/*' });
    expect(result.target).toEqual({ pattern: 'main' });
  });

  it('prefers target.pattern over target.name when both exist', () => {
    const result = createSourceBranchPatternObject({
      target: { pattern: 'release/*', name: 'main' },
    });
    expect(result.target).toEqual({ pattern: 'release/*', name: 'main' });
  });
});
