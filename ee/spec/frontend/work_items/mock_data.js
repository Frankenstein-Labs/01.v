import { cloneDeep } from 'lodash-es';
import * as CE from 'jest/work_items/mock_data';

/*
 * We're disabling the import/export rule here because we want to
 * re-export the mock data from the CE file while also overriding
 * anything that's EE-specific.
 */
// eslint-disable-next-line import/export
export * from 'jest/work_items/mock_data';

// Add EE-specific fields to projectMembersAutocompleteResponseWithCurrentUser - override CE version
/* eslint-disable import/export */
export const projectMembersAutocompleteResponseWithCurrentUser = {
  data: {
    namespace: {
      ...CE.projectMembersAutocompleteResponseWithCurrentUser.data.namespace,
      users: CE.projectMembersAutocompleteResponseWithCurrentUser.data.namespace.users.map(
        (user) => ({
          ...user,
          status: {
            ...user.status,
          },
          duoStatus: {
            disabled: true,
            disabledReason: null,
            flowTriggerEvents: [],
          },
        }),
      ),
    },
  },
};

// Add EE-specific fields to projectMembersAutocompleteResponseWithoutCurrentUser - override CE version
export const projectMembersAutocompleteResponseWithoutCurrentUser = {
  data: {
    namespace: {
      ...CE.projectMembersAutocompleteResponseWithoutCurrentUser.data.namespace,
      users: CE.projectMembersAutocompleteResponseWithoutCurrentUser.data.namespace.users.map(
        (user) => ({
          ...user,
          status: {
            ...user.status,
          },
          duoStatus: {
            disabled: true,
            disabledReason: null,
            flowTriggerEvents: [],
          },
        }),
      ),
    },
  },
};
/* eslint-enable import/export */

/**
 * Adds a blockedWorkItems property to all userPermissions objects that have
 * __typename set to "WorkItemPermissions" at any level of a nested object.
 *
 * @param {Object} obj - The source object to process
 * @param {*} [blockedWorkItemsValue=false] - The value to set for blockedWorkItems property
 * @returns {Object} A new object with the blockedWorkItems property added where applicable
 */
const applyEEWorkItemPermissions = (obj, blockedWorkItemsValue = false) => {
  // Return early for null/undefined values or non-objects
  if (obj === null || obj === undefined || typeof obj !== 'object') {
    return obj;
  }

  // Handle arrays by mapping each element
  if (Array.isArray(obj)) {
    return obj.map((item) => applyEEWorkItemPermissions(item, blockedWorkItemsValue));
  }

  // Create a deep clone of the object to avoid mutation
  const result = cloneDeep(obj);

  // Check if current object is a userPermissions object with __typename === "WorkItemPermissions"
  if (
    result.userPermissions &&
    // eslint-disable-next-line no-underscore-dangle
    result.userPermissions.__typename === 'WorkItemPermissions' &&
    !Object.prototype.hasOwnProperty.call(result.userPermissions, 'blockedWorkItems')
  ) {
    // Add blockedWorkItems property
    result.userPermissions.blockedWorkItems = blockedWorkItemsValue;
  }

  // Process all properties recursively
  Object.keys(result).forEach((key) => {
    if (typeof result[key] === 'object' && result[key] !== null) {
      result[key] = applyEEWorkItemPermissions(result[key], blockedWorkItemsValue);
    }
  });

  return result;
};

export const mockWorkItemStatus = {
  id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/2',
  category: 'in_progress',
  name: 'In progress',
  description: null,
  iconName: 'status-running',
  color: '#1f75cb',
  position: 0,
  __typename: 'WorkItemStatus',
};

