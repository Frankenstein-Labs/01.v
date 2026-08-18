import timezoneMock from 'timezone-mock';
import { ApolloError } from '@apollo/client/core';
import * as utils from 'ee/compliance_dashboard/utils';
import {
  FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
  FRAMEWORKS_FILTER_TYPE_PROJECT,
  FRAMEWORKS_FILTER_TYPE_GROUP,
  FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
} from 'ee/compliance_dashboard/constants';

jest.mock('ee/audit_events/constants', () => ({
  CURRENT_DATE: new Date('2022 2 28'),
}));

describe('compliance report utils', () => {
  const projectIds = ['1', '2'];
  const projectGraphQlIds = ['gid://gitlab/Project/1', 'gid://gitlab/Project/2'];

  describe('isTopLevelGroup', () => {
    const rootGroupPath = '/root';
    const childGroupPath = '/root/child';
    const otherGroupPath = '/other';

    it('returns true for root group', () => {
      expect(utils.isTopLevelGroup(rootGroupPath, rootGroupPath)).toBe(true);
    });

    it('returns false for child group', () => {
      expect(utils.isTopLevelGroup(rootGroupPath, childGroupPath)).toBe(false);
    });

    it('returns false for other group', () => {
      expect(utils.isTopLevelGroup(rootGroupPath, otherGroupPath)).toBe(false);
    });
  });

  describe('parseViolationsQueryFilter', () => {
    it('returns the expected result', () => {
      const query = {
        projectIds,
        mergedAfter: '2021-12-06',
        mergedBefore: '2022-01-06',
        someExtraParam: 'someExtraParamValue',
        targetBranch: 'target-branch',
      };

      expect(utils.parseViolationsQueryFilter(query)).toStrictEqual({
        projectIds: projectGraphQlIds,
        mergedAfter: query.mergedAfter,
        mergedBefore: query.mergedBefore,
        targetBranch: query.targetBranch,
      });
    });

    describe('given a negative UTC timezone', () => {
      beforeAll(() => {
        timezoneMock.register('US/Pacific');
      });

      afterAll(() => {
        timezoneMock.unregister();
      });

      // See https://gitlab.com/gitlab-org/gitlab/-/issues/367675#note_1025545194
      it('ignores the users timezone and uses base UTC for the date', () => {
        const query = {
          projectIds,
          mergedAfter: '2021-12-06',
          mergedBefore: '2022-01-06',
          targetBranch: 'foo',
        };

        expect(utils.parseViolationsQueryFilter(query)).toStrictEqual({
          projectIds: projectGraphQlIds,
          mergedAfter: query.mergedAfter,
          mergedBefore: query.mergedBefore,
          targetBranch: query.targetBranch,
        });
      });
    });
  });

  describe('convertProjectIdsToGraphQl', () => {
    it('returns the expected result', () => {
      expect(utils.convertProjectIdsToGraphQl(projectIds)).toStrictEqual(projectGraphQlIds);
    });
  });

  describe('convertFrameworkIdToGraphQl', () => {
    it('should convert normal id to GraphQl compliance framework id', () => {
      const frameworkId = '123';
      expect(utils.convertFrameworkIdToGraphQl(frameworkId)).toBe(
        'gid://gitlab/ComplianceManagement::Framework/123',
      );
    });
  });

  describe('buildDefaultViolationsFilterParams', () => {
    it('returns the expected result with the default date range of 30 days', () => {
      const queryString = 'projectIds[]=20';

      expect(utils.buildDefaultViolationsFilterParams(queryString)).toStrictEqual({
        mergedAfter: '2022-01-29',
        mergedBefore: '2022-02-28',
        projectIds: ['20'],
      });
    });

    it('return the expected result when the query contains dates', () => {
      const queryString =
        'mergedAfter=2022-02-09&mergedBefore=2022-03-11&projectIds[]=20&tab=violations&targetBranch=foo';

      expect(utils.buildDefaultViolationsFilterParams(queryString)).toStrictEqual({
        mergedAfter: '2022-02-09',
        mergedBefore: '2022-03-11',
        projectIds: ['20'],
        tab: 'violations',
        targetBranch: 'foo',
      });
    });
  });

  describe('mapFiltersToUrlParams', () => {
    it('returns empty object when filters is empty', () => {
      expect(utils.mapFiltersToUrlParams([])).toEqual({});
    });

    it('maps filters to url params', () => {
      const filters = [
        { type: FRAMEWORKS_FILTER_TYPE_PROJECT, value: { data: 'my-project' } },
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework1' } },
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework2' } },
        { type: FRAMEWORKS_FILTER_TYPE_GROUP, value: { data: 'my-group' } },
      ];
      expect(utils.mapFiltersToUrlParams(filters)).toEqual({
        project: 'my-project',
        group: 'my-group',
        'framework[]': ['my-framework1', 'my-framework2'],
      });
    });

    it('maps frameworkExclude when operator is not equals', () => {
      const filters = [
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework', operator: '!=' } },
      ];
      expect(utils.mapFiltersToUrlParams(filters)).toEqual({
        'not[framework][]': ['my-framework'],
      });
    });

    it('maps frameworkExclude when operator is equals', () => {
      const filters = utils.mapQueryToFilters({
        project: 'my-project',
        'not[framework][]': ['my-framework1', 'my-framework2'],
      });

      expect(filters).toEqual([
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework1', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework2', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          value: { data: 'my-project', operator: 'matches' },
        },
      ]);
    });

    it('maps project_status filter when present', () => {
      const filters = [
        { type: FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS, value: { data: 'archived', operator: '=' } },
      ];
      expect(utils.mapFiltersToUrlParams(filters)).toEqual({
        project_status: 'archived',
      });
    });
  });

  describe('mapQueryToFilters', () => {
    it('returns empty array when query params are empty', () => {
      expect(utils.mapQueryToFilters({})).toEqual([]);
    });

    it('maps query params to filters', () => {
      const queryParams = {
        project: 'my-project',
        group: 'my-group',
        'framework[]': ['my-framework1', 'my-framework2'],
      };
      expect(utils.mapQueryToFilters(queryParams)).toEqual([
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework1', operator: '=' } },
        { type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK, value: { data: 'my-framework2', operator: '=' } },
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          value: { data: 'my-project', operator: 'matches' },
        },
        { type: FRAMEWORKS_FILTER_TYPE_GROUP, value: { data: 'my-group', operator: 'matches' } },
      ]);
    });

    it('maps frameworkExclude when query param is set', () => {
      const queryParams = { 'not[framework][]': ['my-framework1', 'my-framework2'] };
      expect(utils.mapQueryToFilters(queryParams)).toEqual([
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework1', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'my-framework2', operator: '!=' },
        },
      ]);
    });

    it('maps project_status filter when query param is set', () => {
      const queryParams = { project_status: 'archived' };
      expect(utils.mapQueryToFilters(queryParams)).toEqual([
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
          value: { data: 'archived', operator: '=' },
        },
      ]);
    });
  });

  describe('checkFilterForChange', () => {
    it('returns false when both filters are empty', () => {
      expect(utils.checkFilterForChange({ currentFilters: [], newFilters: [] })).toBe(false);
    });

    it('returns true when project filter has changed', () => {
      const currentFilters = {
        project: 'framework 1',
        framework: '',
        project_status: 'non-archived',
      };
      const newFilters = { project: 'framework 2', framework: '', project_status: 'non-archived' };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when framework filter has changed', () => {
      const currentFilters = { project: '', 'framework[]': ['old-framework'] };
      const newFilters = {
        project: '',
        framework: ['old-framework', 'new-framework'],
        project_status: 'non-archived',
      };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when group filter has changed', () => {
      const currentFilters = { project: '', 'framework[]': ['old-framework'], group: 'old-group' };
      const newFilters = {
        ...currentFilters,
        group: 'new-group',
      };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when frameworkExclude filter has changed', () => {
      const currentFilters = {
        project: '',
        'framework[]': ['current-framework'],
      };
      const newFilters = { project: '', 'not[framework][]': ['current-framework'] };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when project_status filter has changed', () => {
      const currentFilters = {
        project: '',
        project_status: undefined,
      };
      const newFilters = { project: '', project_status: 'archived' };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns false when filters have not changed', () => {
      const currentFilters = {
        project: '',
        framework: 'current-framework',
        project_status: 'non-archived',
      };
      const newFilters = {
        project: '',
        framework: 'current-framework',
        project_status: 'non-archived',
      };
      expect(utils.checkFilterForChange({ currentFilters, newFilters })).toBe(false);
    });
  });

  describe('checkGraphQLFilterForChange', () => {
    it('returns false when both filters are empty', () => {
      expect(utils.checkGraphQLFilterForChange({ currentFilters: {}, newFilters: {} })).toBe(false);
    });

    it('returns true when current filters are empty', () => {
      const currentFilters = {};
      const newFilters = { project: 'new-project' };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when new filters are empty', () => {
      const currentFilters = { project: 'old-project' };
      const newFilters = {};
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when project filter has changed', () => {
      const currentFilters = { project: 'old-project' };
      const newFilters = { project: 'new-project' };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when frameworks filter has changed', () => {
      const currentFilters = { frameworks: ['old-framework'] };
      const newFilters = { frameworks: ['new-framework'] };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when frameworksNot filter has changed', () => {
      const currentFilters = { frameworksNot: ['old-framework'] };
      const newFilters = { frameworksNot: ['new-framework'] };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns true when group filter has changed', () => {
      const currentFilters = { groupPath: 'old-group' };
      const newFilters = { groupPath: 'new-group' };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(true);
    });

    it('returns false when filters have not changed', () => {
      const currentFilters = {
        project: 'same-project',
        frameworks: ['same-framework'],
        frameworksNot: ['same-framework-not'],
        group: 'same-group',
      };
      const newFilters = { ...currentFilters };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(false);
    });

    it('returns false when non-relevant filters have changed', () => {
      const currentFilters = {
        project: 'same-project',
        frameworks: ['same-framework'],
        otherFilter: 'old-value',
      };
      const newFilters = {
        project: 'same-project',
        frameworks: ['same-framework'],
        otherFilter: 'new-value',
      };
      expect(utils.checkGraphQLFilterForChange({ currentFilters, newFilters })).toBe(false);
    });
  });

  describe('isGraphqlFieldMissingError', () => {
    const graphqlError = new ApolloError({
      graphQLErrors: [
        {
          message: "Field 'foo' doesn't exist on type 'Project'",
        },
      ],
    });

    it('returns true when error looks like graphql one and references correct field', () => {
      expect(utils.isGraphqlFieldMissingError(graphqlError, 'foo')).toBe(true);
    });

    it('returns false when error looks like graphql one but references other field', () => {
      expect(utils.isGraphqlFieldMissingError(graphqlError, 'bar')).toBe(false);
    });
    it('returns false for other errors', () => {
      expect(utils.isGraphqlFieldMissingError(new Error('test'), 'foo')).toBe(false);
    });
  });

  describe('getControls', () => {
    it.each([[], null, undefined])(
      'returns empty array when requirementControlNodes is %p',
      (requirementControlNodes) => {
        expect(utils.getControls(requirementControlNodes, [])).toEqual([]);
      },
    );

    it('filters out controls with unsupported control types', () => {
      const requirementControlNodes = [
        { name: 'control1', controlType: 'internal' },
        { name: 'control2', controlType: 'unsupported' },
        { name: 'control3', controlType: 'external', externalUrl: 'https://example.com' },
      ];
      const complianceRequirementControls = [];

      const result = utils.getControls(requirementControlNodes, complianceRequirementControls);

      expect(result).toHaveLength(2);
      expect(result[0].name).toBe('control1');
      expect(result[1].name).toBe('control3');
    });

    it('sets displayValue to external control URL label for external controls', () => {
      const externalUrl = 'https://example.com';
      const externalControlName = 'External control';
      const requirementControlNodes = [
        { name: 'control1', controlType: 'external', externalUrl, externalControlName },
      ];
      const complianceRequirementControls = [];

      const result = utils.getControls(requirementControlNodes, complianceRequirementControls);

      expect(result[0].displayValue).toBe(externalControlName);
    });

    it('sets displayValue to matching GitLab control name for internal controls', () => {
      const controlName = 'control-id';
      const gitLabControlName = 'GitLab Control Name';
      const requirementControlNodes = [{ name: controlName, controlType: 'internal' }];
      const complianceRequirementControls = [{ id: controlName, name: gitLabControlName }];

      const result = utils.getControls(requirementControlNodes, complianceRequirementControls);

      expect(result[0].displayValue).toBe(gitLabControlName);
    });

    it('sets displayValue to unknown label when no matching GitLab control found', () => {
      const requirementControlNodes = [{ name: 'nonexistent-control', controlType: 'internal' }];
      const complianceRequirementControls = [
        { id: 'different-control', name: 'Different Control' },
      ];

      const result = utils.getControls(requirementControlNodes, complianceRequirementControls);

      expect(result[0].displayValue).toBe('Unknown');
    });

    it('returns empty array when an error occurs', () => {
      const requirementControlNodes = 'not-an-array'; // This will cause an error
      const complianceRequirementControls = [];

      expect(utils.getControls(requirementControlNodes, complianceRequirementControls)).toEqual([]);
    });

    it('handles mixed internal and external controls correctly', () => {
      const internalControlId = 'internal-control';
      const internalControlName = 'Internal Control';
      const externalUrl = 'https://example.com';
      const externalControlName = 'External control';

      const requirementControlNodes = [
        { name: internalControlId, controlType: 'internal' },
        { name: 'external-control', controlType: 'external', externalUrl, externalControlName },
        { name: 'unknown-internal', controlType: 'internal' },
      ];

      const complianceRequirementControls = [{ id: internalControlId, name: internalControlName }];

      const result = utils.getControls(requirementControlNodes, complianceRequirementControls);

      expect(result).toHaveLength(3);
      expect(result[0].displayValue).toBe(internalControlName);
      expect(result[1].displayValue).toBe(externalControlName);
      expect(result[2].displayValue).toBe('Unknown');
    });
  });

  describe('mapFiltersToGraphQLVariables', () => {
    it('returns an empty object when no filters are provided', () => {
      expect(utils.mapFiltersToGraphQLVariables([])).toStrictEqual({});
    });

    it('correctly processes project filter', () => {
      const filters = [
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          value: { data: 'project-1' },
        },
      ];

      expect(utils.mapFiltersToGraphQLVariables(filters)).toStrictEqual({
        project: 'project-1',
      });
    });

    it('correctly processes group filter', () => {
      const filters = [
        {
          type: FRAMEWORKS_FILTER_TYPE_GROUP,
          value: { data: 'group-1' },
        },
      ];

      expect(utils.mapFiltersToGraphQLVariables(filters)).toStrictEqual({
        groupPath: 'group-1',
      });
    });

    it('correctly processes framework include filters', () => {
      const filters = [
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-1', operator: '=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-2', operator: '=' },
        },
      ];

      expect(utils.mapFiltersToGraphQLVariables(filters)).toStrictEqual({
        frameworks: ['framework-1', 'framework-2'],
      });
    });

    it('correctly processes framework exclude filters', () => {
      const filters = [
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-1', operator: '!=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-2', operator: '!=' },
        },
      ];

      expect(utils.mapFiltersToGraphQLVariables(filters)).toStrictEqual({
        frameworksNot: ['framework-1', 'framework-2'],
      });
    });

    it('correctly processes mixed framework filters', () => {
      const filters = [
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-1', operator: '=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-2', operator: '!=' },
        },
      ];

      expect(utils.mapFiltersToGraphQLVariables(filters)).toStrictEqual({
        frameworks: ['framework-1'],
        frameworksNot: ['framework-2'],
      });
    });

    it('correctly processes all filter types together', () => {
      const filters = [
        {
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          value: { data: 'project-1' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_GROUP,
          value: { data: 'group-1' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-1', operator: '=' },
        },
        {
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          value: { data: 'framework-2', operator: '!=' },
        },
      ];

      expect(utils.mapFiltersToGraphQLVariables(filters)).toStrictEqual({
        project: 'project-1',
        groupPath: 'group-1',
        frameworks: ['framework-1'],
        frameworksNot: ['framework-2'],
      });
    });
  });

  describe('mergeAdditionalPolicies', () => {
    const baseFramework = {
      id: '1',
      name: 'Framework A',
      securityPolicies: {
        nodes: [{ type: 'approval_policy', name: 'Policy 1' }],
        pageInfo: { hasNextPage: true, endCursor: 'cursor1' },
      },
    };

    it('returns the framework unchanged when additional is null', () => {
      expect(utils.mergeAdditionalPolicies(baseFramework, null)).toBe(baseFramework);
    });

    it('returns the framework unchanged when additional is undefined', () => {
      expect(utils.mergeAdditionalPolicies(baseFramework, undefined)).toBe(baseFramework);
    });

    it('merges additional nodes into securityPolicies', () => {
      const additional = {
        nodes: [{ type: 'scan_execution_policy', name: 'Policy 2' }],
        pageInfo: { hasNextPage: false, endCursor: 'cursor2' },
      };

      expect(utils.mergeAdditionalPolicies(baseFramework, additional)).toStrictEqual({
        ...baseFramework,
        securityPolicies: {
          nodes: [...baseFramework.securityPolicies.nodes, ...additional.nodes],
          pageInfo: additional.pageInfo,
        },
      });
    });

    it('uses pageInfo from additional, not from the base framework', () => {
      const additional = {
        nodes: [],
        pageInfo: { hasNextPage: false, endCursor: null },
      };

      const result = utils.mergeAdditionalPolicies(baseFramework, additional);

      expect(result.securityPolicies.pageInfo).toStrictEqual(additional.pageInfo);
    });

    it('does not mutate the original framework', () => {
      const additional = {
        nodes: [{ type: 'scan_execution_policy', name: 'Policy 2' }],
        pageInfo: { hasNextPage: false, endCursor: 'cursor2' },
      };
      const originalNodes = [...baseFramework.securityPolicies.nodes];

      utils.mergeAdditionalPolicies(baseFramework, additional);

      expect(baseFramework.securityPolicies.nodes).toStrictEqual(originalNodes);
    });
  });

  describe('getPolicyUrl', () => {
    const GROUP_PATH = 'my-org';
    const GROUP_POLICIES_PATH = `/groups/${GROUP_PATH}/-/security/policies`;
    const PARENT_GROUP_PATH = 'parent-org';

    const makePolicy = ({ fullPath, name = 'my-policy', type = 'scan_execution_policy' }) => ({
      name,
      type,
      source: fullPath ? { namespace: { fullPath } } : {},
    });

    it('returns the group security policies path when source namespace is missing', () => {
      const policy = makePolicy({ fullPath: null });
      expect(utils.getPolicyUrl(policy, GROUP_PATH, GROUP_POLICIES_PATH)).toBe(GROUP_POLICIES_PATH);
    });

    it('returns the group security policies path when source namespace fullPath is undefined', () => {
      const policy = { name: 'my-policy', type: 'scan_execution_policy', source: {} };
      expect(utils.getPolicyUrl(policy, GROUP_PATH, GROUP_POLICIES_PATH)).toBe(GROUP_POLICIES_PATH);
    });

    it('returns the source group policies index when the policy belongs to a different group', () => {
      const policy = makePolicy({ fullPath: PARENT_GROUP_PATH });
      expect(utils.getPolicyUrl(policy, GROUP_PATH, GROUP_POLICIES_PATH)).toBe(
        `/groups/${PARENT_GROUP_PATH}/-/security/policies`,
      );
    });

    it('returns the source group policies index when groupSecurityPoliciesPath is not provided', () => {
      const policy = makePolicy({ fullPath: GROUP_PATH });
      expect(utils.getPolicyUrl(policy, GROUP_PATH, undefined)).toBe(
        `/groups/${GROUP_PATH}/-/security/policies`,
      );
    });

    it('returns the policy edit URL when the policy belongs to the current group', () => {
      const policy = makePolicy({ fullPath: GROUP_PATH });
      expect(utils.getPolicyUrl(policy, GROUP_PATH, GROUP_POLICIES_PATH)).toBe(
        `${GROUP_POLICIES_PATH}/my-policy/edit?type=scan_execution_policy`,
      );
    });
  });
});
