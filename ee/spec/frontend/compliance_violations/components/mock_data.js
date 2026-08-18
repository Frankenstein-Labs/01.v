export const violationId = '123';
export const complianceCenterPath = 'mock/compliance-center';

export const mockComplianceViolation = {
  id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
  status: 'IN_REVIEW',
  createdAt: '2025-06-16T02:20:41Z',
  complianceControl: {
    id: 'gid://gitlab/ComplianceManagement::ComplianceControl/1',
    name: 'Test Control',
    complianceRequirement: {
      id: 'gid://gitlab/ComplianceManagement::ComplianceRequirement/1',
      name: 'Test Requirement',
      framework: {
        id: 'gid://gitlab/ComplianceManagement::Framework/1',
        color: '#1f75cb',
        default: false,
        name: 'Test Framework',
        description: 'Test framework description',
      },
    },
  },
  issues: {
    nodes: [
      {
        id: '1',
        iid: '1',
        reference: '#1',
        referencePath: 'gitlab-org/gitlab-test#1',
        state: 'opened',
        title: 'Test',
        webUrl: 'https://localhost:3000/gitlab/org/gitlab-test/-/issues/1',
      },
    ],
  },
  project: {
    id: 'gid://gitlab/Project/2',
    nameWithNamespace: 'GitLab.org / GitLab Test',
    fullPath: '/gitlab/org/gitlab-test',
    webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
    __typename: 'Project',
  },
  auditEvent: {
    id: 'gid://gitlab/AuditEvents::ProjectAuditEvent/467',
    eventName: 'merge_request_merged',
    targetId: '2',
    targetType: 'MergeRequest',
    details: '{}',
    ipAddress: '123.1.1.9',
    entityPath: 'gitlab-org/gitlab-test',
    entityId: '2',
    entityType: 'Project',
    createdAt: '2023-01-01T00:00:00Z',
    author: {
      id: 'gid://gitlab/User/1',
      name: 'John Doe',
    },
    project: {
      id: 'gid://gitlab/Project/2',
      name: 'Test project',
      fullPath: 'gitlab-org/gitlab-test',
      webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
    },
    group: null,
    user: {
      id: 'gid://gitlab/User/1',
      name: 'John Doe',
    },
  },
  discussions: {
    nodes: [
      {
        id: 'gid://gitlab/Discussion/1',
        notes: {
          nodes: [
            {
              id: 'gid://gitlab/Note/1',
              body: 'Status changed to resolved',
              bodyHtml: '<p>Status changed to resolved</p>',
              createdAt: '2025-06-17T10:00:00Z',
              lastEditedAt: null,
              lastEditedBy: null,
              author: {
                id: 'gid://gitlab/User/1',
                avatarUrl: 'https://example.com/avatar.png',
                name: 'Test User',
                username: 'testuser',
                webUrl: 'https://example.com/testuser',
                webPath: '/testuser',
                __typename: 'UserCore',
              },
              awardEmoji: {
                nodes: [],
              },
              discussion: {
                id: 'gid://gitlab/Discussion/1',
                __typename: 'Discussion',
              },
              systemNoteIconName: 'status',
              system: true,
              internal: false,
              __typename: 'Note',
            },
          ],
          __typename: 'NoteConnection',
        },
        __typename: 'Discussion',
      },
      {
        id: 'gid://gitlab/Discussion/2',
        notes: {
          nodes: [
            {
              id: 'gid://gitlab/Note/2',
              body: 'Violation reviewed',
              bodyHtml: '<p>Violation reviewed</p>',
              createdAt: '2025-06-16T15:30:00Z',
              lastEditedAt: '2025-06-16T16:00:00Z',
              lastEditedBy: {
                id: 'gid://gitlab/User/2',
                avatarUrl: 'https://example.com/avatar2.png',
                name: 'Test User 2',
                username: 'testuser2',
                webUrl: 'https://example.com/testuser2',
                webPath: '/testuser2',
                __typename: 'UserCore',
              },
              author: {
                id: 'gid://gitlab/User/2',
                avatarUrl: 'https://example.com/avatar2.png',
                name: 'Test User 2',
                username: 'testuser2',
                webUrl: 'https://example.com/testuser2',
                webPath: '/testuser2',
                __typename: 'UserCore',
              },
              awardEmoji: {
                nodes: [],
              },
              discussion: {
                id: 'gid://gitlab/Discussion/2',
                __typename: 'Discussion',
              },
              systemNoteIconName: null,
              system: false,
              internal: false,
              __typename: 'Note',
            },
          ],
          __typename: 'NoteConnection',
        },
        __typename: 'Discussion',
      },
    ],
    __typename: 'DiscussionConnection',
  },
  __typename: 'ComplianceManagement::Projects::ComplianceViolation',
};