export const workItemObjectiveMetadataWidgetsEE = {
  HEALTH_STATUS: {
    type: 'HEALTH_STATUS',
    __typename: 'WorkItemWidgetHealthStatus',
    healthStatus: 'onTrack',
    rolledUpHealthStatus: [],
  },
  PROGRESS: {
    type: 'PROGRESS',
    __typename: 'WorkItemWidgetProgress',
    progress: 10,
    updatedAt: new Date(),
  },
  WEIGHT: {
    type: 'WEIGHT',
    weight: 1,
    rolledUpWeight: 0,
    __typename: 'WorkItemWidgetWeight',
  },
  ITERATION: {
    type: 'ITERATION',
    __typename: 'WorkItemWidgetIteration',
    iteration: {
      description: null,
      id: 'gid://gitlab/Iteration/1',
      iid: '12',
      title: 'Iteration title',
      startDate: '2023-12-19',
      dueDate: '2024-01-15',
      webUrl: '/groups/gitlab-org/-/iterations/1',
      updatedAt: new Date(),
      iterationCadence: {
        title: 'Iteration 101',
        __typename: 'IterationCadence',
      },
      __typename: 'Iteration',
    },
  },
  START_AND_DUE_DATE: {
    type: 'START_AND_DUE_DATE',
    dueDate: '2024-06-27',
    startDate: '2024-01-01',
    __typename: 'WorkItemWidgetStartAndDueDate',
  },
  STATUS: {
    type: 'STATUS',
    status: {
      ...mockWorkItemStatus,
    },
    __typename: 'WorkItemWidgetStatus',
  },
};

export const workItemTaskEE = {
  id: 'gid://gitlab/WorkItem/4',
  iid: '4',
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/5',
    name: 'Task',
    iconName: 'work-item-task',
    __typename: 'WorkItemType',
  },
  title: '_bar_',
  titleHtml: '_bar_',
  state: 'OPEN',
  confidential: false,
  reference: 'test-project-path#4',
  namespace: {
    __typename: 'Project',
    id: '1',
    fullPath: 'test-project-path',
    name: 'Project name',
  },
  createdAt: '2022-08-03T12:41:54Z',
  closedAt: null,
  webUrl: '/gitlab-org/gitlab-test/-/work_items/4',
  widgets: [
    workItemObjectiveMetadataWidgetsEE.WEIGHT,
    workItemObjectiveMetadataWidgetsEE.ITERATION,
    workItemObjectiveMetadataWidgetsEE.START_AND_DUE_DATE,
    workItemObjectiveMetadataWidgetsEE.STATUS,
  ],
  __typename: 'WorkItem',
};

export const workItemColorWidget = {
  id: 'gid://gitlab/WorkItem/1',
  iid: '1',
  title: 'Work _item_ epic 5',
  titleHtml: 'Work _item_ epic 5',
  namespace: {
    id: 'gid://gitlab/Group/1',
    fullPath: 'gitlab-org',
    name: 'Gitlab Org',
    __typename: 'Namespace',
  },
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/1',
    name: 'Epic',
    iconName: 'work-item-epic',
    __typename: 'WorkItemType',
  },
  widgets: [
    {
      color: '#1068bf',
      textColor: '#FFFFFF',
      type: 'COLOR',
      __typename: 'WorkItemWidgetColor',
    },
  ],
  __typename: 'WorkItem',
};

export const promoteToEpicMutationResponse = {
  data: {
    promoteToEpic: {
      epic: {
        id: 'gid://gitlab/Epic/225',
        webPath: '/groups/gitlab-org/-/epics/265',
        __typename: 'Epic',
      },
      errors: [],
      __typename: 'PromoteToEpicPayload',
    },
  },
};

export const namespaceWorkItemsWithoutEpicSupport = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/14',
      webUrl: 'http://127.0.0.1:3000/groups/flightjs',
      userPermissions: {
        setNewWorkItemMetadata: true,
      },
      workItemTypes: {
        nodes: [
          {
            id: 'gid://gitlab/WorkItems::Type/1',
            name: 'Issue',
            iconName: 'work-item-issue',
            supportedConversionTypes: [
              {
                id: 'gid://gitlab/WorkItems::Type/2',
                name: 'Incident',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/5',
                name: 'Task',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/3',
                name: 'Test Case',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/9',
                name: 'Ticket',
                __typename: 'WorkItemType',
              },
            ],
            widgetDefinitions: [
              {
                type: 'ASSIGNEES',
                allowsMultipleAssignees: true,
                canInviteMembers: false,
                __typename: 'WorkItemWidgetDefinitionAssignees',
              },
              {
                type: 'AWARD_EMOJI',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'CRM_CONTACTS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'CURRENT_USER_TODOS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'DESCRIPTION',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'DESIGNS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'DEVELOPMENT',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'EMAIL_PARTICIPANTS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'HIERARCHY',
                allowedChildTypes: {
                  nodes: [
                    {
                      id: 'gid://gitlab/WorkItems::Type/5',
                      name: 'Task',
                      __typename: 'WorkItemType',
                    },
                  ],
                  __typename: 'WorkItemTypeConnection',
                },
                allowedParentTypes: {
                  nodes: [
                    {
                      id: 'gid://gitlab/WorkItems::Type/8',
                      name: 'Epic',
                      __typename: 'WorkItemType',
                    },
                  ],
                  __typename: 'WorkItemTypeConnection',
                },
                __typename: 'WorkItemWidgetDefinitionHierarchy',
              },
              {
                type: 'ITERATION',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'LABELS',
                allowsScopedLabels: false,
                __typename: 'WorkItemWidgetDefinitionLabels',
              },
              {
                type: 'LINKED_ITEMS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'MILESTONE',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'NOTES',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'NOTIFICATIONS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'PARTICIPANTS',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'START_AND_DUE_DATE',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'TIME_TRACKING',
                __typename: 'WorkItemWidgetDefinitionGeneric',
              },
              {
                type: 'WEIGHT',
                __typename: 'WorkItemWidgetDefinitionWeight',
              },
              {
                type: 'CUSTOM_FIELDS',
                customFieldValues: [],
                __typename: 'WorkItemWidgetDefinitionCustomFields',
              },
            ],
            __typename: 'WorkItemType',
          },
        ],
        __typename: 'WorkItemTypeConnection',
      },
      __typename: 'Namespace',
    },
  },
};

