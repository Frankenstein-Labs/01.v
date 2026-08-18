import {
  buildRows,
  categoryToYamlKey,
  getInitialCategoryKey,
  getInitialExceptionType,
  getInitialExcludingAttributeIds,
  getInitialIncludingAttributeIds,
  getNonReservedScope,
  getReservedScope,
} from 'ee/security_orchestration/components/policy_editor/scope/utils';

describe('categoryToYamlKey', () => {
  it.each`
    templateType         | name                 | expected
    ${'BUSINESS_IMPACT'} | ${'Business Impact'} | ${'business_impact'}
    ${'BUSINESS_UNIT'}   | ${'Business Unit'}   | ${'business_unit'}
    ${'APPLICATION'}     | ${'Application'}     | ${'application'}
    ${'EXPOSURE'}        | ${'Exposure level'}  | ${'exposure'}
    ${null}              | ${'New Category'}    | ${'new_category'}
    ${null}              | ${'My Custom Label'} | ${'my_custom_label'}
    ${undefined}         | ${'Another One'}     | ${'another_one'}
  `(
    'returns "$expected" for templateType=$templateType, name="$name"',
    ({ templateType, name, expected }) => {
      expect(categoryToYamlKey({ templateType, name })).toBe(expected);
    },
  );
});

describe('getInitialCategoryKey', () => {
  it('returns null for an empty or undefined scope', () => {
    expect(getInitialCategoryKey()).toBe(null);
    expect(getInitialCategoryKey({})).toBe(null);
  });

  it('returns the first non-reserved key with including or excluding', () => {
    expect(getInitialCategoryKey({ business_impact: { including: [{ id: 1 }] } })).toBe(
      'business_impact',
    );
    expect(getInitialCategoryKey({ exposure: { excluding: [{ id: 3 }] } })).toBe('exposure');
  });

  it('ignores reserved scope keys', () => {
    expect(
      getInitialCategoryKey({
        projects: { including: [{ id: 5 }] },
        groups: { excluding: [{ id: 6 }] },
        compliance_frameworks: [{ id: 7 }],
        exposure: { including: [{ id: 3 }] },
      }),
    ).toBe('exposure');
  });

  it('returns null when only reserved keys are present', () => {
    expect(
      getInitialCategoryKey({
        projects: { including: [{ id: 5 }] },
      }),
    ).toBe(null);
  });

  it('returns null when the candidate key has no including or excluding', () => {
    expect(getInitialCategoryKey({ business_impact: {} })).toBe(null);
  });
});

describe('getInitialExceptionType', () => {
  it('returns "including" when no category is present', () => {
    expect(getInitialExceptionType({})).toBe('including');
  });

  it('returns "including" when the category uses the including key', () => {
    expect(getInitialExceptionType({ business_impact: { including: [{ id: 1 }] } })).toBe(
      'including',
    );
  });

  it('returns "excluding" when the category uses the excluding key', () => {
    expect(getInitialExceptionType({ business_impact: { excluding: [{ id: 2 }] } })).toBe(
      'excluding',
    );
  });
});

describe('getInitialIncludingAttributeIds', () => {
  it('returns an empty array when no category is selected', () => {
    expect(getInitialIncludingAttributeIds({})).toEqual([]);
  });

  it('maps numeric ids to GraphQL ids from the including list', () => {
    expect(
      getInitialIncludingAttributeIds({ business_impact: { including: [{ id: 1 }, { id: 2 }] } }),
    ).toEqual(['gid://gitlab/Security::Attribute/1', 'gid://gitlab/Security::Attribute/2']);
  });

  it('returns an empty array when including is missing, even if excluding is set', () => {
    expect(
      getInitialIncludingAttributeIds({ business_impact: { excluding: [{ id: 3 }] } }),
    ).toEqual([]);
  });

  it('returns an empty array when including is not an array', () => {
    expect(getInitialIncludingAttributeIds({ business_impact: { including: null } })).toEqual([]);
  });
});

describe('getInitialExcludingAttributeIds', () => {
  it('returns an empty array when no category is selected', () => {
    expect(getInitialExcludingAttributeIds({})).toEqual([]);
  });

  it('maps numeric ids to GraphQL ids from the excluding list', () => {
    expect(
      getInitialExcludingAttributeIds({ business_impact: { excluding: [{ id: 3 }, { id: 4 }] } }),
    ).toEqual(['gid://gitlab/Security::Attribute/3', 'gid://gitlab/Security::Attribute/4']);
  });

  it('returns an empty array when excluding is missing', () => {
    expect(
      getInitialExcludingAttributeIds({ business_impact: { including: [{ id: 1 }] } }),
    ).toEqual([]);
  });

  it('hydrates independently from the including list', () => {
    expect(
      getInitialExcludingAttributeIds({
        business_impact: { including: [{ id: 1 }], excluding: [{ id: 2 }] },
      }),
    ).toEqual(['gid://gitlab/Security::Attribute/2']);
  });
});

