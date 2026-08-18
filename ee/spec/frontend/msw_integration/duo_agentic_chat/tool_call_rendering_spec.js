import { waitFor } from '@testing-library/vue';
import { getText } from '../test_helpers';
import { installAgenticChatFlowHandlers } from '../handlers/duo_agentic_chat';
import {
  agentLogEntry,
  pushCheckpoint,
  toolLogEntry,
  userLogEntry,
  waitForSocket,
} from './websocket_mock';
import {
  PROJECT_ID,
  findChatMessages,
  findSubmitButton,
  findToolMessageProjectInfo,
  findToolRowLabel,
  findToolRowSecondary,
  mountDuoAgenticChatStateManager,
  sendPrompt,
  setupDuoChatTest,
  teardownDuoChatTest,
} from './test_setup';

// Replaces the "allows user to ask about entity" example from
// ee/spec/support/shared_examples/ai/agentic_chat_shared_example.rb.
//
// Every assertion target lives in `@gitlab/duo-ui`'s `message_tool.vue` and is
// derived purely from `tool_info` — the label from `tool_message_registry`, the
// secondary text from `secondary(args)`, the project chip from `args.project_id`.
// No server data shapes them, so a streamed checkpoint is the whole input.

const MERGE_REQUEST_IID = 7;
const NUMERIC_PROJECT_ID = 1;

describe('Duo Agentic Chat | rendering a tool call in the conversation', () => {
  beforeEach(() => {
    setupDuoChatTest();
    installAgenticChatFlowHandlers();
  });

  afterEach(() => teardownDuoChatTest());

  it('renders the tool label, entity reference and project chip', async () => {
    mountDuoAgenticChatStateManager({ propsData: { projectId: PROJECT_ID } });

    await waitFor(() => {
      expect(findSubmitButton()).not.toBe(null);
    });

    // The worker opens the socket only once startWorkflow calls connect(), so the
    // prompt has to come before the checkpoint.
    sendPrompt('What is in this merge request?');
    await waitForSocket();

    await pushCheckpoint([
      userLogEntry({ id: 'user-1', content: 'What is in this merge request?' }),
      agentLogEntry({ id: 'agent-1', content: 'I should search the entity' }),
      toolLogEntry({
        id: 'tool-1',
        name: 'get_merge_request',
        args: { merge_request_iid: MERGE_REQUEST_IID, project_id: NUMERIC_PROJECT_ID },
        content: `Reading merge request !${MERGE_REQUEST_IID}`,
      }),
      agentLogEntry({ id: 'agent-2', content: 'Found the entity' }),
    ]);

    // Agent messages render their content through markdown asynchronously, so
    // wait for the narration that follows the tool call before asserting.
    await waitFor(() => {
      expect(getText(findChatMessages())).toContain('Found the entity');
    });

    // `get_merge_request` maps to a human-readable label and a `!iid` reference.
    expect(getText(findToolRowLabel())).toBe('Read merge request');
    expect(getText(findToolRowSecondary())).toBe(`!${MERGE_REQUEST_IID}`);

    // The project chip lives inside a collapsed `gl-collapse`, which still
    // renders into the DOM — the Capybara original asserted it with
    // `visible: :all` for the same reason.
    expect(getText(findToolMessageProjectInfo())).toBe(`Project: ${NUMERIC_PROJECT_ID}`);

    // The agent's surrounding narration renders either side of the tool call.
    const chat = getText(findChatMessages());
    expect(chat).toContain('I should search the entity');
    expect(chat).toContain('Found the entity');
  });
});
