import { createAlert, VARIANT_INFO } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  convertObjectPropsToCamelCase,
  normalizeHeaders,
  parseBoolean,
  parseIntPagination,
} from '~/lib/utils/common_utils';
import { __, sprintf } from '~/locale';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_SBOM_OCCURRENCE } from 'ee/graphql_shared/constants';
import { OPERATOR_NOT } from '~/vue_shared/components/filtered_search_bar/constants';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filtered_search/constants';
import projectDependencies from '../graphql/project_dependencies.query.graphql';
import groupDependencies from '../graphql/group_dependencies.query.graphql';
import dependencyVulnerabilities from '../graphql/dependency_vulnerabilities.query.graphql';
import spdxLicenses from '../graphql/spdx_licenses.query.graphql';
import {
  EXPORT_STARTED_MESSAGE,
  FETCH_ERROR_MESSAGE,
  FETCH_ERROR_MESSAGE_WITH_DETAILS,
  FETCH_EXPORT_ERROR_MESSAGE,
  LICENSES_FETCH_ERROR_MESSAGE,
  VULNERABILITIES_FETCH_ERROR_MESSAGE,
} from './constants';
import * as types from './mutation_types';
import { graphQLClient, isValidResponse } from './utils';

export const setDependenciesEndpoint = ({ commit }, endpoint) =>
  commit(types.SET_DEPENDENCIES_ENDPOINT, endpoint);

export const setExportDependenciesEndpoint = ({ commit }, payload) =>
  commit(types.SET_EXPORT_DEPENDENCIES_ENDPOINT, payload);

export const setNamespaceType = ({ commit }, payload) => commit(types.SET_NAMESPACE_TYPE, payload);

export const setPageInfo = ({ commit }, payload) => commit(types.SET_PAGE_INFO, payload);

export const setFullPath = ({ commit }, fullPath) => commit(types.SET_FULL_PATH, fullPath);

export const requestDependencies = ({ commit }) => commit(types.REQUEST_DEPENDENCIES);

const parseCursorPagination = (headers) => {
  return {
    type: headers['X-PAGE-TYPE'],
    currentCursor: headers['X-PAGE'],
    endCursor: headers['X-NEXT-PAGE'],
    hasNextPage: headers['X-NEXT-PAGE'] !== '',
    hasPreviousPage: headers['X-PREV-PAGE'] !== '',
    startCursor: headers['X-PREV-PAGE'],
  };
};

const parseOffsetPagination = (headers) => {
  return {
    ...parseIntPagination(headers),
    type: 'offset',
  };
};

const parsePagination = (headers) => {
  const paginateWithCursor = headers['X-PAGE-TYPE'] === 'cursor';
  if (paginateWithCursor) {
    return parseCursorPagination(headers);
  }
  return parseOffsetPagination(headers);
};

export const receiveDependenciesSuccess = ({ commit }, { headers, data }) => {
  const pageInfo = parsePagination(normalizeHeaders(headers));
  const { dependencies } = data;
  const convertedDependencies = dependencies.map((item) =>
    convertObjectPropsToCamelCase(item, {
      deep: true,
    }),
  );

  commit(types.RECEIVE_DEPENDENCIES_SUCCESS, {
    dependencies: convertedDependencies,
    pageInfo,
  });
};

export const receiveDependenciesError = ({ commit }, error) =>
  commit(types.RECEIVE_DEPENDENCIES_ERROR, error);

const queryParametersFor = (state, params) => {
  const { searchFilterParameters } = state;
  const queryParams = {
    sort_by: state.sortField,
    sort: state.sortOrder,
    filter: 'all',
    ...searchFilterParameters,
    ...params,
  };

  return queryParams;
};

export const fetchDependencies = ({ state, dispatch }, params) => {
  if (!state.endpoint) {
    return;
  }

  dispatch('requestDependencies');

  axios
    .get(state.endpoint, { params: queryParametersFor(state, params) })
    .then((response) => {
      if (isValidResponse(response)) {
        dispatch('receiveDependenciesSuccess', response);
      } else {
        throw new Error(__('Invalid server response'));
      }
    })
    .catch((error) => {
      dispatch('receiveDependenciesError', error);

      const errorDetails = error?.response?.data?.message;

      const message = errorDetails
        ? sprintf(FETCH_ERROR_MESSAGE_WITH_DETAILS, { errorDetails })
        : FETCH_ERROR_MESSAGE;

      createAlert({ message });
    });
};