/*
 * We're disabling the import/export rule here because we want to
 * re-export the mock data from the CE file while also overriding
 * anything that's EE-specific.
 */
/* eslint-disable import/export */
export const createWorkItemQueryResponse = (options) =>
  applyEEWorkItemPermissions(CE.createWorkItemQueryResponse(options), true);

export const createWorkItemQueryResponseWithFeatures = (widgets = []) => {
  const base = applyEEWorkItemPermissions(
    CE.createWorkItemQueryResponseWithFeatures(widgets),
    true,
  );
  Object.assign(base.data.namespace.workItem.features, {
    healthStatus: {
      healthStatus: null,
      rolledUpHealthStatus: [],
    },
    weight: {
      weight: 2,
      rolledUpWeight: 0,
      rolledUpCompletedWeight: 0,
    },
    color: {
      color: '#1068bf',
      textColor: '#FFFFFF',
    },
    progress: {
      progress: 0,
      updatedAt: null,
    },
    linkedItems: {
      blockedByCount: 0,
      blockingCount: 0,
    },
    iteration: {
      iteration: null,
    },
    startAndDueDate: {
      type: 'START_AND_DUE_DATE',
      startDate: null,
      dueDate: null,
      rollUp: false,
      isFixed: false,
    },
    status: {
      status: null,
      __typename: 'WorkItemWidgetStatus',
    },
    customFields: {
      customFieldValues: [],
      __typename: 'WorkItemWidgetCustomFields',
    },
  });
  return base;
};

export const workItemResponseFactory = (options) =>
  applyEEWorkItemPermissions(CE.workItemResponseFactory(options), true);

export const workItemByIidResponseFactory = (options) =>
  applyEEWorkItemPermissions(CE.workItemByIidResponseFactory(options), true);

export const mockMoveWorkItemMutationResponse = (config) =>
  applyEEWorkItemPermissions(CE.mockMoveWorkItemMutationResponse(config), true);

export const getIssueDetailsResponse = (config) =>
  applyEEWorkItemPermissions(CE.getIssueDetailsResponse(config), true);

export const linkedWorkItemResponse = (config, errors = []) =>
  applyEEWorkItemPermissions(CE.linkedWorkItemResponse(config, errors), true);

export const generateWorkItemsListWithId = (config) =>
  applyEEWorkItemPermissions(CE.generateWorkItemsListWithId(config), true);

export const updateWorkItemMutationResponseFactory = (config) =>
  applyEEWorkItemPermissions(CE.updateWorkItemMutationResponseFactory(config), true);

export const workItemQueryResponse = applyEEWorkItemPermissions(CE.workItemQueryResponse, true);

export const createWorkItemMutationResponse = applyEEWorkItemPermissions(
  CE.createWorkItemMutationResponse,
  true,
);

export const changeWorkItemParentMutationResponse = applyEEWorkItemPermissions(
  CE.changeWorkItemParentMutationResponse,
  true,
);

export const childrenWorkItems = applyEEWorkItemPermissions(CE.childrenWorkItems, true);

