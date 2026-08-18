import { snakeCase } from 'lodash-es';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { OPERATORS_OR_NOT } from '~/vue_shared/components/filtered_search_bar/constants';
import AttributeToken from 'ee/security_configuration/security_attributes/components/shared/attribute_token.vue';

const toAttributeOption = (attribute) => ({
  ...attribute,
  id: getIdFromGraphQLId(attribute.id).toString(),
  text: attribute.name,
});

// Prefixed with "attribute~" to avoid clashes with other token types.
// "~" is URL-safe and won't appear in snakeCase output.
const toToken = ({ id, name, securityAttributes }) => ({
  type: `attribute~${snakeCase(name)}`,
  title: name,
  multiSelect: true,
  unique: true,
  token: AttributeToken,
  categoryId: id,
  attributeOptions: securityAttributes.map(toAttributeOption),
  operators: OPERATORS_OR_NOT,
});

export const getAttributeCategoryTokens = (securityCategories = []) =>
  securityCategories.filter(({ securityAttributes }) => securityAttributes?.length).map(toToken);