const buildGraphQLPaginationVariables = ({ cursor, pageInfo = {}, pageSize = 20 }) => {
  const isInitialPage = !cursor;
  const isNavigatingBackward = cursor === pageInfo.startCursor;

  if (isInitialPage) {
    return { first: pageSize };
  }

  if (isNavigatingBackward) {
    return {
      last: pageSize,
      before: cursor,
    };
  }

  // Default to forward navigation for all other cases
  return {
    first: pageSize,
    after: cursor,
  };
};

const buildGraphQLFilterOptions = (searchFilterParameters) => {
  const {
    component_activity: componentActivityFilters,
    component_names: componentNamesFilters,
    component_versions: componentVersionsFilters,
    malware: malwareFilter,
    trackedRefIds: trackedRefIdsFilters,
  } = searchFilterParameters;

  const filterOptions = {};

  const policyViolations = componentActivityFilters?.filter((v) => v !== 'ALL');
  if (policyViolations?.length > 0) {
    filterOptions.policyViolations = policyViolations;
  }

  if (componentVersionsFilters?.length > 0) {
    filterOptions.componentVersions = componentVersionsFilters;
  }

  if (componentNamesFilters?.length > 0) {
    filterOptions.componentNames = componentNamesFilters;
  }

  if (malwareFilter !== undefined) {
    filterOptions.malware = parseBoolean(malwareFilter);
  }

  const trackedRefIds = (trackedRefIdsFilters || [])
    .filter((ref) => ref !== ALL_ID)
    .map((ref) => ref.id);
  if (trackedRefIds.length > 0) {
    filterOptions.trackedRefIds = trackedRefIds;
  }

  return filterOptions;
};

const buildGraphQLSortOptions = (sortField = '', sortOrder = '') => {
  if (!sortField || !sortOrder) {
    return {};
  }

  return {
    sort: `${sortField.toUpperCase()}_${sortOrder.toUpperCase()}`,
  };
};

const mapGraphQLDependencyToStore = ({ id, componentVersion, packager, ...dependency }) => ({
  ...dependency,
  id,
  occurrenceId: getIdFromGraphQLId(id),
  // the componentId is needed to fetch related vulnerabilities
  componentId: getIdFromGraphQLId(id),
  // Note: This will be mapped to an actual value, once the field has been added to the GraphQL query
  // Related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/532226
  projectCount: 1,
  ...(componentVersion && {
    version: componentVersion.version,
    componentVersionId: getIdFromGraphQLId(componentVersion.id),
  }),
  // `packager` is of type enum (`Dependency.PackageManager`), which per convention is returned as an uppercase string
  //  all supported packager names map nicely to the lowercase version, so we can keep this simple and just transform them to lowercase
  ...(packager && { packager: packager.toLowerCase() }),
});

export const fetchDependenciesViaGraphQL = ({ state, dispatch, commit }, params = {}) => {
  dispatch('requestDependencies');

  const { cursor, pageSize } = params;
  const { fullPath, namespaceType, pageInfo, sortField, sortOrder, searchFilterParameters } = state;

  const query = namespaceType === 'group' ? groupDependencies : projectDependencies;

  const variables = {
    fullPath,
    ...buildGraphQLPaginationVariables({
      cursor,
      pageInfo,
      pageSize,
    }),
    ...buildGraphQLFilterOptions(searchFilterParameters),
    ...buildGraphQLSortOptions(sortField, sortOrder),
  };

  graphQLClient
    .query({
      query,
      variables,
    })
    .then(({ data }) => {
      const { nodes: dependenciesData, pageInfo: responsePageInfo } = data.namespace.dependencies;

      const dependencies = dependenciesData.map(mapGraphQLDependencyToStore);

      commit(types.RECEIVE_DEPENDENCIES_SUCCESS, {
        dependencies,
        pageInfo: responsePageInfo,
      });
    })
    .catch((error) => {
      dispatch('receiveDependenciesError', error);

      const errorMessage = error.message || FETCH_ERROR_MESSAGE;
      createAlert({ message: errorMessage });
    });
};

export const setSortField = ({ commit }, id) => {
  commit(types.SET_SORT_FIELD, id);
};

export const toggleSortOrder = ({ commit }) => {
  commit(types.TOGGLE_SORT_ORDER);
};

