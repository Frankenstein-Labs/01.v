export const mockGroupPath = 'gitlab-org';
export const mockProjectPath = `${mockGroupPath}/some-project`;

export const mockIssueId = 'gid://gitlab/Issue/1';

export const mockIssue = {
  projectPath: mockProjectPath,
  iid: '1',
  groupPath: mockGroupPath,
  id: mockIssueId,
};

export const mockCadence1 = {
  id: 'gid://gitlab/Iterations::Cadence/1',
  title: 'Plan cadence',
};

export const mockCadence2 = {
  id: 'gid://gitlab/Iterations::Cadence/2',
  title: 'Automatic cadence',
};

export const mockIteration1 = {
  __typename: 'Iteration',
  id: 'gid://gitlab/Iteration/1',
  title: null,
  webUrl: 'http://gdk.test:3000/groups/gitlab-org/-/iterations/1',
  state: 'opened',
  startDate: '2021-10-05',
  dueDate: '2021-10-10',
  iterationCadence: mockCadence1,
};

export const mockIteration2 = {
  __typename: 'Iteration',
  id: 'gid://gitlab/Iteration/2',
  title: 'Awesome Iteration',
  webUrl: 'http://gdk.test:3000/groups/gitlab-org/-/iterations/2',
  state: 'opened',
  startDate: '2021-10-12',
  dueDate: '2021-10-17',
  iterationCadence: mockCadence2,
};

export const mockEpic1 = {
  __typename: 'Epic',
  id: 'gid://gitlab/Epic/1',
  iid: '1',
  title: 'Foobar Epic',
  webUrl: 'http://gdk.test:3000/groups/gitlab-org/-/epics/1',
  state: 'opened',
};

export const mockWorkItemEpic1 = {
  id: 'gid://gitlab/WorkItem/727',
  iid: '3',
  title: 'Work item Epic 1',
  webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/130',
  state: 'OPEN',
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/3284',
    name: 'Epic',
    __typename: 'WorkItemType',
  },
};

export const mockWorkItemEpic2 = {
  id: 'gid://gitlab/WorkItem/728',
  iid: '4',
  title: 'Work item Epic 2',
  webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/131',
  state: 'OPEN',
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/3284',
    name: 'Epic',
    __typename: 'WorkItemType',
  },
};

export const mockEpic2 = {
  __typename: 'Epic',
  id: 'gid://gitlab/Epic/2',
  iid: '2',
  title: 'Awesome Epic',
  webUrl: 'http://gdk.test:3000/groups/gitlab-org/-/epics/2',
  state: 'opened',
};

export const mockGroupIterationsResponse = {
  data: {
    namespace: {
      id: '1',
      attributes: {
        nodes: [mockIteration1, mockIteration2],
      },
      __typename: 'IterationConnection',
    },
    __typename: 'Group',
  },
};

export const mockGroupEpicsResponse = {
  data: {
    namespace: {
      id: '1',
      attributes: {
        nodes: [mockEpic1, mockEpic2],
      },
      __typename: 'EpicConnection',
    },
    __typename: 'Group',
  },
};

export const mockGroupWorkItemEpicsResponse = {
  data: {
    namespace: {
      id: '1',
      attributes: {
        nodes: [mockWorkItemEpic1, mockWorkItemEpic2],
      },
      __typename: 'EpicConnection',
    },
    __typename: 'Group',
  },
};

export const emptyGroupEpicsResponse = {
  data: {
    namespace: {
      id: '1',
      attributes: {
        nodes: [],
      },
      __typename: 'EpicConnection',
    },
    __typename: 'Group',
  },
};

export const mockCurrentIterationResponse1 = {
  data: {
    errors: [],
    namespace: {
      id: '1',
      issuable: {
        id: mockIssueId,
        attribute: mockIteration1,
        __typename: 'Issue',
      },
      __typename: 'Project',
    },
  },
};

export const mockCurrentIterationResponse2 = {
  data: {
    errors: [],
    namespace: {
      id: '1',
      issuable: {
        id: mockIssueId,
        attribute: mockIteration2,
        __typename: 'Issue',
      },
      __typename: 'Project',
    },
  },
};

export const noCurrentEpicResponse = {
  data: {
    namespace: {
      id: '1',
      issuable: {
        id: mockIssueId,
        hasEpic: false,
        hasParent: false,
        attribute: null,
        __typename: 'Issue',
      },
      __typename: 'Project',
    },
  },
};

export const currentEpicResponse = {
  data: {
    namespace: {
      id: '1',
      issuable: {
        id: mockIssueId,
        hasEpic: true,
        hasParent: false,
        attribute: mockEpic1,
        __typename: 'Issue',
      },
      __typename: 'Project',
    },
  },
};

export const currentEpicHasParentResponse = {
  data: {
    namespace: {
      id: '1',
      issuable: {
        id: mockIssueId,
        hasEpic: false,
        hasParent: true,
        attribute: null,
        __typename: 'Issue',
      },
      __typename: 'Project',
    },
  },
};

