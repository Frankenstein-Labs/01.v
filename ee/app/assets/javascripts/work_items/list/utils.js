/* eslint-disable import/export */
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  convertToApiParams as convertToApiParamsCE,
  convertToUrlParams as convertToUrlParamsCE,
  convertMultipleIsTypeTokensToOr,
  getSavedViewFilterTokens as getSavedViewFilterTokensCE,
} from '~/work_items/list/utils';
import { filtersMap, URL_PARAM } from '~/work_items/list/constants';

import {
  TOKEN_TYPE_TYPE,
  OPERATOR_IS,
  TOKEN_TYPE_STATE,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TYPENAME_CUSTOM_FIELD,
  TYPENAME_CUSTOM_FIELD_SELECT_OPTION,
} from '~/graphql_shared/constants';

export * from '~/work_items/list/utils';

const customFieldApiFieldName = 'customField';

const customFieldRegex = /custom-field\[(\d+)\]/;
const isCustomField = (name) => customFieldRegex.test(name);
const isCustomFieldToken = (token) => customFieldRegex.test(token.type);

const tokenTypes = Object.keys(filtersMap);

const getUrlParams = (tokenType) =>
  Object.values(filtersMap[tokenType][URL_PARAM]).flatMap((filterObj) => Object.values(filterObj));

const urlParamKeys = tokenTypes.flatMap(getUrlParams);

const getTokenTypeFromUrlParamKey = (urlParamKey) => {
  if (isCustomField(urlParamKey)) {
    return urlParamKey;
  }
  return tokenTypes.find((tokenType) => getUrlParams(tokenType).includes(urlParamKey));
};

const getOperatorFromUrlParamKey = (tokenType, urlParamKey) => {
  if (isCustomField(urlParamKey)) {
    return OPERATOR_IS;
  }
  return Object.entries(filtersMap[tokenType][URL_PARAM]).find(([, filterObj]) =>
    Object.values(filterObj).includes(urlParamKey),
  )[0];
};

export const getFilterTokens = (locationSearch, options = {}) => {
  const tokens = Array.from(new URLSearchParams(locationSearch).entries())
    .filter(([key]) => {
      if (!options.includeStateToken && key === TOKEN_TYPE_STATE) {
        return false;
      }
      const customField = options.hasCustomFieldsFeature && isCustomField(key);
      return urlParamKeys.includes(key) || customField;
    })
    .map(([key, data]) => {
      const type = getTokenTypeFromUrlParamKey(key);
      const operator = getOperatorFromUrlParamKey(type, key);
      return {
        type,
        value: { data, operator },
      };
    });

  if (options.convertTypeTokens) {
    const hasTypeToken = tokens.some((token) => token.type === TOKEN_TYPE_TYPE);
    if (hasTypeToken) return convertMultipleIsTypeTokensToOr(tokens);
  }

  return tokens;
};

/**
 * @param {Object} token - Custom field token ex. { type: "custom-field[2]", }
 * @returns {string} - Custom field token id ex. "2"
 */
export const getCustomFieldTokenId = (token) =>
  token?.type?.replace('custom-field[', '').replace(']', '');

/**
 * @param {Object} filterTokensCustomFields - Custom field tokens
 * @returns {Object} - Custom field tokens with duplicated ids merged into one
 */
export const mergeDuplicatedCustomFieldTokens = (filterTokensCustomFields) => {
  return Object.values(
    filterTokensCustomFields.reduce((acc, token) => {
      const customFieldId = getCustomFieldTokenId(token);

      if (!customFieldId) {
        return acc;
      }

      if (acc[customFieldId]) {
        const existingData = Array.isArray(acc[customFieldId].value.data)
          ? acc[customFieldId].value.data
          : [acc[customFieldId].value.data];
        const newData = Array.isArray(token.value.data) ? token.value.data : [token.value.data];

        acc[customFieldId].value.data = [...new Set([...existingData, ...newData])];
      } else {
        acc[customFieldId] = {
          ...token,
          value: {
            ...token.value,
            data: Array.isArray(token.value.data) ? token.value.data : [token.value.data],
          },
        };
      }

      return acc;
    }, {}),
  );
};