export const fetchExport = ({ state, commit }, params) => {
  if (!state.exportEndpoint) {
    return;
  }

  commit(types.SET_FETCHING_IN_PROGRESS, true);

  const defaultParams = { send_email: true };

  axios
    .post(state.exportEndpoint, { ...defaultParams, ...params })
    .then((response) => {
      if (response?.status === HTTP_STATUS_CREATED) {
        commit(types.SET_FETCHING_IN_PROGRESS, false);
        createAlert({ message: EXPORT_STARTED_MESSAGE, variant: VARIANT_INFO });
      } else {
        throw new Error(__('Invalid server response'));
      }
    })
    .catch(() => {
      commit(types.SET_FETCHING_IN_PROGRESS, false);
      createAlert({
        message: FETCH_EXPORT_ERROR_MESSAGE,
      });
    });
};

export const setSearchFilterParameters = ({ state, commit }, searchFilters = []) => {
  const searchFilterParameters = {};

  // populate the searchFilterParameters object with the data from the search filters. For example:
  // given filters: [{ type: 'licenses', value: { data: ['MIT', 'GNU'] } }, { type: 'project', value: { data: ['GitLab'] } }
  // will result in the parameters: { licenses: ['MIT', 'GNU'], project: ['GitLab'] }
  searchFilters.forEach((searchFilter) => {
    let { type } = searchFilter;
    const { value } = searchFilter;
    let filterData = value.data;

    // The MalwareToken is single select and emits a single string value instead of an array.
    if (type === 'malware' && typeof filterData === 'string') {
      searchFilterParameters[type] = filterData;
      return;
    }

    // If a user types to filter available options the filter data will be a string and we just ignore it
    // as filters can only be applied via selecting an option from the dropdown
    if (!Array.isArray(filterData) || !filterData.length) {
      return;
    }

    if (type === 'licenses') {
      // for the license filter we display the license name in the UI, but want to send the spdx-identifier to the API
      const getSpdxIdentifier = (licenseName) =>
        state.licenses.find(({ name }) => name === licenseName)?.spdxIdentifier || [];

      filterData = filterData.flatMap(getSpdxIdentifier);
    }
    if (value.operator === OPERATOR_NOT) {
      type = `not[${type}]`;
    }

    // Convert reactive Vue arrays to plain arrays to fix caching issue
    // Without this, Apollo returns wrong cached data when filters change
    // Ex. ['0.24.0', '1.6.7', __ob__: Observer2] → ['0.24.0', '1.6.7']
    searchFilterParameters[type] = Array.isArray(filterData) ? [...filterData] : filterData;
  });

  commit(types.SET_SEARCH_FILTER_PARAMETERS, searchFilterParameters);
};

export const fetchLicenses = async ({ commit, state }) => {
  if (state.licenses.length) {
    return;
  }

  commit(types.SET_FETCHING_LICENSES_IN_PROGRESS, true);

  try {
    const { data } = await graphQLClient.query({ query: spdxLicenses });
    const licenses = data?.spdxLicenses || [];

    // spdxIdentifier can have duplicates, so we use the index as the id
    // https://gitlab.com/gitlab-org/gitlab/-/work_items/439886
    const licensesWithId = licenses.map((license, index) => ({
      ...license,
      id: index,
    }));

    commit(types.SET_LICENSES, licensesWithId);
  } catch (e) {
    createAlert({
      message: LICENSES_FETCH_ERROR_MESSAGE,
    });
  } finally {
    commit(types.SET_FETCHING_LICENSES_IN_PROGRESS, false);
  }
};

export const fetchVulnerabilitiesViaGraphQL = ({ commit }, { item }) => {
  const { occurrenceId } = item;

  if (!occurrenceId) {
    return;
  }

  commit(types.TOGGLE_VULNERABILITY_ITEM_LOADING, item);

  graphQLClient
    .query({
      query: dependencyVulnerabilities,
      variables: {
        occurrenceId: convertToGraphQLId(TYPENAME_SBOM_OCCURRENCE, occurrenceId),
      },
    })
    .then(({ data }) => {
      const vulnerabilities = data.dependency?.vulnerabilities?.nodes || [];

      const vulnerabilitiesWithOccurrenceId = vulnerabilities.map((vulnerability) => ({
        ...vulnerability,
        // the occurrence_id is used by both the mutation and UI to map the vulnerability to the correct dependency
        occurrence_id: occurrenceId,
      }));

      commit(types.SET_VULNERABILITIES, vulnerabilitiesWithOccurrenceId);
    })
    .catch(() => {
      createAlert({
        message: VULNERABILITIES_FETCH_ERROR_MESSAGE,
      });
    })
    .finally(() => {
      commit(types.TOGGLE_VULNERABILITY_ITEM_LOADING, item);
    });
};