export const mockComplianceViolationData = {
  data: {
    projectComplianceViolation: mockComplianceViolation,
  },
};

export const mockUpdateResponseData = {
  data: {
    updateProjectComplianceViolation: {
      clientMutationId: null,
      errors: [],
      complianceViolation: {
        status: 'RESOLVED',
        __typename: 'ComplianceManagement::Projects::ComplianceViolation',
      },
      __typename: 'UpdateProjectComplianceViolationPayload',
    },
  },
};

export const mockGraphQlError = jest.fn().mockRejectedValue(new Error('GraphQL error'));

export const mockDataWithoutAuditEvent = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      auditEvent: null,
    },
  },
};

export const mockDataWithoutNotes = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      discussions: {
        nodes: [],
        __typename: 'DiscussionConnection',
      },
    },
  },
};

export const mockDataWithNullNotes = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      discussions: null,
    },
  },
};

export const mockDataWithOnlyNonSystemNotes = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      discussions: {
        nodes: [
          {
            id: 'gid://gitlab/Discussion/3',
            notes: {
              nodes: [
                {
                  id: 'gid://gitlab/Note/3',
                  body: 'Regular comment',
                  bodyHtml: '<p>Regular comment</p>',
                  createdAt: '2025-06-16T12:00:00Z',
                  lastEditedAt: null,
                  lastEditedBy: null,
                  author: {
                    id: 'gid://gitlab/User/3',
                    avatarUrl: 'https://example.com/avatar3.png',
                    name: 'Test User 3',
                    username: 'testuser3',
                    webUrl: 'https://example.com/testuser3',
                    webPath: '/testuser3',
                    __typename: 'UserCore',
                  },
                  awardEmoji: {
                    nodes: [],
                  },
                  discussion: {
                    id: 'gid://gitlab/Discussion/3',
                    __typename: 'Discussion',
                  },
                  systemNoteIconName: null,
                  system: false,
                  internal: false,
                  __typename: 'Note',
                },
              ],
              __typename: 'NoteConnection',
            },
            __typename: 'Discussion',
          },
          {
            id: 'gid://gitlab/Discussion/4',
            notes: {
              nodes: [
                {
                  id: 'gid://gitlab/Note/4',
                  body: 'Another regular comment',
                  bodyHtml: '<p>Another regular comment</p>',
                  createdAt: '2025-06-16T13:00:00Z',
                  lastEditedAt: null,
                  lastEditedBy: null,
                  author: {
                    id: 'gid://gitlab/User/4',
                    avatarUrl: 'https://example.com/avatar4.png',
                    name: 'Test User 4',
                    username: 'testuser4',
                    webUrl: 'https://example.com/testuser4',
                    webPath: '/testuser4',
                    __typename: 'UserCore',
                  },
                  awardEmoji: {
                    nodes: [],
                  },
                  discussion: {
                    id: 'gid://gitlab/Discussion/4',
                    __typename: 'Discussion',
                  },
                  systemNoteIconName: null,
                  system: false,
                  internal: false,
                  __typename: 'Note',
                },
              ],
              __typename: 'NoteConnection',
            },
            __typename: 'Discussion',
          },
        ],
        __typename: 'DiscussionConnection',
      },
    },
  },
};

export const mockNote = {
  id: 'gid://gitlab/Note/123',
  author: {
    id: 'gid://gitlab/User/456',
    name: 'John Doe',
    username: 'johndoe',
    avatarUrl: 'https://example.com/avatar.jpg',
    webUrl: 'https://example.com/johndoe',
  },
  body: 'This is a discussion note',
  bodyHtml: '<p>This is a discussion note</p>',
  createdAt: '2023-01-01T00:00:00Z',
  lastEditedAt: null,
  lastEditedBy: null,
  awardEmoji: {
    nodes: [],
  },
};

export const mockNoteWithAwards = {
  ...mockNote,
  awardEmoji: {
    nodes: [
      {
        name: 'thumbsup',
        user: {
          id: 'gid://gitlab/User/456',
          name: 'John Doe',
        },
      },
      {
        name: 'heart',
        user: {
          id: 'gid://gitlab/User/789',
          name: 'Jane Smith',
        },
      },
    ],
  },
};

