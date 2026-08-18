import { waitFor } from '@testing-library/vue';
import { getText } from '../test_helpers';
import { installAgenticChatFlowHandlers } from '../handlers/duo_agentic_chat';
import {
  agentLogEntry,
  getSockets,
  lastStartRequest,
  pushCheckpoint,
  toolLogEntry,
  toolRequestLogEntry,
  userLogEntry,
  waitForSocket,
} from './websocket_mock';
import {
  PROJECT_ID,
  approveTool,
  findApproveButton,
  findChatMessages,
  findDenyButton,
  findSubmitButton,
  mountDuoAgenticChatStateManager,
  sendPrompt,
  setupDuoChatTest,
  teardownDuoChatTest,
} from './test_setup';

// Replaces the UI half of the "allows user to create a new entity" example from
// ee/spec/support/shared_examples/ai/agentic_chat_shared_example.rb.
//
// The remaining half of that example — that an approved tool call actually
// reaches Postgres — needs a real duo-workflow-service and stays in
// ee/spec/features/duo_chat/agentic_chat_smoke_spec.rb.

const TOOL_ARGS = {
  title: 'New feature',
  project_id: 1,
  source_branch: 'feature',
  target_branch: 'main',
};

const pendingToolRequest = () => [
  userLogEntry({ id: 'user-1', content: 'Open a merge request for my branch' }),
  agentLogEntry({ id: 'agent-1', content: 'I should create a new entity' }),
  toolRequestLogEntry({
    id: 'request-1',
    name: 'create_merge_request',
    args: TOOL_ARGS,
    content: 'Requesting approval to create a merge request',
    status: 'pending',
  }),
];

// After an approval the service re-emits the request with `status: 'success'`
// *followed by the executed tool message*. That trailing tool message is what
// `toolDenialTransformer` looks for to tell an approved request from a denied
// one — without it the card would finalize as "Cancelled".
const approvedToolRequest = () => [
  ...pendingToolRequest().slice(0, 2),
  toolRequestLogEntry({
    id: 'request-1',
    name: 'create_merge_request',
    args: TOOL_ARGS,
    content: 'Requesting approval to create a merge request',
    status: 'success',
  }),
  toolLogEntry({
    id: 'tool-1',
    name: 'create_merge_request',
    args: TOOL_ARGS,
    content: 'Created merge request !1',
  }),
  agentLogEntry({ id: 'agent-2', content: 'Entity created' }),
];

describe('Duo Agentic Chat | approving a tool call', () => {
  const mountAndRequestApproval = async () => {
    mountDuoAgenticChatStateManager({ propsData: { projectId: PROJECT_ID } });

    await waitFor(() => {
      expect(findSubmitButton()).not.toBe(null);
    });

    // The worker opens the socket only once startWorkflow calls connect().
    sendPrompt('Open a merge request for my branch');
    await waitForSocket();

    await pushCheckpoint(pendingToolRequest(), { status: 'INPUT_REQUIRED' });

    await waitFor(() => {
      expect(findApproveButton()).not.toBe(null);
    });
  };

  beforeEach(() => {
    setupDuoChatTest();
    installAgenticChatFlowHandlers();
  });

  afterEach(() => teardownDuoChatTest());

  it('renders the pending tool call with approve and deny actions', async () => {
    await mountAndRequestApproval();

    // The title is derived from the tool name by `message_tool_approval.vue`.
    expect(getText(findChatMessages())).toContain('Create merge request');
    expect(findDenyButton()).not.toBe(null);
    // Request approval card status indicator.
    expect(getText(findChatMessages())).toContain('Pending');
  });

  it('sends an approval over the stream', async () => {
    await mountAndRequestApproval();

    const socketsBeforeApproval = getSockets().length;

    approveTool();

    // The worker flushes the startRequest from its `onopen` handler, so the frame
    // is only on the wire once the new socket has finished its handshake.
    await waitFor(() => {
      expect(getSockets()).toHaveLength(socketsBeforeApproval + 1);
    });
    await waitForSocket();

    // Approval is a fresh connect carrying an approval payload and an empty
    // goal, not a `send` on the existing socket.
    expect(lastStartRequest().approval).toEqual({ approval: {} });
    expect(lastStartRequest().goal).toBe('');
  });

  it('shows the tool as approved once the next checkpoint arrives', async () => {
    await mountAndRequestApproval();

    const socketsBeforeApproval = getSockets().length;
    approveTool();

    // Wait for the approval to reach the wire before replying to it, so the
    // ordering is explicit rather than relying on the handler chain being
    // synchronous.
    // The worker flushes the startRequest from its `onopen` handler, so the frame
    // is only on the wire once the new socket has finished its handshake.
    await waitFor(() => {
      expect(getSockets()).toHaveLength(socketsBeforeApproval + 1);
    });
    await waitForSocket();

    // The service replies with the same tool message flipped to `success`,
    // followed by the agent's confirmation.
    await pushCheckpoint(approvedToolRequest());

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain('Entity created');
    });

    expect(getText(findChatMessages())).toContain('Approved');
  });
});