export const convertToApiParams = (filterTokens, options = {}) => {
  const params = new Map();
  const filterTokensFoss = filterTokens.filter((t) => !isCustomFieldToken(t));
  const statusToken = filterTokens.find((t) => t.type === 'status');

  if (options.hasCustomFieldsFeature) {
    const filterTokensCustomFields = filterTokens.filter((t) => isCustomFieldToken(t));

    // Merge duplicated custom fields tokens that have the same id/field
    const uniqueFilterTokensCustomFields =
      mergeDuplicatedCustomFieldTokens(filterTokensCustomFields);

    uniqueFilterTokensCustomFields.forEach((token) => {
      const customFieldId = getCustomFieldTokenId(token);

      const isValueArray = Array.isArray(token.value.data);
      // When field type is multi-select, the value will be an array, so we need to get each ID individually
      const selectedOptionIds = isValueArray
        ? token.value.data.map((value) =>
            convertToGraphQLId(TYPENAME_CUSTOM_FIELD_SELECT_OPTION, value),
          )
        : [convertToGraphQLId(TYPENAME_CUSTOM_FIELD_SELECT_OPTION, token.value.data)];

      const data = [
        {
          customFieldId: convertToGraphQLId(TYPENAME_CUSTOM_FIELD, customFieldId),
          selectedOptionIds,
        },
      ];

      params.set(
        customFieldApiFieldName,
        params.has(customFieldApiFieldName)
          ? [params.get(customFieldApiFieldName), data].flat()
          : data,
      );
    });
  }

  // we should be converting the status param from string to `WorkItemWidgetStatusFilterInput`
  // irrespective if we have the data attribute
  if (statusToken?.value?.data) {
    params.set('status', { name: statusToken?.value?.data });
  }

  return {
    ...convertToApiParamsCE(filterTokensFoss),
    ...Object.fromEntries(params),
  };
};

export const convertToUrlParams = (filterTokens, options = {}) => {
  const params = new Map();

  if (options.hasCustomFieldsFeature) {
    const filterTokensCustomFields = filterTokens.filter((t) => isCustomFieldToken(t));

    filterTokensCustomFields.forEach((token) => {
      const urlParam = token.type;

      params.set(
        urlParam,
        params.has(urlParam) ? [params.get(urlParam), token.value.data].flat() : token.value.data,
      );
    });
  }

  const filterTokensFoss = filterTokens.filter((t) => !isCustomFieldToken(t));
  return {
    ...convertToUrlParamsCE(filterTokensFoss),
    ...Object.fromEntries(params),
  };
};

const graphQLIdToTokenType = (graphQLId) => {
  const id = getIdFromGraphQLId(graphQLId);
  return `custom-field[${id}]`;
};

const extractCustomFieldTokens = (fieldList) => {
  return fieldList.reduce((acc, field) => {
    const type = graphQLIdToTokenType(field.customFieldId);
    const data = field.selectedOptionIds.map((optionId) => getIdFromGraphQLId(optionId).toString());
    acc.push(...data.map((d) => ({ type, data: d, operator: OPERATOR_IS })));
    return acc;
  }, []);
};

export const getSavedViewFilterTokens = (filterObject, options = {}) => {
  const ceTokens = getSavedViewFilterTokensCE(filterObject, options);

  const eeTokens = Object.entries(filterObject)
    .reduce((acc, [key, value]) => {
      if (key === 'customField') {
        acc.push(...extractCustomFieldTokens(value));
      }
      return acc;
    }, [])
    .map(({ type, data, operator }) => {
      return {
        type,
        value: { data, operator },
      };
    });

  return [...ceTokens, ...eeTokens];
};
