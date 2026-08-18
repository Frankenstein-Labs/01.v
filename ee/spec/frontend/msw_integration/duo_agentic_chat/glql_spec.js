import { waitFor } from '@testing-library/vue';
import { installAgenticChatFlowHandlers } from '../handlers/duo_agentic_chat';
import { agentLogEntry, pushCheckpoint, userLogEntry, waitForSocket } from './websocket_mock';
import {
  PROJECT_ID,
  findSubmitButton,
  mountDuoAgenticChatStateManager,
  sendPrompt,
  setupDuoChatTest,
  teardownDuoChatTest,
} from './test_setup';

// Regression coverage for GLQL embedded views failing to render in Duo
// (agentic) Chat while a response streams in — they only mounted after a full
// page reload.
//
// The whole point of this spec is to exercise the *real* markdown → renderGFM →
// GLQL facade pipeline, so we deliberately do NOT mock `render_gfm`,
// `workflow_utils`, or `messages_utils`. The streaming layer is real too --
// `stream_manager` and `stream_worker` both run, and only the websocket
// transport is faked.

const GOAL = 'Show me a GLQL view of my issues';

// A markdown reply carrying a fenced GLQL block. This is what the assistant
// streams back; the facade must mount from it without a page reload.
const AGENT_MARKDOWN = [
  'Here are your open issues:',
  '',
  '```glql',
  'assignee = currentUser()',
  '```',
  '',
].join('\n');

describe('Duo Agentic Chat | rendering a GLQL view from a streamed message', () => {
  beforeEach(() => {
    setupDuoChatTest();
    installAgenticChatFlowHandlers();
  });

  afterEach(() => teardownDuoChatTest());

  it('mounts the GLQL facade from the streamed assistant message', async () => {
    mountDuoAgenticChatStateManager({ propsData: { projectId: PROJECT_ID } });

    await waitFor(() => {
      expect(findSubmitButton()).not.toBe(null);
    });

    // The worker only opens a socket once the state manager starts a workflow,
    // so the prompt has to come before the checkpoint.
    sendPrompt(GOAL);
    await waitForSocket();

    await pushCheckpoint(
      [
        userLogEntry({ id: 'msg-user-1', content: GOAL }),
        agentLogEntry({ id: 'msg-agent-1', content: AGENT_MARKDOWN }),
      ],
      { goal: GOAL },
    );

    // renderGFM detects the `.language-glql` block and mounts the facade via a
    // dynamic import; waitFor polls until it resolves.
    await waitFor(() => {
      expect(document.querySelector('[data-testid="glql-facade"]')).not.toBeNull();
    });
  });
});
