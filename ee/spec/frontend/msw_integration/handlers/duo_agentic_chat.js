import { join } from 'node:path';
import { rest } from 'msw';
import { cloneDeep } from 'lodash-es';
import { parseGid } from '~/graphql_shared/utils';
import { loadFixturesMap } from '../fixture_utils';
import { server } from '../server';

const FIXTURES_PATH = join('tmp/tests/frontend/fixtures-ee/graphql/ai/duo_agentic_chat/');
export const fixtures = loadFixturesMap(FIXTURES_PATH);

// Derive test constants from fixture data so the spec does not need to
// hardcode IDs that only exist at fixture-generation time.
const workflowNode = fixtures.getWorkflowLatestCheckpoint?.data?.duoWorkflowWorkflows?.nodes?.[0];
export const MOCK_WORKFLOW_GID = workflowNode?.id;
export const MOCK_WORKFLOW_NUMERIC_ID = workflowNode ? parseGid(MOCK_WORKFLOW_GID)?.id : null;

export function handleDuoAgenticChatOperation({ operationName, res, ctx }) {
  const fixture = fixtures[operationName];
  if (!fixture) return null;
  return res(ctx.json(fixture));
}

// -----------------------------------------------------------------------------
// Runtime handlers for the live chat flow.
//
// Sending a prompt creates a workflow and then reads it back, so these
// operations depend on what earlier requests in the same test did and cannot be
// served as static fixtures. They are installed per-suite via `server.use` (see
// `installAgenticChatFlowHandlers`) rather than added to the global EE chain,
// because `handlers/ai_duo_panel.js` already answers some of them with its own
// canned workflow and the other suites depend on that.
//
// Response *shapes* are still taken from the generated fixtures and only the
// varying values are overridden, so a schema change reaches these handlers when
// the fixtures are regenerated instead of silently diverging from the API.
// -----------------------------------------------------------------------------

const GRAPHQL_URL = 'http://test.host/api/graphql';

/**
 * Reads a generated fixture, resolved on use rather than at import so a spec that
 * never exercises an operation is not broken by an unrelated missing fixture. A
 * stale `tmp/` is common, so say what to do about it instead of failing with
 * `Cannot read properties of undefined`.
 */
const fixtureFor = (operationName) => {
  const fixture = fixtures[operationName];

  if (!fixture) {
    throw new Error(
      `Missing MSW fixture for "${operationName}". Regenerate with: ` +
        'bundle exec rspec ee/spec/frontend/fixtures/ai/duo_agentic_chat.rb',
    );
  }

  return fixture;
};

// Reading a workflow back reuses the generated shapes wholesale, so the field
// set, the enum casing and every __typename come from the API rather than from
// a literal maintained here.
const createPayloadTemplate = () => fixtureFor('createAiDuoWorkflow').data.aiDuoWorkflowCreate;
const checkpointConnectionTemplate = () =>
  fixtureFor('getWorkflowLatestCheckpoint').data.duoWorkflowWorkflows;
const checkpointNodeTemplate = () => checkpointConnectionTemplate().nodes[0];
const duoMessageTemplate = () => checkpointNodeTemplate().latestCheckpoint.duoMessages[0];
const additionalContextTemplate = () => duoMessageTemplate().additionalContext[0];
const workflowConnectionTemplate = () => fixtureFor('getUserWorkflows').data.duoWorkflowWorkflows;
const workflowEdgeTemplate = () => workflowConnectionTemplate().edges[0];

const flowState = {
  nextWorkflowId: 900,
  workflows: [],
  checkpoints: new Map(),
};

const resetAgenticChatFlowState = () => {
  flowState.nextWorkflowId = 900;
  flowState.workflows = [];
  flowState.checkpoints = new Map();
};

const recordWorkflow = (id, { goal, workflowDefinition, aiCatalogItemVersionId = null }) => {
  flowState.workflows.push({
    ...cloneDeep(workflowEdgeTemplate().node),
    id,
    title: goal,
    aiCatalogItemVersionId,
  });

  flowState.checkpoints.set(id, {
    uiChatLog: [],
    status: 'INPUT_REQUIRED',
    goal,
    workflowDefinition,
    aiCatalogItemVersionId,
  });
};

/**
 * Maps checkpoint `ui_chat_log` entries onto the `duoMessages` shape. The field
 * set and typenames come from the fixture; only the values are supplied here.
 */
