import {
  updateCacheAfterCreatingNote,
  updateCacheAfterDeletingNote,
} from 'ee/compliance_violations/graphql/cache_utils';

describe('compliance violations cache utils', () => {
  const mockDiscussion = {
    id: 'gid://gitlab/Discussion/abc123',
    notes: {
      nodes: [
        {
          id: 'gid://gitlab/Note/1',
          body: 'Test note',
          system: false,
        },
      ],
    },
  };

  const mockCurrentData = {
    projectComplianceViolation: {
      id: 'gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/1',
      discussions: {
        nodes: [mockDiscussion],
      },
    },
  };

  describe('updateCacheAfterCreatingNote', () => {
    it('returns current data when newNote is null', () => {
      const result = updateCacheAfterCreatingNote(mockCurrentData, null);

      expect(result).toBe(mockCurrentData);
    });

    it('adds new discussion when it does not exist', () => {
      const newNote = {
        id: 'gid://gitlab/Note/2',
        discussion: {
          id: 'gid://gitlab/Discussion/def456',
          notes: {
            nodes: [
              {
                id: 'gid://gitlab/Note/2',
                body: 'New note',
                system: false,
              },
            ],
          },
        },
      };

      const result = updateCacheAfterCreatingNote(mockCurrentData, newNote);

      expect(result.projectComplianceViolation.discussions.nodes).toHaveLength(2);
      expect(result.projectComplianceViolation.discussions.nodes[1]).toEqual(newNote.discussion);
    });

    it('does not add discussion when it already exists', () => {
      const newNote = {
        id: 'gid://gitlab/Note/2',
        discussion: {
          id: mockDiscussion.id,
          notes: {
            nodes: [
              {
                id: 'gid://gitlab/Note/2',
                body: 'Reply note',
                system: false,
              },
            ],
          },
        },
      };

      const result = updateCacheAfterCreatingNote(mockCurrentData, newNote);

      expect(result.projectComplianceViolation.discussions.nodes).toHaveLength(1);
    });

    it('returns current data when discussions is not present', () => {
      const dataWithoutDiscussions = {
        projectComplianceViolation: {
          id: 'gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/1',
        },
      };

      const newNote = {
        id: 'gid://gitlab/Note/2',
        discussion: {
          id: 'gid://gitlab/Discussion/def456',
        },
      };

      const result = updateCacheAfterCreatingNote(dataWithoutDiscussions, newNote);

      expect(result).toEqual(dataWithoutDiscussions);
    });

    it('returns current data when projectComplianceViolation is not present', () => {
      const emptyData = {};
      const newNote = {
        id: 'gid://gitlab/Note/2',
        discussion: {
          id: 'gid://gitlab/Discussion/def456',
        },
      };

      const result = updateCacheAfterCreatingNote(emptyData, newNote);

      expect(result).toBe(emptyData);
    });
  });

  describe('updateCacheAfterDeletingNote', () => {
    it('returns current data when workItemNoteDeleted is not in subscriptionData', () => {
      const subscriptionData = { data: {} };

      const result = updateCacheAfterDeletingNote(mockCurrentData, subscriptionData);

      expect(result).toBe(mockCurrentData);
    });

    it('removes entire discussion when lastDiscussionNote is true', () => {
      const subscriptionData = {
        data: {
          workItemNoteDeleted: {
            id: 'gid://gitlab/Note/1',
            discussionId: mockDiscussion.id,
            lastDiscussionNote: true,
          },
        },
      };

      const result = updateCacheAfterDeletingNote(mockCurrentData, subscriptionData);

      expect(result.projectComplianceViolation.discussions.nodes).toHaveLength(0);
    });

    it('removes only the note when lastDiscussionNote is false', () => {
      const discussionWithMultipleNotes = {
        id: 'gid://gitlab/Discussion/abc123',
        notes: {
          nodes: [
            { id: 'gid://gitlab/Note/1', body: 'First note' },
            { id: 'gid://gitlab/Note/2', body: 'Second note' },
          ],
        },
      };

      const dataWithMultipleNotes = {
        projectComplianceViolation: {
          id: 'gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/1',
          discussions: {
            nodes: [discussionWithMultipleNotes],
          },
        },
      };

      const subscriptionData = {
        data: {
          workItemNoteDeleted: {
            id: 'gid://gitlab/Note/1',
            discussionId: discussionWithMultipleNotes.id,
            lastDiscussionNote: false,
          },
        },
      };

      const result = updateCacheAfterDeletingNote(dataWithMultipleNotes, subscriptionData);

      expect(result.projectComplianceViolation.discussions.nodes).toHaveLength(1);
      expect(result.projectComplianceViolation.discussions.nodes[0].notes.nodes).toHaveLength(1);
      expect(result.projectComplianceViolation.discussions.nodes[0].notes.nodes[0].id).toBe(
        'gid://gitlab/Note/2',
      );
    });

    it('returns current data when discussion is not found', () => {
      const subscriptionData = {
        data: {
          workItemNoteDeleted: {
            id: 'gid://gitlab/Note/999',
            discussionId: 'gid://gitlab/Discussion/nonexistent',
            lastDiscussionNote: true,
          },
        },
      };

      const result = updateCacheAfterDeletingNote(mockCurrentData, subscriptionData);

      expect(result.projectComplianceViolation.discussions.nodes).toHaveLength(1);
    });

    it('returns current data when projectComplianceViolation is not present', () => {
      const emptyData = {};
      const subscriptionData = {
        data: {
          workItemNoteDeleted: {
            id: 'gid://gitlab/Note/1',
            discussionId: 'gid://gitlab/Discussion/abc123',
            lastDiscussionNote: true,
          },
        },
      };

      const result = updateCacheAfterDeletingNote(emptyData, subscriptionData);

      expect(result).toBe(emptyData);
    });
  });
});
