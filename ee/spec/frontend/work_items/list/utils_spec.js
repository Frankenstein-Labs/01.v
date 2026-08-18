import {
  getFilterTokens,
  convertToApiParams,
  convertToUrlParams,
  getCustomFieldTokenId,
  mergeDuplicatedCustomFieldTokens,
  getSavedViewFilterTokens,
} from 'ee/work_items/list/utils';
import {
  TOKEN_TYPE_STATE,
  OPERATOR_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { savedViewFiltersObject, savedViewFilterTokens } from '../mock_data';

describe('getFilterTokens', () => {
  it('parses URL search params into filter tokens', () => {
    const locationSearch = '?state=opened';
    const tokens = getFilterTokens(locationSearch, { includeStateToken: true });

    expect(tokens).toHaveLength(1);
    expect(tokens[0]).toMatchObject({
      type: TOKEN_TYPE_STATE,
      value: { data: 'opened', operator: '=' },
    });
  });

  it('excludes state token when includeStateToken is false', () => {
    const locationSearch = '?type=issue&state=opened';
    const tokens = getFilterTokens(locationSearch, { includeStateToken: false });

    expect(tokens.find((t) => t.type === TOKEN_TYPE_STATE)).toBeUndefined();
  });

  it('handles custom fields when feature is enabled', () => {
    const locationSearch = '?custom-field[123]=456';
    const tokens = getFilterTokens(locationSearch, { hasCustomFieldsFeature: true });

    expect(tokens).toHaveLength(1);
    expect(tokens[0]).toMatchObject({
      type: 'custom-field[123]',
      value: { data: '456', operator: '=' },
    });
  });
});

describe('convertToApiParams', () => {
  it('ignores custom field tokens when feature is not enabled', () => {
    const filterTokens = [{ type: 'custom-field[123]', value: { data: '456', operator: '=' } }];
    const params = convertToApiParams(filterTokens);

    expect(params).toEqual({});
  });

  it('handles custom field tokens when feature is enabled', () => {
    const filterTokens = [{ type: 'custom-field[123]', value: { data: '456', operator: '=' } }];
    const params = convertToApiParams(filterTokens, { hasCustomFieldsFeature: true });

    expect(params).toEqual({
      customField: [
        {
          customFieldId: 'gid://gitlab/Issuables::CustomField/123',
          selectedOptionIds: ['gid://gitlab/Issuables::CustomFieldSelectOption/456'],
        },
      ],
    });
  });
});

describe('convertToUrlParams', () => {
  it('ignores custom field tokens when option not passed', () => {
    const filterTokens = [{ type: 'custom-field[123]', value: { data: '456', operator: '=' } }];
    const params = convertToUrlParams(filterTokens);

    expect(params).toEqual({});
  });

  it('handles custom field tokens when option passed', () => {
    const filterTokens = [{ type: 'custom-field[123]', value: { data: '456', operator: '=' } }];
    const params = convertToUrlParams(filterTokens, { hasCustomFieldsFeature: true });

    expect(params['custom-field[123]']).toEqual('456');
  });
});

describe('getCustomFieldTokenId', () => {
  it('extracts custom field ID from token type', () => {
    const token = { type: 'custom-field[123]' };
    expect(getCustomFieldTokenId(token)).toBe('123');
  });

  it('returns undefined for null token', () => {
    expect(getCustomFieldTokenId(null)).toBeUndefined();
  });

  it('returns undefined for undefined token', () => {
    expect(getCustomFieldTokenId(undefined)).toBeUndefined();
  });

  it('returns undefined for token without type', () => {
    const token = { value: { data: 'test' } };
    expect(getCustomFieldTokenId(token)).toBeUndefined();
  });
});

describe('mergeDuplicatedCustomFieldTokens', () => {
  it('merges tokens with the same custom field ID', () => {
    const tokens = [
      {
        type: 'custom-field[1]',
        value: { data: 'option1', operator: OPERATOR_IS },
      },
      {
        type: 'custom-field[1]',
        value: { data: 'option2', operator: OPERATOR_IS },
      },
    ];

    const result = mergeDuplicatedCustomFieldTokens(tokens);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      type: 'custom-field[1]',
      value: {
        data: ['option1', 'option2'],
        operator: OPERATOR_IS,
      },
    });
  });

  it('preserves tokens with different custom field IDs', () => {
    const tokens = [
      {
        type: 'custom-field[2]',
        value: { data: 'option1', operator: OPERATOR_IS },
      },
      {
        type: 'custom-field[4]',
        value: { data: 'option2', operator: OPERATOR_IS },
      },
    ];

    const result = mergeDuplicatedCustomFieldTokens(tokens);

    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({
      type: 'custom-field[2]',
      value: {
        data: ['option1'],
        operator: OPERATOR_IS,
      },
    });
    expect(result[1]).toEqual({
      type: 'custom-field[4]',
      value: {
        data: ['option2'],
        operator: OPERATOR_IS,
      },
    });
  });

  it('removes duplicate values when merging', () => {
    const tokens = [
      {
        type: 'custom-field[1]',
        value: { data: 'option1', operator: OPERATOR_IS },
      },
      {
        type: 'custom-field[1]',
        value: { data: 'option1', operator: OPERATOR_IS },
      },
      {
        type: 'custom-field[1]',
        value: { data: 'option2', operator: OPERATOR_IS },
      },
    ];

    const result = mergeDuplicatedCustomFieldTokens(tokens);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      type: 'custom-field[1]',
      value: {
        data: ['option1', 'option2'],
        operator: OPERATOR_IS,
      },
    });
  });

  it('handles empty array input', () => {
    const result = mergeDuplicatedCustomFieldTokens([]);
    expect(result).toEqual([]);
  });

  it('handles single token', () => {
    const tokens = [
      {
        type: 'custom-field[1]',
        value: { data: 'option1', operator: OPERATOR_IS },
      },
    ];

    const result = mergeDuplicatedCustomFieldTokens(tokens);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      type: 'custom-field[1]',
      value: {
        data: ['option1'],
        operator: OPERATOR_IS,
      },
    });
  });
});

describe('getSavedViewFilterTokens', () => {
  it('returns valid filter tokens given a saved view filters object', () => {
    expect(getSavedViewFilterTokens(savedViewFiltersObject)).toEqual(savedViewFilterTokens);
  });
});
