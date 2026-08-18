import { s__ } from '~/locale';
import { MESSAGE_SUB_TYPE_DELEGATION, MESSAGE_SUB_TYPE_DELEGATION_RETURNS } from './constants';

/**
 * Parses a toolInfo value that may be either a JSON string or a plain object.
 * Returns the parsed object, or null if parsing fails or the value is absent.
 */
export const parseToolInfo = (rawToolInfo) => {
  if (!rawToolInfo) return null;
  if (typeof rawToolInfo === 'object') return rawToolInfo;
  try {
    return JSON.parse(rawToolInfo);
  } catch {
    return null;
  }
};

const parseToolName = (rawToolInfo) => parseToolInfo(rawToolInfo)?.name;

const getSubTypeData = (message) => {
  const returnedData = {
    icon: 'arrow-up',
    title: s__('DuoAgentPlatform|Returned to agent'),
    level: 1,
  };

  const subTypeMap = {
    [MESSAGE_SUB_TYPE_DELEGATION]: {
      icon: 'arrow-down',
      title: s__('DuoAgentPlatform|Delegated to subagent'),
      level: 1,
    },
    // Keyed by `status`. Unknown / non-terminal statuses (e.g. running,
    // paused) fall back to `default` so we never mis-render a return row
    // as a delegation via the `delegate_task` toolMap entry.
    [MESSAGE_SUB_TYPE_DELEGATION_RETURNS]: {
      success: returnedData,
      failure: {
        icon: 'error',
        title: s__('DuoAgentPlatform|Subagent did not produce an answer'),
        level: 1,
      },
      default: returnedData,
    },
  };

  if (message?.messageSubType === MESSAGE_SUB_TYPE_DELEGATION_RETURNS) {
    const returns = subTypeMap[MESSAGE_SUB_TYPE_DELEGATION_RETURNS];
    return returns[message.status] ?? returns.default;
  }

  return subTypeMap[message?.messageSubType] ?? null;
};

export const getToolData = (toolMessage) => {
  // Sub-type takes precedence over tool name. Delegation rows arrive as
  // messageType='tool' with toolInfo.name='delegate_task', but must render
  // as flow-control rows, so we resolve sub-types first to keep the
  // `delegate_task` toolMap entry from claiming them.
  const subTypeData = getSubTypeData(toolMessage);
  if (subTypeData) return subTypeData;

  const toolName = parseToolName(toolMessage?.toolInfo);

  const toolMap = {
    read_file: { icon: 'eye', title: s__('DuoAgentsPlatform|Read file'), level: 0 },
    write_file: { icon: 'pencil', title: s__('DuoAgentsPlatform|Write file'), level: 1 },
    edit_file: { icon: 'pencil', title: s__('DuoAgentsPlatform|Edit file'), level: 1 },
    create_file_with_contents: {
      icon: 'pencil',
      title: s__('DuoAgentsPlatform|Create file'),
      level: 1,
    },
    grep: { icon: 'search', title: s__('DuoAgentsPlatform|Search'), level: 0 },
    grep_files: { icon: 'search', title: s__('DuoAgentsPlatform|Search files'), level: 0 },
    find_files: { icon: 'search', title: s__('DuoAgentsPlatform|Find files'), level: 0 },
    list_files: { icon: 'search', title: s__('DuoAgentsPlatform|List files'), level: 0 },
    list_dir: { icon: 'folder-open', title: s__('DuoAgentsPlatform|List directory'), level: 0 },
    mkdir: { icon: 'folder-new', title: s__('DuoAgentsPlatform|Create directory'), level: 1 },
    run_command: { icon: 'terminal', title: s__('DuoAgentsPlatform|Run command'), level: 0 },
    gitlab_api_get: { icon: 'api', title: s__('DuoAgentsPlatform|API request'), level: 0 },
    gitlab_issue_search: {
      icon: 'search',
      title: s__('DuoAgentsPlatform|Search issues'),
      level: 0,
    },
    get_issue: { icon: 'work-item-issue', title: s__('DuoAgentsPlatform|Get issue'), level: 0 },
    get_issue_note: {
      icon: 'comments',
      title: s__('DuoAgentsPlatform|Get comment'),
      level: 0,
    },
    create_merge_request: {
      icon: 'git-merge',
      title: s__('DuoAgentsPlatform|Create merge request'),
      level: 1,
    },
    update_merge_request: {
      icon: 'git-merge',
      title: s__('DuoAgentsPlatform|Update merge request'),
      level: 1,
    },
    get_merge_request: {
      icon: 'git-merge',
      title: s__('DuoAgentsPlatform|Get merge request'),
      level: 0,
    },
    list_issue_notes: {
      icon: 'work-item-issue',
      title: s__('DuoAgentsPlatform|List comments'),
      level: 0,
    },
    create_issue_note: {
      icon: 'comment',
      title: s__('DuoAgentsPlatform|Comment on issue'),
      level: 1,
    },
    create_merge_request_note: {
      icon: 'comment',
      title: s__('DuoAgentsPlatform|Comment on merge request'),
      level: 1,
    },
    create_work_item_note: {
      icon: 'comment',
      title: s__('DuoAgentsPlatform|Comment on work item'),
      level: 1,
    },
    create_commit: { icon: 'commit', title: s__('DuoAgentsPlatform|Create commit'), level: 1 },
    todo_write: { icon: 'todo-done', title: s__('DuoAgentsPlatform|Plan updated'), level: 1 },
    delegate_task: {
      icon: 'arrow-down',
      title: s__('DuoAgentsPlatform|Delegated to subagent'),
      level: 1,
    },
  };

  return (
    toolMap[toolName] || {
      icon: 'work-item-maintenance',
      title: s__('DuoAgentsPlatform|Action'),
      level: 0,
    }
  );
};

export const getMessageData = (message) => {
  if (!message.messageType) {
    throw new Error(`Message requires property 'message_type' but got ${JSON.stringify(message)} `);
  }

  switch (message.messageType) {
    case 'user':
      return { icon: 'user', title: s__('DuoAgentPlatform|User messaged agent'), level: 1 };
    case 'request':
      return {
        icon: 'question-o',
        title: s__('DuoAgentPlatform|Agent required human input'),
        level: 1,
      };
    case 'agent':
      return { icon: 'tanuki-ai', title: s__('DuoAgentPlatform|Agent reasoning'), level: 0 };
    case 'tool':
      return getToolData(message);
    default:
      return { icon: 'work-item-maintenance', title: s__('DuoAgentPlatform|Action'), level: 0 };
  }
};