const toDuoMessages = (uiChatLog = []) =>
  uiChatLog.map((entry) => ({
    ...cloneDeep(duoMessageTemplate()),
    content: entry.content,
    messageType: entry.message_type,
    messageSubType: entry.message_sub_type ?? null,
    status: entry.status ?? null,
    // The resolver serialises tool_info with `.to_json`, so `null` arrives as
    // the string "null" -- see the fixture.
    toolInfo: JSON.stringify(entry.tool_info ?? null),
    timestamp: entry.timestamp,
    correlationId: entry.correlation_id ?? null,
    messageId: entry.message_id,
    role: entry.role ?? null,
    additionalContext:
      entry.additional_context?.map((item) => ({
        ...cloneDeep(additionalContextTemplate()),
        category: String(item.category ?? '').toUpperCase(),
        id: item.id,
        content: item.content,
        metadata: typeof item.metadata === 'string' ? JSON.parse(item.metadata) : item.metadata,
      })) ?? null,
  }));

const workflowNodeFor = (id) => {
  const checkpoint = flowState.checkpoints.get(id);

  return {
    ...cloneDeep(checkpointNodeTemplate()),
    id,
    status: checkpoint.status,
    aiCatalogItemVersionId: checkpoint.aiCatalogItemVersionId ?? null,
    workflowDefinition: checkpoint.workflowDefinition ?? 'chat',
    latestCheckpoint: {
      ...cloneDeep(checkpointNodeTemplate().latestCheckpoint),
      workflowGoal: checkpoint.goal ?? '',
      workflowStatus: checkpoint.status,
      errors: [],
      duoMessages: toDuoMessages(checkpoint.uiChatLog),
    },
  };
};

/** Seeds a workflow that already exists when the test starts. */
export const seedWorkflow = ({ id, title = 'Seeded conversation', uiChatLog = [] } = {}) => {
  recordWorkflow(id, { goal: title, workflowDefinition: 'chat' });
  flowState.checkpoints.get(id).uiChatLog = uiChatLog;

  return id;
};

const OPERATION_HANDLERS = {
  createAiDuoWorkflow: ({ variables }) => {
    flowState.nextWorkflowId += 1;
    const id = `gid://gitlab/Ai::DuoWorkflows::Workflow/${flowState.nextWorkflowId}`;
    recordWorkflow(id, variables);
    const template = createPayloadTemplate();

    return {
      data: {
        aiDuoWorkflowCreate: {
          ...cloneDeep(template),
          workflow: { ...template.workflow, id },
        },
      },
    };
  },

  getUserWorkflows: () => ({
    data: {
      duoWorkflowWorkflows: {
        ...workflowConnectionTemplate(),
        edges: flowState.workflows.map((node) => ({
          ...cloneDeep(workflowEdgeTemplate()),
          node: cloneDeep(node),
        })),
      },
    },
  }),

  getWorkflowLatestCheckpoint: ({ variables }) => ({
    data: {
      duoWorkflowWorkflows: {
        ...checkpointConnectionTemplate(),
        nodes: flowState.checkpoints.has(variables.workflowId)
          ? [workflowNodeFor(variables.workflowId)]
          : [],
      },
    },
  }),
};

// Fixtures the handlers above need. Checked when the handlers are installed
// rather than at import: a resolver that throws is swallowed by MSW and
// resurfaces as an unrelated timeout, and only specs that opt into the flow
// should care whether these exist.
const REQUIRED_FIXTURES = [
  'createAiDuoWorkflow',
  'getUserWorkflows',
  'getWorkflowLatestCheckpoint',
];

/**
 * Installs the runtime handlers for the current test. MSW 1.x prepends runtime
 * handlers and treats an `undefined` return as "not handled", so operations this
 * module does not own fall through to the global chain. The suite-wide
 * `server.resetHandlers()` in `spec/frontend/msw_integration/test_setup.js`
 * removes them again after each test.
 */
export const installAgenticChatFlowHandlers = () => {
  resetAgenticChatFlowState();

  server.use(
    rest.post(GRAPHQL_URL, (req, res, ctx) => {
      const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
      const handler = OPERATION_HANDLERS[body.operationName];

      if (!handler) {
        return undefined;
      }

      return res(ctx.json(handler({ variables: body.variables ?? {} })));
    }),
  );

  // Checked after the handlers are registered, so a stale fixture surfaces as
  // this message rather than as the suite-level "missing graphql handlers"
  // warning that would otherwise fire first and point somewhere unhelpful.
  REQUIRED_FIXTURES.forEach(fixtureFor);
};
