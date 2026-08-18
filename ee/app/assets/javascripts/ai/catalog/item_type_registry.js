import { s__, sprintf } from '~/locale';

import {
  AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_TYPE_FLOW,
  TRACK_EVENT_TYPE_THIRD_PARTY_FLOW,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
} from 'ee/ai/catalog/constants';
import { isAiCatalogItemRestricted } from './capabilities';
import AiCatalogAgentForm from './components/ai_catalog_agent_form.vue';
import AiCatalogFlowForm from './components/ai_catalog_flow_form.vue';
import { AGENT_MESSAGES, FLOW_MESSAGES, THIRD_PARTY_FLOW_MESSAGES } from './messages';
import {
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
} from './router/constants';
import { canCreateAiCatalogAgent, canCreateAiCatalogFlow } from './permissions';

export const itemTypeValidator = (type) =>
  [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_FOUNDATIONAL_AGENT].includes(type);

const AGENT_CONFIG = {
  ...AGENT_MESSAGES.common,
  disable: AGENT_MESSAGES.disable,
  formComponent: AiCatalogAgentForm,
  mutations: AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_AGENT].mutations,
  queries: AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_AGENT].queries,
  acceptedTypes: [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW],
  trackLabel: TRACK_EVENT_TYPE_AGENT,
  canCreateFn: canCreateAiCatalogAgent,
  create: {
    ...AGENT_MESSAGES.create,
  },
  edit: {
    ...AGENT_MESSAGES.edit,
    buildInitialValues: (item) => ({
      projectId: item.project?.id,
      name: item.name,
      description: item.description,
      systemPrompt: item.latestVersion.systemPrompt,
      tools: (item.latestVersion.tools?.nodes ?? []).map((t) => t.id),
      mcpTools: item.latestVersion.mcpTools ?? [],
      mcpServers: (item.latestVersion.mcpServers?.nodes ?? []).map((s) => s.id),
      definition: item.latestVersion.definition ?? '',
      public: item.public,
      itemType: item.itemType,
      visibility: item.visibility,
    }),
  },
  duplicate: {
    ...AGENT_MESSAGES.duplicate,
    buildInitialValues: (item, { activeVersion, glFeatures = {} }) => ({
      name: sprintf(s__('AICatalog|Copy of %{name}'), { name: item.name }),
      description: item.description,
      systemPrompt: activeVersion.systemPrompt,
      tools: (activeVersion.tools?.nodes ?? []).map((t) => t.id),
      mcpTools: activeVersion.mcpTools ?? [],
      mcpServers: (activeVersion.mcpServers?.nodes ?? []).map((s) => s.id),
      definition: activeVersion.definition ?? '',
      public: false,
      itemType: item.itemType,
      visibility: isAiCatalogItemRestricted(item, glFeatures)
        ? VISIBILITY_LEVEL_RESTRICTED
        : VISIBILITY_LEVEL_PRIVATE,
    }),
  },
  show: {
    ...AGENT_MESSAGES.show,
  },
  routes: {
    show: AI_CATALOG_AGENTS_SHOW_ROUTE,
    list: AI_CATALOG_AGENTS_ROUTE,
    duplicate: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
    edit: AI_CATALOG_AGENTS_EDIT_ROUTE,
  },
  index: {
    ...AGENT_MESSAGES.index,
    explorePathKey: 'exploreAiCatalogAgentsPath',
    managedItemsUpdate: (data) => {
      return (data?.project?.aiCatalogItems?.nodes || []).map((item) => {
        if (!item.configurationForProject) return item;
        const latest = item.latestVersion.versionName;
        const pinned = item.configurationForProject.pinnedItemVersion.versionName;
        return { ...item, isUpdateAvailable: latest !== pinned };
      });
    },
    showActionItem: (item, canAdminConsumer) => canAdminConsumer && !item.foundational,
  },
  visibilityDescriptions: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
};

const ITEM_TYPE_REGISTRY = {
  [AI_CATALOG_TYPE_AGENT]: AGENT_CONFIG,
  [AI_CATALOG_TYPE_FLOW]: {
    ...FLOW_MESSAGES.common,
    disable: FLOW_MESSAGES.disable,
    formComponent: AiCatalogFlowForm,
    mutations: AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FLOW].mutations,
    queries: AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FLOW].queries,
    acceptedTypes: [AI_CATALOG_TYPE_FLOW],
    trackLabel: TRACK_EVENT_TYPE_FLOW,
    canCreateFn: canCreateAiCatalogFlow,
    create: {
      ...FLOW_MESSAGES.create,
    },
    edit: {
      ...FLOW_MESSAGES.edit,
      buildInitialValues: (item) => ({
        projectId: item.project?.id,
        name: item.name,
        description: item.description,
        public: item.public,
        definition: item.latestVersion.definition ?? '',
        visibility: item.visibility,
      }),
    },
    duplicate: {
      ...FLOW_MESSAGES.duplicate,
      buildInitialValues: (item, { activeVersion, glFeatures = {} }) => ({
        name: sprintf(s__('AICatalog|Copy of %{name}'), { name: item.name }),
        public: false,
        description: item.description,
        definition: activeVersion.definition ?? '',
        visibility: isAiCatalogItemRestricted(item, glFeatures)
          ? VISIBILITY_LEVEL_RESTRICTED
          : VISIBILITY_LEVEL_PRIVATE,
      }),
    },
    show: {
      ...FLOW_MESSAGES.show,
    },
    routes: {
      show: AI_CATALOG_FLOWS_SHOW_ROUTE,
      list: AI_CATALOG_FLOWS_ROUTE,
      duplicate: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
      edit: AI_CATALOG_FLOWS_EDIT_ROUTE,
    },
    index: {
      ...FLOW_MESSAGES.index,
      explorePathKey: 'exploreAiCatalogFlowsPath',
      managedItemsUpdate: (data) => data?.project?.aiCatalogItems?.nodes || [],
      showActionItem: (item, canAdminConsumer, { isGroupNamespace } = {}) =>
        canAdminConsumer && !(item.foundational && isGroupNamespace),
    },
    visibilityDescriptions: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  },
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: {
    ...AGENT_CONFIG,
    index: {
      ...AGENT_CONFIG.index,
      ...THIRD_PARTY_FLOW_MESSAGES.index,
    },
    trackLabel: TRACK_EVENT_TYPE_THIRD_PARTY_FLOW,
    mutations: AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_THIRD_PARTY_FLOW].mutations,
  },
  [AI_CATALOG_TYPE_FOUNDATIONAL_AGENT]: {
    ...AGENT_MESSAGES.common,
    queries: AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[AI_CATALOG_TYPE_FOUNDATIONAL_AGENT].queries,
    routes: {
      show: AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
    },
    disable: AGENT_MESSAGES.disable,
    show: {
      ...AGENT_MESSAGES.show,
    },
  },
};

export const getRegistryItem = (type) => {
  const config = ITEM_TYPE_REGISTRY[type];
  if (!config) {
    throw new Error(`Unknown AI catalog item type: ${type}`);
  }
  return config;
};