describe('getNonReservedScope', () => {
  it('returns an empty object for an empty or undefined scope', () => {
    expect(getNonReservedScope()).toEqual({});
    expect(getNonReservedScope({})).toEqual({});
    expect(getNonReservedScope(null)).toEqual({});
  });

  it('strips reserved keys and keeps category keys', () => {
    expect(
      getNonReservedScope({
        projects: { including: [{ id: 1 }] },
        groups: { excluding: [{ id: 2 }] },
        compliance_frameworks: [{ id: 3 }],
        business_impact: { including: [{ id: 4 }] },
        exposure: { excluding: [{ id: 5 }] },
      }),
    ).toEqual({
      business_impact: { including: [{ id: 4 }] },
      exposure: { excluding: [{ id: 5 }] },
    });
  });

  it('returns an empty object when only reserved keys are present', () => {
    expect(
      getNonReservedScope({
        projects: { including: [{ id: 1 }] },
        compliance_frameworks: [{ id: 2 }],
      }),
    ).toEqual({});
  });

  it('preserves category values unchanged (no deep clone)', () => {
    const category = { including: [{ id: 1 }] };
    const result = getNonReservedScope({ business_impact: category });
    expect(result.business_impact).toBe(category);
  });
});

describe('getReservedScope', () => {
  it('returns an empty object for an empty or undefined scope', () => {
    expect(getReservedScope()).toEqual({});
    expect(getReservedScope({})).toEqual({});
    expect(getReservedScope(null)).toEqual({});
  });

  it('keeps reserved keys and strips category keys', () => {
    expect(
      getReservedScope({
        projects: { including: [{ id: 1 }] },
        groups: { excluding: [{ id: 2 }] },
        compliance_frameworks: [{ id: 3 }],
        business_impact: { including: [{ id: 4 }] },
        exposure: { excluding: [{ id: 5 }] },
      }),
    ).toEqual({
      projects: { including: [{ id: 1 }] },
      groups: { excluding: [{ id: 2 }] },
      compliance_frameworks: [{ id: 3 }],
    });
  });

  it('returns an empty object when only category keys are present', () => {
    expect(
      getReservedScope({
        business_impact: { including: [{ id: 1 }] },
      }),
    ).toEqual({});
  });

  it('is complementary with getNonReservedScope', () => {
    const scope = {
      projects: { including: [{ id: 1 }] },
      business_impact: { including: [{ id: 2 }] },
    };
    expect({ ...getReservedScope(scope), ...getNonReservedScope(scope) }).toEqual(scope);
  });
});

describe('buildRows', () => {
  it('returns a single empty row for an empty scope', () => {
    const rows = buildRows({});
    expect(rows).toHaveLength(1);
    expect(rows[0].scope).toEqual({});
    expect(rows[0].id).toEqual(expect.stringMatching(/^scope-row-/));
  });

  it('returns a single empty row when scope is undefined', () => {
    const rows = buildRows();
    expect(rows).toHaveLength(1);
    expect(rows[0].scope).toEqual({});
  });

  it('returns a single empty row when only reserved keys are present', () => {
    const rows = buildRows({ projects: { including: [{ id: 1 }] } });
    expect(rows).toHaveLength(1);
    expect(rows[0].scope).toEqual({});
  });

  it('builds one row per non-reserved category key, preserving values', () => {
    const rows = buildRows({
      projects: { including: [{ id: 1 }] },
      business_impact: { including: [{ id: 2 }] },
      exposure: { excluding: [{ id: 3 }] },
    });

    expect(rows).toHaveLength(2);
    expect(rows.map((r) => r.scope)).toEqual([
      { business_impact: { including: [{ id: 2 }] } },
      { exposure: { excluding: [{ id: 3 }] } },
    ]);
  });

  it('assigns a unique id to each row', () => {
    const rows = buildRows({
      business_impact: { including: [{ id: 1 }] },
      exposure: { excluding: [{ id: 2 }] },
    });
    const ids = rows.map((r) => r.id);
    expect(new Set(ids).size).toBe(ids.length);
    ids.forEach((id) => expect(id).toEqual(expect.stringMatching(/^scope-row-/)));
  });
});
