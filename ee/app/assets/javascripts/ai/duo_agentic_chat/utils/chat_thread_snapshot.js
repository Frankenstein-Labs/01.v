const THREAD_MAX_MESSAGES = 20;

const threadSnapshotKey = (convoId) => `chat/${convoId}`;

export const saveThreadSnapshot = (convoId, messages) => {
  const snapshot = {
    convoId,
    messages: messages.slice(-THREAD_MAX_MESSAGES),
  };

  try {
    sessionStorage.setItem(threadSnapshotKey(convoId), JSON.stringify(snapshot));
  } catch {
    /* ignore quota errors */
  }
};

export const loadThreadSnapshot = (convoId) => {
  try {
    const raw = sessionStorage.getItem(threadSnapshotKey(convoId));
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

export const clearThreadSnapshot = (convoId) => {
  try {
    sessionStorage.removeItem(threadSnapshotKey(convoId));
  } catch {
    /* ignore errors */
  }
};