export const childrenWorkItemsObjectives = applyEEWorkItemPermissions(
  CE.childrenWorkItemsObjectives,
  true,
);

export const updateWorkItemMutationErrorResponse = applyEEWorkItemPermissions(
  CE.updateWorkItemMutationErrorResponse,
  true,
);

export const mockHierarchyWidget = applyEEWorkItemPermissions(CE.mockHierarchyWidget, true);

export const workItemHierarchyTreeResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyTreeResponse,
  true,
);

export const workItemTask = applyEEWorkItemPermissions(CE.workItemTask, true);

export const workItemObjectiveWithChild = applyEEWorkItemPermissions(
  CE.workItemObjectiveWithChild,
  true,
);

export const workItemObjectiveWithClosedChild = applyEEWorkItemPermissions(
  CE.workItemObjectiveWithClosedChild,
  true,
);

export const workItemEpic = applyEEWorkItemPermissions(CE.workItemEpic, true);

export const workItemHierarchyPaginatedTreeResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyPaginatedTreeResponse,
  true,
);

export const workItemHierarchyTreeFailureResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyTreeFailureResponse,
  true,
);

export const workItemHierarchyNoChildrenTreeResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyNoChildrenTreeResponse,
  true,
);

export const workItemHierarchyTreeSingleClosedItemResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyTreeSingleClosedItemResponse,
  true,
);

export const workItemWithParentAsChild = applyEEWorkItemPermissions(
  CE.workItemWithParentAsChild,
  true,
);

export const workItemHierarchyTreeEmptyResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyTreeEmptyResponse,
  true,
);

export const workItemHierarchyNoUpdatePermissionResponse = applyEEWorkItemPermissions(
  CE.workItemHierarchyNoUpdatePermissionResponse,
  true,
);
export const mockWorkItemCommentNote = applyEEWorkItemPermissions(CE.mockWorkItemCommentNote, true);

export const updateWorkItemMutationResponse = applyEEWorkItemPermissions(
  CE.updateWorkItemMutationResponse,
  true,
);

export const mockBlockedByLinkedItem = applyEEWorkItemPermissions(CE.mockBlockedByLinkedItem, true);

export const mockBlockedByOpenAndClosedLinkedItems = applyEEWorkItemPermissions(
  CE.mockBlockedByOpenAndClosedLinkedItems,
  true,
);

export const workItemBlockedByLinkedItemsResponse = applyEEWorkItemPermissions(
  CE.workItemBlockedByLinkedItemsResponse,
  true,
);

export const workItemsClosedAndOpenLinkedItemsResponse = applyEEWorkItemPermissions(
  CE.workItemsClosedAndOpenLinkedItemsResponse,
  true,
);

export const workItemNoBlockedByLinkedItemsResponse = applyEEWorkItemPermissions(
  CE.workItemNoBlockedByLinkedItemsResponse,
  true,
);

export const mockOpenChildrenCount = applyEEWorkItemPermissions(CE.mockOpenChildrenCount, true);

export const mockNoOpenChildrenCount = applyEEWorkItemPermissions(CE.mockNoOpenChildrenCount, true);

export const convertWorkItemMutationResponse = applyEEWorkItemPermissions(
  CE.convertWorkItemMutationResponse,
  true,
);

export const updateWorkItemNotificationsMutationResponse = applyEEWorkItemPermissions(
  CE.updateWorkItemNotificationsMutationResponse,
  true,
);

