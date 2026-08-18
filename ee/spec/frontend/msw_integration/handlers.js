import { rest } from 'msw';
import { handleWorkItemOperation, workItemRestEndpoints } from './work_items/handlers';
import { captureMissingOperation, captureRequest } from './operation_helpers';
import { handleAiCatalogOperation, aiCatalogRestEndpoints } from './handlers/ai_catalog';
import { handleAiDuoPanelEEOperation } from './handlers/ai_duo_panel';
import { handleAiAgenticChatOperation } from './handlers/ai_agentic_chat';

export const featureHandlers = [
  handleWorkItemOperation,
  handleAiCatalogOperation,
  // Agentic-chat handler runs before the duo-panel handler so the agentic chat
  // integration tests get the archived/active workflow fixtures from
  // `ai_agentic_chat.js` instead of the duo-panel fallback for shared
  // GraphQL operations like `getUserWorkflows`.
  handleAiAgenticChatOperation,
  handleAiDuoPanelEEOperation,
];
export const restEndpoints = [...workItemRestEndpoints, ...aiCatalogRestEndpoints];

export function buildHandlers(allFeatureHandlers, allRestEndpoints) {
  const restEndpointsHandlers = allRestEndpoints.map((endpoint) =>
    rest[endpoint.method](endpoint.path, (req, res, ctx) => {
      const operationName = endpoint.name || `REST:${endpoint.method}:${endpoint.path}`;
      captureRequest(operationName, req);

      const transforms = [ctx.json(endpoint.response)];
      if (endpoint.headers) {
        Object.entries(endpoint.headers).forEach(([key, value]) => {
          transforms.push(ctx.set(key, value));
        });
      }
      return res(...transforms);
    }),
  );

  return [
    rest.post('http://test.host/api/graphql', (req, res, ctx) => {
      const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
      const { operationName, variables } = body;

      for (const handler of allFeatureHandlers) {
        const result = handler({ operationName, variables, res, ctx });
        if (result) {
          captureRequest(operationName, req, variables);
          return result;
        }
      }

      captureMissingOperation(operationName);
      return res(ctx.status(400));
    }),

    ...restEndpointsHandlers,

    rest.get('*', (req, res, ctx) => {
      // eslint-disable-next-line no-console
      console.log(`Unhandled url for REST endpoint: ${req.url.href}`);
      return res(ctx.status(400));
    }),
  ];
}
