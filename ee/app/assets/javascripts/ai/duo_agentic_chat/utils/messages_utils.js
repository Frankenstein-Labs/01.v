export const getMessagesToProcess = (messages, lastProcessedMessageId) => {
  if (!messages || messages.length === 0) {
    return {
      toProcess: [],
      lastProcessedMessageId: null,
    };
  }

  // First run or log shrank (truncate / reset): process everything.
  const isFirstRunOrReset = lastProcessedMessageId === null;
  let startIndex;
  if (isFirstRunOrReset) {
    startIndex = 0;
  } else {
    startIndex = messages.findIndex((msg) => msg.message_id === lastProcessedMessageId);
    if (startIndex === -1) {
      startIndex = 0;
    }
  }

  const toProcess = messages.slice(startIndex);

  return {
    toProcess,
    lastProcessedMessageId: messages.at(-1).message_id,
  };
};
