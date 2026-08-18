import { isEqual } from 'lodash-es';
import { convertToGraphQLIds, convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { formatDate, getDateInPast, toISODateFormat } from '~/lib/utils/datetime_utility';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import { queryToObject } from '~/lib/utils/url_utility';
import { CURRENT_DATE } from '../audit_events/constants';
import {
  FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
  FRAMEWORKS_FILTER_TYPE_PROJECT,
  FRAMEWORKS_FILTER_TYPE_GROUP,
  FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
  GRAPHQL_FRAMEWORK_TYPE,
  UNKNOWN_CONTROL_LABEL,
} from './constants';

export const isTopLevelGroup = (groupPath, rootPath) => groupPath === rootPath;

export const convertProjectIdsToGraphQl = (projectIds) =>
  convertToGraphQLIds(
    TYPENAME_PROJECT,
    projectIds.filter((id) => Boolean(id)),
  );

export const convertFrameworkIdToGraphQl = (frameworId) =>
  convertToGraphQLId(GRAPHQL_FRAMEWORK_TYPE, frameworId);

export const parseViolationsQueryFilter = ({
  mergedBefore,
  mergedAfter,
  projectIds,
  targetBranch,
}) => ({
  projectIds: projectIds ? convertProjectIdsToGraphQl(projectIds) : [],
  mergedBefore: formatDate(mergedBefore, ISO_SHORT_FORMAT, true),
  mergedAfter: formatDate(mergedAfter, ISO_SHORT_FORMAT, true),
  targetBranch,
});

export const buildDefaultViolationsFilterParams = (queryString) => ({
  mergedAfter: toISODateFormat(getDateInPast(CURRENT_DATE, 30)),
  mergedBefore: toISODateFormat(CURRENT_DATE),
  ...queryToObject(queryString, { gatherArrays: true }),
});

export function mapFiltersToGraphQLVariables(filters) {
  return filters.reduce((result, filter) => {
    const { type, value } = filter;
    const updatedResult = { ...result };

    if (type === FRAMEWORKS_FILTER_TYPE_PROJECT) {
      updatedResult.project = value.data;
    } else if (type === FRAMEWORKS_FILTER_TYPE_GROUP) {
      updatedResult.groupPath = value.data;
    } else if (type === FRAMEWORKS_FILTER_TYPE_FRAMEWORK) {
      if (value.operator === '!=') {
        updatedResult.frameworksNot = [...(updatedResult.frameworksNot || []), value.data];
      } else {
        updatedResult.frameworks = [...(updatedResult.frameworks || []), value.data];
      }
    }

    return updatedResult;
  }, {});
}

export function mapFiltersToUrlParams(filters) {
  const normalizedFilters = mapFiltersToGraphQLVariables(filters);
  const urlParams = {};

  if (normalizedFilters.project) {
    urlParams.project = normalizedFilters.project;
  }

  if (normalizedFilters.groupPath) {
    urlParams.group = normalizedFilters.groupPath;
  }

  const projectStatusFilter = filters.find(
    (filter) => filter.type === FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
  );

  if (projectStatusFilter) {
    urlParams.project_status = projectStatusFilter.value.data;
  }

  if (normalizedFilters.frameworks?.length > 0) {
    urlParams['framework[]'] = normalizedFilters.frameworks;
  }

  if (normalizedFilters.frameworksNot?.length > 0) {
    urlParams['not[framework][]'] = normalizedFilters.frameworksNot;
  }

  return urlParams;
}

export function mapQueryToFilters(queryParams) {
  const filters = [];
  const { project, group } = queryParams;
  const frameworks = queryParams['framework[]'];
  const notFrameworks = queryParams['not[framework][]'];
  const projectStatus = queryParams.project_status;

  const getFrameworkFilters = (params, operator) => {
    const frameworksArray = Array.isArray(params) ? params : [params];
    frameworksArray.forEach((framework) => {
      filters.push({
        type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
        value: { data: framework, operator },
      });
    });
  };

  if (frameworks) {
    getFrameworkFilters(frameworks, '=');
  }

  if (notFrameworks) {
    getFrameworkFilters(notFrameworks, '!=');
  }

  if (project) {
    filters.push({
      type: FRAMEWORKS_FILTER_TYPE_PROJECT,
      value: { data: project, operator: 'matches' },
    });
  }

  if (group) {
    filters.push({
      type: FRAMEWORKS_FILTER_TYPE_GROUP,
      value: { data: group, operator: 'matches' },
    });
  }

  if (projectStatus) {
    filters.push({
      type: FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
      value: { data: projectStatus, operator: '=' },
    });
  }

  return filters;
}

export const checkFilterForChange = ({
  currentFilters = {},
  newFilters = {},
  filterKeys = ['project', 'framework[]', 'not[framework][]', 'group', 'project_status'],
}) => {
  return filterKeys.some((key) => !isEqual(currentFilters[key], newFilters[key]));
};

export const checkGraphQLFilterForChange = ({ currentFilters = {}, newFilters = {} }) => {
  const filterKeys = [
    FRAMEWORKS_FILTER_TYPE_PROJECT,
    'frameworks',
    'frameworksNot',
    FRAMEWORKS_FILTER_TYPE_GROUP,
    'groupPath',
  ];

  return checkFilterForChange({ currentFilters, newFilters, filterKeys });
};

export function mapStandardsAdherenceQueryToFilters(filters) {
  const filterParams = {};

  const checkSearch = filters?.find((filter) => filter.type === 'check');
  filterParams.checkName = checkSearch?.value?.data ?? undefined;

  const standardSearch = filters?.find((filter) => filter.type === 'standard');
  filterParams.standard = standardSearch?.value?.data ?? undefined;

  const projectIdsSearch = filters?.find((filter) => filter.type === 'project');
  filterParams.projectIds = projectIdsSearch?.value?.data ?? undefined;

  return filterParams;
}

export const mergeAdditionalPolicies = (framework, additional) => {
  if (!additional) return framework;
  return {
    ...framework,
    securityPolicies: {
      nodes: [...framework.securityPolicies.nodes, ...additional.nodes],
      pageInfo: additional.pageInfo,
    },
  };
};

export const getPolicyUrl = (policy, groupPath, groupSecurityPoliciesPath) => {
  const fullPath = policy.source?.namespace?.fullPath;
  if (!fullPath) return groupSecurityPoliciesPath;
  if (fullPath !== groupPath || !groupSecurityPoliciesPath) {
    // eslint-disable-next-line @gitlab/no-hardcoded-urls
    return `/groups/${fullPath}/-/security/policies`;
  }
  // eslint-disable-next-line @gitlab/no-hardcoded-urls
  return `${groupSecurityPoliciesPath}/${policy.name}/edit?type=${policy.type}`;
};

export const isGraphqlFieldMissingError = (error, field) => {
  return Boolean(
    error?.graphQLErrors?.some((e) =>
      e?.message?.startsWith(`Field '${field}' doesn't exist on type`),
    ),
  );
};

export const getControls = (requirementControlNodes, complianceRequirementControls) => {
  if (!requirementControlNodes?.length) {
    return [];
  }
  try {
    return requirementControlNodes
      .map((control) => {
        if (!['internal', 'external'].includes(control.controlType)) {
          return null;
        }
        const matchingGitLabControl = complianceRequirementControls.find(
          (gitLabControl) => gitLabControl.id === control.name,
        );
        return {
          ...control,
          displayValue:
            control.controlType === 'external'
              ? control.externalControlName
              : matchingGitLabControl?.name || UNKNOWN_CONTROL_LABEL,
        };
      })
      .filter(Boolean);
  } catch (error) {
    return [];
  }
};
