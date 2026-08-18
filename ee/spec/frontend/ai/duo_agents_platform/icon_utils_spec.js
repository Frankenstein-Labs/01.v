// eslint-disable-next-line no-restricted-imports
import { s__ } from '~/locale';
import { getToolData, getMessageData } from 'ee/ai/duo_agents_platform/icon_utils';

jest.mock('~/locale');

describe('duo_agents_platform icon_utils', () => {
  describe('getToolData', () => {
    beforeEach(() => {
      s__.mockImplementation((key) => key.split('|')[1]);
    });

    it.each([
      ['read_file', { icon: 'eye', title: 'Read file', level: 0 }],
      ['write_file', { icon: 'pencil', title: 'Write file', level: 1 }],
      ['edit_file', { icon: 'pencil', title: 'Edit file', level: 1 }],
      ['create_file_with_contents', { icon: 'pencil', title: 'Create file', level: 1 }],
      ['grep', { icon: 'search', title: 'Search', level: 0 }],
      ['grep_files', { icon: 'search', title: 'Search files', level: 0 }],
      ['find_files', { icon: 'search', title: 'Find files', level: 0 }],
      ['list_files', { icon: 'search', title: 'List files', level: 0 }],
      ['list_dir', { icon: 'folder-open', title: 'List directory', level: 0 }],
      ['mkdir', { icon: 'folder-new', title: 'Create directory', level: 1 }],
      ['run_command', { icon: 'terminal', title: 'Run command', level: 0 }],
      ['gitlab_api_get', { icon: 'api', title: 'API request', level: 0 }],
      ['gitlab_issue_search', { icon: 'search', title: 'Search issues', level: 0 }],
      ['get_issue', { icon: 'work-item-issue', title: 'Get issue', level: 0 }],
      ['get_issue_note', { icon: 'comments', title: 'Get comment', level: 0 }],
      ['create_merge_request', { icon: 'git-merge', title: 'Create merge request', level: 1 }],
      ['update_merge_request', { icon: 'git-merge', title: 'Update merge request', level: 1 }],
      ['get_merge_request', { icon: 'git-merge', title: 'Get merge request', level: 0 }],
      ['list_issue_notes', { icon: 'work-item-issue', title: 'List comments', level: 0 }],
      ['create_issue_note', { icon: 'comment', title: 'Comment on issue', level: 1 }],
      [
        'create_merge_request_note',
        { icon: 'comment', title: 'Comment on merge request', level: 1 },
      ],
      ['create_work_item_note', { icon: 'comment', title: 'Comment on work item', level: 1 }],
      ['create_commit', { icon: 'commit', title: 'Create commit', level: 1 }],
      ['todo_write', { icon: 'todo-done', title: 'Plan updated', level: 1 }],
    ])('returns correct data for %s tool', (toolName, expected) => {
      const toolMessage = { toolInfo: { name: toolName } };

      const result = getToolData(toolMessage);

      expect(result).toEqual(expected);
    });

    it('returns default data for unknown tool', () => {
      const toolMessage = { toolInfo: { name: 'unknown_tool' } };

      const result = getToolData(toolMessage);

      expect(result).toEqual({
        icon: 'work-item-maintenance',
        title: 'Action',
        level: 0,
      });
    });

    it('handles missing toolInfo', () => {
      const toolMessage = {};

      const result = getToolData(toolMessage);

      expect(result).toEqual({
        icon: 'work-item-maintenance',
        title: 'Action',
        level: 0,
      });
    });

    it('handles null toolMessage', () => {
      const result = getToolData(null);

      expect(result).toEqual({
        icon: 'work-item-maintenance',
        title: 'Action',
        level: 0,
      });
    });

    describe('when toolInfo is a JSON string (GraphQL production format)', () => {
      it.each([
        ['read_file', { icon: 'eye', title: 'Read file', level: 0 }],
        ['create_commit', { icon: 'commit', title: 'Create commit', level: 1 }],
        ['todo_write', { icon: 'todo-done', title: 'Plan updated', level: 1 }],
      ])('parses JSON string and returns correct data for %s', (toolName, expected) => {
        const toolMessage = { toolInfo: JSON.stringify({ name: toolName, args: {} }) };

        expect(getToolData(toolMessage)).toEqual(expected);
      });

      it('returns default data for malformed JSON', () => {
        const toolMessage = { toolInfo: 'not valid json{' };

        expect(getToolData(toolMessage)).toEqual({
          icon: 'work-item-maintenance',
          title: 'Action',
          level: 0,
        });
      });
    });
  });

  describe('getMessageData', () => {
    beforeEach(() => {
      s__.mockImplementation((key) => key.split('|')[1]);
    });

    it.each([
      ['user', { icon: 'user', title: 'User messaged agent', level: 1 }],
      ['request', { icon: 'question-o', title: 'Agent required human input', level: 1 }],
      ['agent', { icon: 'tanuki-ai', title: 'Agent reasoning', level: 0 }],
      ['unknown', { icon: 'work-item-maintenance', title: 'Action', level: 0 }],
    ])('returns correct data for %s message type', (messageType, expected) => {
      const message = { messageType };

      const result = getMessageData(message);

      expect(result).toEqual(expected);
    });

    it('returns tool data for tool message type', () => {
      const message = {
        messageType: 'tool',
        toolInfo: { name: 'read_file' },
      };

      const result = getMessageData(message);

      expect(result).toEqual({
        icon: 'eye',
        title: 'Read file',
        level: 0,
      });
    });

    it.each([
      [{}, "Message requires property 'message_type' but got {}"],
      [
        { messageType: null },
        'Message requires property \'message_type\' but got {"messageType":null}',
      ],
    ])('throws error when messageType is invalid: %p', (message, expectedError) => {
      expect(() => getMessageData(message)).toThrow(expectedError);
    });

    it('returns delegated-to-subagent data for delegation sub-type', () => {
      expect(getMessageData({ messageType: 'tool', messageSubType: 'delegation' })).toEqual({
        icon: 'arrow-down',
        title: 'Delegated to subagent',
        level: 1,
      });
    });

    it('returns returned-to-agent data for delegation_returns success', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: 'delegation_returns',
          status: 'success',
        }),
      ).toEqual({
        icon: 'arrow-up',
        title: 'Returned to agent',
        level: 1,
      });
    });

    it('returns failure data for delegation_returns failure', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: 'delegation_returns',
          status: 'failure',
        }),
      ).toEqual({
        icon: 'error',
        title: 'Subagent did not produce an answer',
        level: 1,
      });
    });

    it('returns up-arrow returned-to-agent for delegation_returns with unknown status', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: 'delegation_returns',
          status: 'running',
        }),
      ).toEqual({
        icon: 'arrow-up',
        title: 'Returned to agent',
        level: 1,
      });
    });

    it('does not fall through to the delegate_task toolMap entry for return rows with unknown status', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: 'delegation_returns',
          status: 'running',
          toolInfo: { name: 'delegate_task' },
        }),
      ).toEqual({
        icon: 'arrow-up',
        title: 'Returned to agent',
        level: 1,
      });
    });

    describe('when delegation sub-types arrive as tool messages', () => {
      // The gateway emits delegation/delegation_returns entries as
      // messageType='tool' because they ARE delegate_task tool invocations.
      // The sub-type handler must win over the toolMap's `delegate_task`
      // entry so delegation rows render flow-control icons, not the tool
      // icon, and so delegation_returns rows render `arrow-up` instead of
      // the toolMap's `arrow-down`.
      it('returns delegated-to-subagent for tool + delegation', () => {
        expect(
          getMessageData({
            messageType: 'tool',
            messageSubType: 'delegation',
            toolInfo: { name: 'delegate_task' },
          }),
        ).toEqual({
          icon: 'arrow-down',
          title: 'Delegated to subagent',
          level: 1,
        });
      });

      it('returns returned-to-agent for tool + delegation_returns + success', () => {
        expect(
          getMessageData({
            messageType: 'tool',
            messageSubType: 'delegation_returns',
            status: 'success',
            toolInfo: { name: 'delegate_task' },
          }),
        ).toEqual({
          icon: 'arrow-up',
          title: 'Returned to agent',
          level: 1,
        });
      });

      it('returns failure data for tool + delegation_returns + failure', () => {
        expect(
          getMessageData({
            messageType: 'tool',
            messageSubType: 'delegation_returns',
            status: 'failure',
            toolInfo: { name: 'delegate_task' },
          }),
        ).toEqual({
          icon: 'error',
          title: 'Subagent did not produce an answer',
          level: 1,
        });
      });
    });
  });
});
