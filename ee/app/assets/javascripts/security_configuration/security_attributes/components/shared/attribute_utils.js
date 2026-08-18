import { OPERATORS_IS_NOT_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import AttributeToken from './attribute_token.vue';
import { ATTRIBUTE_TOKEN_PREFIX } from './attribute_constants';

export const getAttributeHeaderToken = (securityCategories = [], title) => ({
  type: 'gl-filtered-search-suggestion-group-attributes',
  title,
  match: ({ query, defaultMatcher }) =>
    securityCategories.some(({ name }) => defaultMatcher(name, query)),
});

export const getAttributeCategoryTokens = (securityCategories = []) =>
  securityCategories
    ?.filter(({ securityAttributes }) => securityAttributes?.length)
    .map(({ id, name }) => ({
      type: `${ATTRIBUTE_TOKEN_PREFIX}${id}`,
      title: name,
      multiSelect: true,
      unique: true,
      token: AttributeToken,
      categoryId: id,
      attributeOptions:
        securityCategories
          .find((category) => category.id === id)
          ?.securityAttributes.map((attribute) => ({ ...attribute, text: attribute.name })) || [],
      operators: OPERATORS_IS_NOT_OR,
    }));