export const mockRolledUpHealthStatus = [
  {
    count: 1,
    healthStatus: 'onTrack',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
  {
    count: 0,
    healthStatus: 'needsAttention',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
  {
    count: 1,
    healthStatus: 'atRisk',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
];

export const workItemChangeTypeWidgets = {
  ITERATION: {
    type: 'ITERATION',
    iteration: {
      id: 'gid://gitlab/Iteration/86312',
      __typename: 'Iteration',
    },
    __typename: 'WorkItemWidgetIteration',
  },
  WEIGHT: {
    type: 'WEIGHT',
    weight: 1,
    __typename: 'WorkItemWidgetWeight',
  },
  PROGRESS: {
    type: 'PROGRESS',
    progress: 33,
    updatedAt: '2024-12-05T16:24:56Z',
    __typename: 'WorkItemWidgetProgress',
  },
  MILESTONE: {
    type: 'MILESTONE',
    __typename: 'WorkItemWidgetMilestone',
    milestone: {
      __typename: 'Milestone',
      id: 'gid://gitlab/Milestone/30',
      title: 'v4.0',
      state: 'active',
      expired: false,
      startDate: '2022-10-17',
      dueDate: '2022-10-24',
      webPath: '123',
      projectMilestone: true,
    },
  },
};
/* eslint-enable import/export */

const relatedVulnerabilitiesNodes = [
  {
    id: 'gid://gitlab/Vulnerability/727',
    state: 'DETECTED',
    severity: 'MEDIUM',
    name: "Improper Neutralization of Input During Web Page Generation ('Cross-site Scripting')",
    webUrl: '/vulnerabilities/727',
    __typename: 'Vulnerability',
  },
  {
    id: 'gid://gitlab/Vulnerability/688',
    state: 'CONFIRMED',
    severity: 'INFO',
    name: 'Loop with Unreachable Exit Condition (Infinite Loop)',
    webUrl: '/vulnerabilities/688',
    __typename: 'Vulnerability',
  },
];

export const getVulnerabilitiesWidgetResponse = (
  nodes = relatedVulnerabilitiesNodes,
  hasNextPage = false,
  useFeatures = false,
) => {
  const vulnerabilitiesWidget = {
    type: 'VULNERABILITIES',
    relatedVulnerabilities: {
      nodes,
      pageInfo: {
        hasPreviousPage: false,
        hasNextPage,
        endCursor: hasNextPage ? 'XYZ' : null,
        startCursor: null,
        __typename: 'PageInfo',
      },
      count: nodes.length,
      __typename: 'VulnerabilityConnection',
    },
    __typename: 'WorkItemWidgetVulnerabilities',
  };

  return {
    data: {
      namespace: {
        __typename: 'Namespace',
        id: 'gid://gitlab/Namespaces::ProjectNamespace/1',
        workItem: {
          __typename: 'WorkItem',
          id: 'gid://gitlab/WorkItem/1',
          iid: '1',
          namespace: {
            __typename: 'Project',
            id: '1',
          },
          widgets: useFeatures ? null : [vulnerabilitiesWidget],
          features: useFeatures
            ? { __typename: 'WorkItemFeatures', vulnerabilities: vulnerabilitiesWidget }
            : null,
        },
      },
    },
  };
};

export const vulnerabilitiesWidgetResponse = getVulnerabilitiesWidgetResponse();
export const emptyVulnerabilitiesWidgetResponse = getVulnerabilitiesWidgetResponse([]);
export const paginatedVulnerabilitiesWidgetResponse = getVulnerabilitiesWidgetResponse(
  relatedVulnerabilitiesNodes,
  true,
);

export const savedViewFiltersObject = {
  state: 'opened',
  confidential: true,
  subscribed: 'explicitly_subscribed',
  in: ['title'],
  search: 'ABC',
  myReactionEmoji: 'smile',
  closedBefore: '2025-01-01T00:00:00.000+00:00',
  closedAfter: '2025-01-01T00:00:00.000+00:00',
  iid: '123',
  dueBefore: '2025-01-01T00:00:00.000+00:00',
  dueAfter: '2025-01-01T00:00:00.000+00:00',
  createdBefore: '2025-01-01T00:00:00.000+00:00',
  createdAfter: '2025-01-01T00:00:00.000+00:00',
  updatedBefore: '2025-01-01T00:00:00.000+00:00',
  updatedAfter: '2025-01-01T00:00:00.000+00:00',
  excludeProjects: true,
  excludeGroupWorkItems: true,
  includeDescendants: true,
  healthStatusFilter: 'on_track',
  weight: '1',
  types: ['issue'],
  not: {
    myReactionEmoji: 'smile',
    healthStatusFilter: ['on_track'],
    weight: '1',
    types: ['epic', 'issue'],
    assigneeUsernames: ['root'],
    authorUsername: ['root'],
    iterationId: ['1'],
  },
  assigneeUsernames: ['root'],
  or: {
    assigneeUsernames: ['root'],
    authorUsernames: ['root'],
  },
  authorUsername: 'root',
  milestoneTitle: ['v0.0'],
  hierarchyFilters: {
    includeDescendantWorkItems: false,
  },
  fullPath: 'flightjs/Flight',
  customField: [
    {
      customFieldId: 'gid://gitlab/Issuables::CustomField/4',
      selectedOptionIds: ['gid://gitlab/Issuables::CustomFieldSelectOption/4'],
    },
    {
      customFieldId: 'gid://gitlab/Issuables::CustomField/4',
      selectedOptionIds: ['gid://gitlab/Issuables::CustomFieldSelectOption/6'],
    },
    {
      customFieldId: 'gid://gitlab/Issuables::CustomField/10',
      selectedOptionIds: [
        'gid://gitlab/Issuables::CustomFieldSelectOption/12',
        'gid://gitlab/Issuables::CustomFieldSelectOption/15',
      ],
    },
  ],
  iterationWildcardId: 'CURRENT',
  iterationCadenceId: ['gid://gitlab/Iterations::Cadence/1'],
  status: {
    name: "Won't do",
  },
};

export const savedViewFilterTokens = [
  { type: 'confidential', value: { data: 'yes', operator: '=' } },
  { type: 'subscribed', value: { data: 'EXPLICITLY_SUBSCRIBED', operator: '=' } },
  { type: 'in', value: { data: 'TITLE', operator: '=' } },
  { type: 'filtered-search-term', value: { data: 'ABC', operator: undefined } },
  { type: 'my-reaction', value: { data: 'smile', operator: '=' } },
  {
    type: 'closed',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '<',
    },
  },
  {
    type: 'closed',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '≥',
    },
  },
  {
    type: 'due-date',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '<',
    },
  },
  {
    type: 'due-date',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '≥',
    },
  },
  {
    type: 'created',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '<',
    },
  },
  {
    type: 'created',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '≥',
    },
  },
  {
    type: 'updated',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '<',
    },
  },
  {
    type: 'updated',
    value: {
      data: '2025-01-01T00:00:00.000+00:00',
      operator: '≥',
    },
  },
  { type: 'health', value: { data: 'onTrack', operator: '=' } },
  { type: 'weight', value: { data: '1', operator: '=' } },
  { type: 'type', value: { data: 'ISSUE', operator: '=' } },
  { type: 'my-reaction', value: { data: 'smile', operator: '!=' } },
  { type: 'health', value: { data: 'onTrack', operator: '!=' } },
  { type: 'weight', value: { data: '1', operator: '!=' } },
  { type: 'type', value: { data: ['EPIC', 'ISSUE'], operator: '!=' } },
  { type: 'assignee', value: { data: ['root'], operator: '!=' } },
  { type: 'author', value: { data: ['root'], operator: '!=' } },
  { type: 'iteration', value: { data: ['1'], operator: '!=' } },
  { type: 'assignee', value: { data: 'root', operator: '=' } },
  { type: 'assignee', value: { data: ['root'], operator: '||' } },
  { type: 'author', value: { data: ['root'], operator: '||' } },
  { type: 'author', value: { data: 'root', operator: '=' } },
  { type: 'milestone', value: { data: 'v0.0', operator: '=' } },
  { type: 'group', value: { data: 'flightjs/Flight', operator: '=' } },
  { type: 'iteration', value: { data: 'Current&1', operator: '=' } },
  { type: 'status', value: { data: "Won't do", operator: '=' } },
  {
    type: 'custom-field[4]',
    value: {
      data: '4',
      operator: '=',
    },
  },
  {
    type: 'custom-field[4]',
    value: {
      data: '6',
      operator: '=',
    },
  },
  {
    type: 'custom-field[10]',
    value: {
      data: '12',
      operator: '=',
    },
  },
  {
    type: 'custom-field[10]',
    value: {
      data: '15',
      operator: '=',
    },
  },
];

export const mockWorkItemTypeIconDefinitionsResponse = {
  data: {
    workItemTypeIconDefinitions: [
      {
        name: 'work-item-enhancement',
        label: 'Magic wand',
        __typename: 'WorkItemTypeIconDefinition',
      },
      { name: 'work-item-epic', label: 'Stack', __typename: 'WorkItemTypeIconDefinition' },
      { name: 'work-item-issue', label: 'Document', __typename: 'WorkItemTypeIconDefinition' },
      { name: 'work-item-task', label: 'Check', __typename: 'WorkItemTypeIconDefinition' },
      { name: 'bug', label: 'Insect', __typename: 'WorkItemTypeIconDefinition' },
    ],
  },
};

export const mockWorkItemTypeIcons =
  mockWorkItemTypeIconDefinitionsResponse.data.workItemTypeIconDefinitions;
