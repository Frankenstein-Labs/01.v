import { getAttributeCategoryTokens } from 'ee/security_dashboard/utils/attribute_utils';
import { OPERATORS_OR_NOT } from '~/vue_shared/components/filtered_search_bar/constants';
import AttributeToken from 'ee/security_configuration/security_attributes/components/shared/attribute_token.vue';

const gid = (id) => `gid://gitlab/Security::Attribute/${id}`;

const mockSecurityCategories = [
  {
    id: 6,
    name: 'Business Impact',
    securityAttributes: [
      { id: gid(10), name: 'Business Administrative', description: 'desc', color: '#e9be74' },
      { id: gid(8), name: 'Business Critical', description: 'desc', color: '#c17d10' },
    ],
  },
  {
    id: 10,
    name: 'Custom',
    securityAttributes: [{ id: gid(13), name: 'first', description: 'desc', color: '#aaa' }],
  },
  {
    id: 12,
    name: 'Empty Category',
    securityAttributes: [],
  },
];

describe('getAttributeCategoryTokens', () => {
  it('returns an empty array when given no categories', () => {
    expect(getAttributeCategoryTokens()).toStrictEqual([]);
  });

  it('filters out categories with no security attributes', () => {
    const tokens = getAttributeCategoryTokens(mockSecurityCategories);

    expect(tokens).toHaveLength(2);
    expect(tokens.map((t) => t.title)).toStrictEqual(['Business Impact', 'Custom']);
  });

  it('maps securityCategories to filtered search tokens', () => {
    expect(getAttributeCategoryTokens(mockSecurityCategories)).toStrictEqual([
      {
        type: 'attribute~business_impact',
        title: 'Business Impact',
        multiSelect: true,
        unique: true,
        token: AttributeToken,
        categoryId: 6,
        attributeOptions: [
          {
            id: '10',
            name: 'Business Administrative',
            description: 'desc',
            color: '#e9be74',
            text: 'Business Administrative',
          },
          {
            id: '8',
            name: 'Business Critical',
            description: 'desc',
            color: '#c17d10',
            text: 'Business Critical',
          },
        ],
        operators: OPERATORS_OR_NOT,
      },
      {
        type: 'attribute~custom',
        title: 'Custom',
        multiSelect: true,
        unique: true,
        token: AttributeToken,
        categoryId: 10,
        attributeOptions: [
          {
            id: '13',
            name: 'first',
            description: 'desc',
            color: '#aaa',
            text: 'first',
          },
        ],
        operators: OPERATORS_OR_NOT,
      },
    ]);
  });

  it('converts GraphQL IDs to numeric string IDs in attributeOptions', () => {
    const tokens = getAttributeCategoryTokens(mockSecurityCategories);

    expect(tokens[0].attributeOptions[0].id).toBe('10');
    expect(tokens[0].attributeOptions[1].id).toBe('8');
  });

  it('uses snakeCase category name as the token type', () => {
    const tokens = getAttributeCategoryTokens(mockSecurityCategories);

    expect(tokens[0].type).toBe('attribute~business_impact');
    expect(tokens[1].type).toBe('attribute~custom');
  });
});