export const currentWorkItemEpicResponse = {
  data: {
    workItem: {
      id: 'gid://gitlab/Issue/1',
      widgets: [
        {
          type: 'HIERARCHY',
          parent: {
            id: 'gid://gitlab/WorkItem/3',
            title: 'Work Item Epic',
            webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/130',
            __typename: 'WorkItem',
          },
          __typename: 'WorkItemWidgetHierarchy',
        },
      ],
      __typename: 'WorkItem',
    },
  },
};

export const mockEpicUpdatesSubscriptionResponse = {
  data: {
    issuableEpicUpdated: null,
  },
};

export const noParentUpdatedResponse = {
  data: {
    workItem: {
      id: 'gid://gitlab/Issue/1',
      widgets: [{}],
      __typename: 'Project',
    },
  },
};

export const mockNoPermissionEpicResponse = {
  data: {
    namespace: {
      id: '1',
      issuable: {
        id: mockIssueId,
        hasEpic: true,
        hasParent: false,
        attribute: null,
        __typename: 'Issue',
      },
      __typename: 'Project',
    },
  },
};

export const mockEpicMutationResponse = {
  data: {
    issuableSetAttribute: {
      errors: [],
      issuable: {
        id: 'gid://gitlab/Issue/1',
        hasParent: false,
        attribute: {
          id: 'gid://gitlab/Epic/2',
          title: 'Awesome Epic',
          state: 'opened',
          __typename: 'Epic',
        },
        __typename: 'Issue',
      },
      __typename: 'IssueSetEpicPayload',
    },
  },
};

export const mockSetEpicNullMutationResponse = {
  data: {
    issuableSetAttribute: {
      errors: [],
      issuable: {
        id: 'gid://gitlab/Issue/1',
        hasParent: false,
        attribute: null,
        __typename: 'Issue',
      },
      __typename: 'IssueSetEpicPayload',
    },
  },
};

export const mockSetWorkItemEpicNullMutationResponse = {
  data: {
    issuableSetAttribute: {
      workItem: {
        id: 'gid://gitlab/WorkItem/1',
        widgets: [
          {
            type: 'HIERARCHY',
            parent: null,
            __typename: 'WorkItemWidgetHierarchy',
          },
        ],
        __typename: 'WorkItem',
      },
      errors: [],
      __typename: 'WorkItemUpdatePayload',
    },
  },
};

export const mockWorkItemEpicMutationResponse = {
  data: {
    issuableSetAttribute: {
      workItem: {
        id: 'gid://gitlab/Issue/1',
        widgets: [
          {
            type: 'HIERARCHY',
            parent: {
              id: 'gid://gitlab/WorkItem/4',
              title: 'Work Item Epic 2',
              webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/131',
              __typename: 'WorkItem',
            },
            __typename: 'WorkItemWidgetHierarchy',
          },
        ],
        __typename: 'WorkItem',
      },
      errors: [],
      __typename: 'WorkItemUpdatePayload',
    },
  },
};

export const issueNoWeightResponse = () => ({
  data: {
    namespace: {
      id: '1',
      issuable: { id: mockIssueId, weight: null, __typename: 'Issue' },
      __typename: 'Project',
    },
  },
});

export const issueWeightResponse = (weight = 0) => ({
  data: {
    namespace: {
      id: '1',
      issuable: { id: mockIssueId, weight, __typename: 'Issue' },
      __typename: 'Project',
    },
  },
});

export const setWeightResponse = (weight = 2) => ({
  data: {
    issuableSetWeight: {
      issuable: { id: mockIssueId, weight, __typename: 'Issue' },
      errors: [],
      __typename: 'Project',
    },
  },
});

export const removeWeightResponse = () => ({
  data: {
    issuableSetWeight: {
      issuable: { id: mockIssueId, weight: null, __typename: 'Issue' },
      errors: [],
      __typename: 'Project',
    },
  },
});

export const issueWeightSubscriptionResponse = () => ({
  data: {
    issuableWeightUpdated: {
      issue: {
        id: 'gid://gitlab/Issue/4',
        weight: 1,
      },
    },
  },
});

export const getHealthStatusMutationResponse = ({ healthStatus = null }) => {
  return {
    data: {
      updateIssue: {
        issuable: { id: 'gid://gitlab/Issue/1', healthStatus, __typename: 'Issue' },
        errors: [],
        __typename: 'UpdateIssuePayload',
      },
    },
  };
};

export const getHealthStatusQueryResponse = ({ state = 'opened', healthStatus = null }) => {
  return {
    data: {
      namespace: {
        id: '1',
        issuable: { id: 'gid://gitlab/Issue/1', state, healthStatus, __typename: 'Issue' },
        __typename: 'Project',
      },
    },
  };
};

export const mockGetMergeRequestReviewers = {
  data: {
    namespace: {
      id: 'gid://gitlab/Project/1',
      issuable: {
        id: 'gid://gitlab/MergeRequest/1',
        reviewers: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              avatarUrl: 'image',
              name: 'User',
              username: 'username',
              webUrl: 'https://example.com/username',
              webPath: '/username',
              status: null,
              type: 'human',
              mergeRequestInteraction: {
                canMerge: true,
                canUpdate: true,
                approved: true,
                reviewState: 'APPROVED',
                applicableApprovalRules: [{ id: 'gid://gitlab/ApprovalMergeRequestRule/1' }],
              },
            },
          ],
        },
        userPermissions: { adminMergeRequest: true },
      },
    },
  },
};
