import { join } from 'node:path';
import { cloneDeep } from 'lodash-es';
import { loadFixturesMap } from '../fixture_utils';

const FIXTURES_PATH = join('tmp/tests/frontend/fixtures-ee/graphql/ai_catalog/integration/');
const fixtures = loadFixturesMap(FIXTURES_PATH);

export const agentResponse = fixtures.aiCatalogAgent;
export const agentPinnedToLatestResponse = fixtures.aiCatalogAgentPinnedToLatest;
export const flowResponse = fixtures.aiCatalogFlow;
export const flowPinnedToLatestResponse = fixtures.aiCatalogFlowPinnedToLatest;
export const updateConsumerResponse = fixtures.updateAiCatalogItemConsumer;

let agentCache = cloneDeep(agentResponse);
let flowCache = cloneDeep(flowResponse);

export function resetAiCatalogCache({ agent, flow } = {}) {
  agentCache = cloneDeep(agent || agentResponse);
  flowCache = cloneDeep(flow || flowResponse);
}

const FIXTURE_RESPONSES = {
  ...fixtures,
};

const STATIC_OPERATION_HANDLERS = Object.fromEntries(
  Object.entries(FIXTURE_RESPONSES).map(([operationName, fixture]) => [
    operationName,
    () => fixture,
  ]),
);

// Use cached copies so mutations can update what subsequent queries return
STATIC_OPERATION_HANDLERS.aiCatalogAgent = () => agentCache;
STATIC_OPERATION_HANDLERS.aiCatalogFlow = () => flowCache;

const MUTATION_OPERATION_HANDLERS = {
  updateAiCatalogItemConsumer: () => {
    // Swap query caches to "pinned to latest" so refetch returns updated state
    agentCache = cloneDeep(agentPinnedToLatestResponse);
    flowCache = cloneDeep(flowPinnedToLatestResponse);

    return cloneDeep(updateConsumerResponse);
  },
};

const OPERATION_HANDLERS = {
  ...STATIC_OPERATION_HANDLERS,
  ...MUTATION_OPERATION_HANDLERS,
};

export function handleAiCatalogOperation({ operationName, variables, res, ctx }) {
  const handler = OPERATION_HANDLERS[operationName];

  if (!handler) {
    return null;
  }

  const payload = handler({ operationName, variables });

  return res(ctx.json(payload));
}

export const aiCatalogRestEndpoints = [];
