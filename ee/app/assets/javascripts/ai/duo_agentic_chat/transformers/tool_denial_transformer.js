import { CHAT_MESSAGE_TYPES } from 'ee/ai/constants';

// Mirrors the backend ToolStatus enum value consumed by duo-ui's MessageToolApproval card.
const TOOL_STATUS_CANCELLED = 'cancelled';

const isApprovalRequest = (msg) =>
  msg.message_type === CHAT_MESSAGE_TYPES.request && Boolean(msg.tool_info);

const isExecutedTool = (msg) =>
  msg.message_type === CHAT_MESSAGE_TYPES.tool && Boolean(msg.tool_info);

/**
 * Determines the index where the trailing run of pending approval requests begins.
 * These are the consecutive request+tool_info messages at the very end of the log
 * that are still awaiting the user's decision. They must be left untouched so the
 * interactive approval widget keeps rendering (mirrors duo-ui's pendingToolApprovals).
 */
const pendingApprovalStartIndex = (messages) => {
  let index = messages.length;
  while (index > 0 && isApprovalRequest(messages[index - 1])) {
    index -= 1;
  }
  return index;
};

/**
 * Rewrites denied tool approval requests into finalized "cancelled" request cards.
 *
 * The backend never emits a tool message for a denied request, so without this the
 * chat log would only keep the "Tool X requires approval..." text and drop the card
 * entirely. An approved request, by contrast, is followed by an executed tool message
 * sharing the same tool_info.name. We use that to tell the two apart:
 *
 *   - pending  → request is in the trailing approval run            → leave as-is
 *   - approved → a later, unclaimed tool message matches its name   → leave as-is
 *   - denied   → neither of the above                               → set status to
 *                'cancelled' so duo-ui's MessageToolApproval renders the finalized card
 *
 * Since duo-ui routes request-type messages directly to MessageToolApproval (as of
 * @gitlab/duo-ui v15.41), the message_type stays 'request' — only the status changes.
 *
 * Matching by name with a claimed Set (rather than correlation_id, which is always
 * null) resolves repeated tools in order, the same approach used by the
 * clarificationQuestionTransformer.
 */
export const toolDenialTransformer = (messages) => {
  const pendingStart = pendingApprovalStartIndex(messages);
  const claimedToolIndices = new Set();

  const hasMatchingExecutedTool = (request, requestIndex) => {
    for (let i = requestIndex + 1; i < messages.length; i += 1) {
      if (
        !claimedToolIndices.has(i) &&
        isExecutedTool(messages[i]) &&
        messages[i].tool_info.name === request.tool_info.name
      ) {
        claimedToolIndices.add(i);
        return true;
      }
    }
    return false;
  };

  return messages.map((msg, index) => {
    if (index >= pendingStart || !isApprovalRequest(msg)) {
      return msg;
    }

    if (hasMatchingExecutedTool(msg, index)) {
      return msg;
    }

    return {
      ...msg,
      status: TOOL_STATUS_CANCELLED,
    };
  });
};
