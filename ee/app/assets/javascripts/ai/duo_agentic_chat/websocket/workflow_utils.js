import { parseDocument } from 'yaml';
import Api from 'ee/api';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { parseMessage } from '~/lib/utils/websocket_utils';
import {
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_CLIENT_VERSION,
  DUO_WORKFLOW_WEBSOCKET_PARAM_ROOT_NAMESPACE_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_NAMESPACE_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_PROJECT_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_USER_SELECTED_MODEL,
  DUO_WORKFLOW_WEBSOCKET_PARAM_WORKFLOW_DEFINITION,
  DUO_WORKFLOW_WEBSOCKET_PARAM_AI_CATALOG_ITEM_VERSION_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_WORKFLOW_ID,
} from 'ee/ai/constants';
import { WorkflowUtils } from '../utils/workflow_utils';
import { getMessagesToProcess } from '../utils/messages_utils';

export function buildWebsocketUrl({
  rootNamespaceId,
  namespaceId,
  projectId,
  userModelSelectionEnabled,
  currentModel,
  defaultModel,
  workflowDefinition,
  aiCatalogItemVersionId,
  workflowId,
}) {
  const params = new URLSearchParams();

  if (rootNamespaceId) {
    params.append(
      DUO_WORKFLOW_WEBSOCKET_PARAM_ROOT_NAMESPACE_ID,
      getIdFromGraphQLId(rootNamespaceId),
    );
  }

  if (namespaceId) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_NAMESPACE_ID, getIdFromGraphQLId(namespaceId));
  }

  if (projectId) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_PROJECT_ID, getIdFromGraphQLId(projectId));
  }

  if (
    rootNamespaceId &&
    userModelSelectionEnabled &&
    currentModel?.value &&
    currentModel?.value !== defaultModel?.value
  ) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_USER_SELECTED_MODEL, currentModel.value);
  }

  params.append(
    DUO_WORKFLOW_WEBSOCKET_PARAM_WORKFLOW_DEFINITION,
    workflowDefinition || DUO_WORKFLOW_CHAT_DEFINITION,
  );

  const id = getIdFromGraphQLId(aiCatalogItemVersionId);
  if (id) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_AI_CATALOG_ITEM_VERSION_ID, id);
  }

  if (workflowId) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_WORKFLOW_ID, workflowId);
  }

  params.append('client_type', 'browser');

  const baseUrl = Api.buildUrl(Api.duoWorkflowsWsPath);

  return params.toString() ? `${baseUrl}?${params}` : baseUrl;
}

export function buildStartRequest({
  workflowId,
  workflowDefinition,
  goal,
  approval = {},
  additionalContext,
  agentConfig,
  flowConfig,
  metadata,
  clientCapabilities = [],
  orbitEnabled = true,
  isRetry = false,
  selectedRegenerateMessageId = null,
}) {
  const startRequest = {
    startRequest: {
      workflowID: workflowId,
      clientVersion: DUO_WORKFLOW_CLIENT_VERSION,
      workflowDefinition: workflowDefinition || DUO_WORKFLOW_CHAT_DEFINITION,
      workflowMetadata: metadata,
      clientCapabilities,
      goal,
      approval,
      // Reflects the user's saved Orbit preference. When false the backend
      // should suppress Orbit tool injection for this workflow invocation.
      useOrbit: orbitEnabled,
      // Signals the duo-workflow-service that this submission replaces the
      // previous agent attempt rather than appending a new turn. Consumed
      // by ExecuteWorkflow in ai-assist!5801.
      regenerate: isRetry,
    },
  };

  if (additionalContext) {
    startRequest.startRequest.additional_context = additionalContext;
  }

  if (agentConfig) {
    const parsedAgentConfig = parseDocument(agentConfig).toJSON();

    startRequest.startRequest.flowConfig = parsedAgentConfig;
    startRequest.startRequest.flowConfigSchemaVersion = parsedAgentConfig.version;
  }

  // The Duo Workflow Service rejects a flowConfigId that is not accompanied by a
  // flowConfigSchemaVersion. Some foundational agents (e.g. the default `chat` agent)
  // expose a flowConfig without a schema version; for those we omit the flow config
  // entirely and let the service resolve the default flow.
  if (flowConfig?.flowConfigSchemaVersion) {
    startRequest.startRequest.flowConfigId = flowConfig.flowConfigId;
    startRequest.startRequest.flowVersion = flowConfig.flowVersion;
    startRequest.startRequest.flowConfigSchemaVersion = flowConfig.flowConfigSchemaVersion;
  }

  // Retry feature: promote selected alternative to canonical before processing
  if (selectedRegenerateMessageId) {
    startRequest.startRequest.selectedRegenerateMessageId = selectedRegenerateMessageId;
  }

  return startRequest;
}

export async function processWorkflowMessage(event, currentMessageId) {
  const action = await parseMessage(event);

  if (!action || !action.newCheckpoint) {
    return null;
  }

  let checkpoint;
  try {
    checkpoint = JSON.parse(action.newCheckpoint.checkpoint);
  } catch {
    return null;
  }

  const uiChatLog = checkpoint?.channel_values?.ui_chat_log;
  if (!uiChatLog) {
    return null;
  }

  const { toProcess, lastProcessedMessageId } = getMessagesToProcess(uiChatLog, currentMessageId);
  const messages = WorkflowUtils.transformChatMessages(toProcess);

  return {
    messages,
    status: action.newCheckpoint.status,
    goal: action.newCheckpoint.goal,
    lastProcessedMessageId,
  };
}
