import { produce } from 'immer';

export const updateCacheAfterCreatingNote = (currentData, newNote) => {
  if (!newNote || !currentData?.projectComplianceViolation) {
    return currentData;
  }

  return produce(currentData, (draftData) => {
    const discussions = draftData?.projectComplianceViolation?.discussions?.nodes;

    if (!discussions) {
      return;
    }

    const existingDiscussion = discussions.find((d) => d.id === newNote.discussion.id);

    if (existingDiscussion) {
      return;
    }

    discussions.push(newNote.discussion);
  });
};

export const updateCacheAfterDeletingNote = (currentData, subscriptionData) => {
  if (!subscriptionData.data?.workItemNoteDeleted || !currentData?.projectComplianceViolation) {
    return currentData;
  }

  const deletedNote = subscriptionData.data.workItemNoteDeleted;
  const { id, discussionId, lastDiscussionNote } = deletedNote;

  return produce(currentData, (draftData) => {
    const discussions = draftData?.projectComplianceViolation?.discussions?.nodes;

    if (!discussions) {
      return;
    }

    const discussionIndex = discussions.findIndex((discussion) => discussion.id === discussionId);

    if (discussionIndex === -1) {
      return;
    }

    if (lastDiscussionNote) {
      discussions.splice(discussionIndex, 1);
    } else {
      const discussion = discussions[discussionIndex];
      const noteIndex = discussion.notes.nodes.findIndex((note) => note.id === id);
      if (noteIndex !== -1) {
        discussion.notes.nodes.splice(noteIndex, 1);
      }
    }
  });
};