export const mockNoteWithEdit = {
  ...mockNote,
  lastEditedAt: '2023-01-02T00:00:00Z',
  lastEditedBy: {
    name: 'Jane Editor',
    webPath: '/jane-editor',
  },
};

export const mockDeleteNoteSuccess = {
  data: {
    destroyNote: {
      errors: [],
      note: {
        id: mockNote.id,
      },
    },
  },
};

export const mockDeleteNoteError = {
  data: {
    destroyNote: {
      errors: ['Something went wrong'],
      note: null,
    },
  },
};

export const mockToggleAwardEmojiSuccess = {
  data: {
    awardEmojiToggle: {
      errors: [],
      toggledOn: true,
      awardEmoji: {
        name: 'thumbsup',
        user: {
          id: 'gid://gitlab/User/456',
          name: 'John Doe',
        },
      },
    },
  },
};

export const mockToggleAwardEmojiError = {
  data: {
    awardEmojiToggle: {
      errors: ['Failed to toggle emoji'],
      toggledOn: false,
      awardEmoji: null,
    },
  },
};

export const mockNoteCreatedSubscriptionResponse = {
  data: {
    workItemNoteCreated: {
      id: 'gid://gitlab/Note/5',
      bodyHtml: '<p>New note from subscription</p>',
      system: false,
      internal: false,
      systemNoteIconName: null,
      createdAt: '2025-06-17T12:00:00Z',
      author: {
        id: 'gid://gitlab/User/1',
        name: 'Test User',
        username: 'testuser',
        webUrl: 'https://example.com/testuser',
        avatarUrl: 'https://example.com/avatar.png',
        __typename: 'UserCore',
      },
      discussion: {
        id: 'gid://gitlab/Discussion/5',
        notes: {
          nodes: [
            {
              id: 'gid://gitlab/Note/5',
              body: 'New note from subscription',
              bodyHtml: '<p>New note from subscription</p>',
              createdAt: '2025-06-17T12:00:00Z',
              lastEditedAt: null,
              lastEditedBy: null,
              author: {
                id: 'gid://gitlab/User/1',
                avatarUrl: 'https://example.com/avatar.png',
                name: 'Test User',
                username: 'testuser',
                webUrl: 'https://example.com/testuser',
                webPath: '/testuser',
                __typename: 'UserCore',
              },
              awardEmoji: {
                nodes: [],
              },
              discussion: {
                id: 'gid://gitlab/Discussion/5',
                __typename: 'Discussion',
              },
              systemNoteIconName: null,
              system: false,
              internal: false,
              __typename: 'Note',
            },
          ],
          __typename: 'NoteConnection',
        },
        __typename: 'Discussion',
      },
      __typename: 'Note',
    },
  },
};

export const mockNoteUpdatedSubscriptionResponse = {
  data: {
    workItemNoteUpdated: {
      id: 'gid://gitlab/Note/2',
      body: 'Updated note content',
      bodyHtml: '<p>Updated note content</p>',
      createdAt: '2025-06-16T15:30:00Z',
      lastEditedAt: '2025-06-17T14:00:00Z',
      lastEditedBy: {
        id: 'gid://gitlab/User/2',
        avatarUrl: 'https://example.com/avatar2.png',
        name: 'Test User 2',
        username: 'testuser2',
        webUrl: 'https://example.com/testuser2',
        webPath: '/testuser2',
        __typename: 'UserCore',
      },
      author: {
        id: 'gid://gitlab/User/2',
        avatarUrl: 'https://example.com/avatar2.png',
        name: 'Test User 2',
        username: 'testuser2',
        webUrl: 'https://example.com/testuser2',
        webPath: '/testuser2',
        __typename: 'UserCore',
      },
      awardEmoji: {
        nodes: [],
      },
      discussion: {
        id: 'gid://gitlab/Discussion/2',
        __typename: 'Discussion',
      },
      systemNoteIconName: null,
      system: false,
      internal: false,
      __typename: 'Note',
    },
  },
};

export const mockNoteDeletedSubscriptionResponse = {
  data: {
    workItemNoteDeleted: {
      id: 'gid://gitlab/Note/2',
      discussionId: 'gid://gitlab/Discussion/2',
      lastDiscussionNote: true,
    },
  },
};
