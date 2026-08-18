import { __, s__ } from '~/locale';

import projectAiCatalogTabItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_catalog_items.query.graphql';
import projectAiCatalogItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_items.query.graphql';
import createAiCatalogAgent from './graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import createAiCatalogFlow from './graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from './graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import deleteAiCatalogAgentMutation from './graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import deleteAiCatalogFlowMutation from './graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import deleteAiCatalogThirdPartyFlowMutation from './graphql/mutations/delete_ai_catalog_third_party_flow.mutation.graphql';
import updateAiCatalogAgent from './graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import updateAiCatalogFlow from './graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import updateAiCatalogThirdPartyFlow from './graphql/mutations/update_ai_catalog_third_party_flow.mutation.graphql';
import aiCatalogItemsQuery from './graphql/queries/ai_catalog_items.query.graphql';
import aiCatalogCustomAndFoundationalItemsQuery from './graphql/queries/ai_catalog_custom_and_foundational_items.query.graphql';
import aiCatalogAgentQuery from './graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogFlowQuery from './graphql/queries/ai_catalog_flow.query.graphql';
import aiFoundationalChatAgentQuery from './graphql/queries/ai_foundational_chat_agent.query.graphql';

/**
 * Namespace types for the AI Catalog.
 *
 * The catalog renders in three contexts: explore, project, and group.
 * The root entry points provide three booleans via Vue `provide/inject`:
 *
 *   isGlobalNamespace  – true on the Explore page
 *   isProjectNamespace – true inside a project
 *   isGroupNamespace   – true inside a group
 *
 * Inject declarations omit `default` so a missing provide surfaces
 * immediately. Tests must supply namespace booleans explicitly.
 */
export const NAMESPACE_EXPLORE = 'explore';
export const NAMESPACE_PROJECT = 'project';
export const NAMESPACE_GROUP = 'group';

export const AI_CATALOG_TYPE_AGENT = 'AGENT';
export const AI_CATALOG_TYPE_FLOW = 'FLOW';
export const AI_CATALOG_TYPE_THIRD_PARTY_FLOW = 'THIRD_PARTY_FLOW';
export const AI_CATALOG_TYPE_FOUNDATIONAL_AGENT = 'FOUNDATIONAL_AGENT';

// Granular `item_type` event property values. Must match the values produced
// by the backend builder `Ai::Catalog::Tracking::EventPropertiesBuilder` so
// that frontend and backend events are joinable on `item_type`.
export const EVENT_ITEM_TYPE_CUSTOM_AGENT = 'custom_agent';
export const EVENT_ITEM_TYPE_CUSTOM_FLOW = 'custom_flow';
export const EVENT_ITEM_TYPE_CUSTOM_EXTERNAL_AGENT = 'custom_external_agent';
export const EVENT_ITEM_TYPE_FOUNDATIONAL_AGENT = 'foundational_agent';
export const EVENT_ITEM_TYPE_FOUNDATIONAL_FLOW = 'foundational_flow';
export const EVENT_ITEM_TYPE_FOUNDATIONAL_EXTERNAL_AGENT = 'foundational_external_agent';

// Foundational agents all run under the "chat" flow within Duo Workflow Service.
// Their events are tagged with this flow_name to make them joinable with backend chat events.
export const EVENT_FOUNDATIONAL_AGENT_FLOW_NAME = 'chat';

// Custom agents are executed by Duo Workflow Service v1 flow schema.
export const EVENT_CUSTOM_AGENT_ITEM_SCHEMA_VERSION = 'v1';

// GraphQL `DuoLicensedFeature` enum value for the projects query.
export const DUO_LICENSED_FEATURE = 'AI_CATALOG';

// Foundational flow references — must match values in
// `ee/app/models/ai/catalog/foundational_flow.rb`.
export const FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW = 'code_review/v1';

export const VERIFICATION_LEVEL_GITLAB_MAINTAINED = 'GITLAB_MAINTAINED';

export const TYPENAME_AI_FOUNDATIONAL_CHAT_AGENT = 'AiFoundationalChatAgent';

export const TYPENAME_AI_CATALOG_MCP_SERVER = 'Ai::Catalog::McpServer';
export const AI_CATALOG_ITEM_LABELS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|agent'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|flow'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|agent'),
};
export const AI_CATALOG_ITEM_PLURAL_LABELS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|agents'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|flows'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|agents'),
};

export const AI_CATALOG_CONSUMER_TYPE_GROUP = 'group';
export const AI_CATALOG_CONSUMER_TYPE_PROJECT = 'project';
export const AI_CATALOG_CONSUMER_LABELS = {
  [AI_CATALOG_CONSUMER_TYPE_GROUP]: __('group'),
  [AI_CATALOG_CONSUMER_TYPE_PROJECT]: __('project'),
};
export const AI_CATALOG_PROJECT_CONSUMER_LABEL_DESCRIPTION = {
  [AI_CATALOG_TYPE_AGENT]: s__(
    'AICatalog|Members of the selected project will be able to use the agent.',
  ),
  [AI_CATALOG_TYPE_FLOW]: s__(
    'AICatalog|Members of the selected project will be able to use the flow.',
  ),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__(
    'AICatalog|Members of the selected project will be able to use the agent.',
  ),
};
export const AI_CATALOG_PROJECT_MULTI_CONSUMER_LABEL_DESCRIPTION = {
  [AI_CATALOG_TYPE_AGENT]: s__(
    'AICatalog|Select one or more projects where the agent should be enabled.',
  ),
  [AI_CATALOG_TYPE_FLOW]: s__(
    'AICatalog|Select one or more projects where the flow should be enabled.',
  ),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__(
    'AICatalog|Select one or more projects where the agent should be enabled.',
  ),
};

// Sort options in the shape FilteredSearchBar expects: `{ id, title, sortDirection }`.
// CATALOG_PRIORITY is a backend-defined ordering with no asc/desc variant. Both directions
// resolve to the bare value so FilteredSearchBar always emits 'CATALOG_PRIORITY', and the
// direction toggle is suppressed via sortDirectionToggleClass on the wrapper.
// TODO: add a first-class `directionless` flag to FilteredSearchBar's sortOptions shape
// so this workaround is no longer needed.
export const SORT_OPTIONS = [
  {
    id: 'CATALOG_PRIORITY',
    title: s__('AICatalog|Default'),
    sortDirection: { ascending: 'CATALOG_PRIORITY', descending: 'CATALOG_PRIORITY' },
  },
  {
    id: 'STAR_COUNT',
    title: s__('AICatalog|Star count'),
    sortDirection: { ascending: 'STAR_COUNT_ASC', descending: 'STAR_COUNT_DESC' },
  },
  {
    id: 'USAGE_COUNT',
    title: s__('AICatalog|Usage (last 30 days)'),
    sortDirection: { ascending: 'USAGE_COUNT_ASC', descending: 'USAGE_COUNT_DESC' },
  },
];
export const DEFAULT_SORT = 'CATALOG_PRIORITY';
export const AI_CATALOG_FILTERED_SEARCH_NAMESPACE = 'ai-catalog';
export const AI_CATALOG_FILTERED_SEARCH_TERM_KEY = 'search';
export const RECENT_SEARCHES_STORAGE_KEY_AI_CATALOG = 'ai-catalog';

export const MINIMUM_QUERY_LENGTH = 3;
export const PAGE_SIZE = 20;
export const MAX_PROJECTS_BULK_ENABLE = 100;

// Matches backend validations in https://gitlab.com/gitlab-org/gitlab/blob/aa02c3080b316cf0f3b71a992bc5cc5dc8e8bb34/ee/app/models/ai/catalog/item.rb#L10
export const MAX_LENGTH_NAME = 255;
export const MAX_LENGTH_DESCRIPTION = 1024;
export const MAX_LENGTH_PROMPT = 1000000;

export const VISIBILITY_LEVEL_PRIVATE = 'PRIVATE';
export const VISIBILITY_LEVEL_RESTRICTED = 'RESTRICTED';
export const VISIBILITY_LEVEL_PUBLIC = 'PUBLIC';
export const AGENT_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC]: s__('AICatalog|Anyone can view and use the agent.'),
  [VISIBILITY_LEVEL_RESTRICTED]: s__(
    "AICatalog|Anyone in the owning project's top-level group can view and use this agent. It won't be visible outside the owning project's top-level group.",
  ),
  [VISIBILITY_LEVEL_PRIVATE]: s__(
    "AICatalog|This agent can be viewed only by members of this project, or by users with the Owner role for the top-level group. This agent can't be shared with other projects.",
  ),
};
export const FLOW_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC]: s__('AICatalog|Anyone can view and use the flow.'),
  [VISIBILITY_LEVEL_RESTRICTED]: s__(
    "AICatalog|Anyone in the owning project's top-level group can view and use this flow. It won't be visible outside the owning project's top-level group.",
  ),
  [VISIBILITY_LEVEL_PRIVATE]: s__(
    "AICatalog|This flow can be viewed only by members of this project, or by users with the Owner role for the top-level group. This flow can't be shared with other projects.",
  ),
};
export const VISIBILITY_TYPE_ICON = {
  [VISIBILITY_LEVEL_PUBLIC]: 'earth',
  [VISIBILITY_LEVEL_RESTRICTED]: 'organization',
  [VISIBILITY_LEVEL_PRIVATE]: 'lock',
};
export const VISIBILITY_LEVEL_LABELS = {
  [VISIBILITY_LEVEL_PUBLIC]: s__('AICatalog|Public'),
  [VISIBILITY_LEVEL_RESTRICTED]: s__('AICatalog|Restricted'),
  [VISIBILITY_LEVEL_PRIVATE]: s__('AICatalog|Private'),
};
export const VISIBILITY_LEVEL_BADGE_VARIANT = {
  [VISIBILITY_LEVEL_PUBLIC]: 'success',
  [VISIBILITY_LEVEL_RESTRICTED]: 'info',
  [VISIBILITY_LEVEL_PRIVATE]: 'warning',
};

export const TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX = 'view_ai_catalog_item_index';
export const TRACK_EVENT_VIEW_AI_CATALOG_ITEM = 'view_ai_catalog_item';
export const TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED = 'view_ai_catalog_project_managed';
export const TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG = 'view_ai_catalog_project_catalog';
export const TRACK_EVENT_ENABLE_AI_CATALOG_ITEM = 'click_enable_ai_catalog_item_button';
export const TRACK_EVENT_DISABLE_AI_CATALOG_ITEM = 'click_disable_ai_catalog_item_button';
export const TRACK_EVENT_DELETE_AI_CATALOG_ITEM = 'click_delete_ai_catalog_item_button';
export const TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM = 'click_duplicate_ai_catalog_item_button';
export const TRACK_EVENT_TYPE_AGENT = AI_CATALOG_TYPE_AGENT.toLowerCase();
export const TRACK_EVENT_TYPE_FLOW = AI_CATALOG_TYPE_FLOW.toLowerCase();
export const TRACK_EVENT_TYPE_THIRD_PARTY_FLOW = AI_CATALOG_TYPE_THIRD_PARTY_FLOW.toLowerCase();
export const TRACK_EVENT_ITEM_TYPES = {
  [AI_CATALOG_TYPE_AGENT]: TRACK_EVENT_TYPE_AGENT,
  [AI_CATALOG_TYPE_FLOW]: TRACK_EVENT_TYPE_FLOW,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: TRACK_EVENT_TYPE_THIRD_PARTY_FLOW,
};
export const TRACK_EVENT_ORIGIN_EXPLORE = 'explore';
export const TRACK_EVENT_ORIGIN_PROJECT = 'project';
export const TRACK_EVENT_ORIGIN_GROUP = 'group';
export const TRACK_EVENT_PAGE_LIST = 'list';
export const TRACK_EVENT_PAGE_SHOW = 'show';

export const VERSION_LATEST = 'latestVersion';
export const VERSION_PINNED = 'configurationForProject.pinnedItemVersion';
export const VERSION_PINNED_GROUP = 'configurationForGroup.pinnedItemVersion';

export const AI_CATALOG_APOLLO_LIST_QUERY = aiCatalogItemsQuery;
export const AI_CATALOG_APOLLO_CUSTOM_AND_FOUNDATIONAL_LIST_QUERY =
  aiCatalogCustomAndFoundationalItemsQuery;
export const AI_CATALOG_APOLLO_PROJECT_LIST_QUERY = projectAiCatalogItemsQuery;
export const AI_CATALOG_APOLLO_PROJECT_TAB_LIST_QUERY = projectAiCatalogTabItemsQuery;
export const AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG = {
  [AI_CATALOG_TYPE_AGENT]: {
    queries: {
      item: aiCatalogAgentQuery,
    },
    mutations: {
      create: {
        mutation: createAiCatalogAgent,
        responseKey: 'aiCatalogAgentCreate',
      },
      delete: {
        mutation: deleteAiCatalogAgentMutation,
        responseKey: 'aiCatalogAgentDelete',
      },
      update: {
        mutation: updateAiCatalogAgent,
        responseKey: 'aiCatalogAgentUpdate',
      },
    },
  },
  [AI_CATALOG_TYPE_FLOW]: {
    queries: {
      item: aiCatalogFlowQuery,
    },
    mutations: {
      create: {
        mutation: createAiCatalogFlow,
        responseKey: 'aiCatalogFlowCreate',
      },
      delete: {
        mutation: deleteAiCatalogFlowMutation,
        responseKey: 'aiCatalogFlowDelete',
      },
      update: {
        mutation: updateAiCatalogFlow,
        responseKey: 'aiCatalogFlowUpdate',
      },
    },
  },
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: {
    mutations: {
      create: {
        mutation: createAiCatalogThirdPartyFlow,
        responseKey: 'aiCatalogThirdPartyFlowCreate',
      },
      delete: {
        mutation: deleteAiCatalogThirdPartyFlowMutation,
        responseKey: 'aiCatalogThirdPartyFlowDelete',
      },
      update: {
        mutation: updateAiCatalogThirdPartyFlow,
        responseKey: 'aiCatalogThirdPartyFlowUpdate',
      },
    },
  },
  [AI_CATALOG_TYPE_FOUNDATIONAL_AGENT]: {
    queries: {
      item: aiFoundationalChatAgentQuery,
    },
  },
};

export const DEFAULT_FLOW_YML_STRING = `\
# Schema version
version: "v1"
# Environment where the flow runs (ambient = GitLab's managed environment)
environment: ambient

# Components define the steps in your flow
# Each component can be an Agent, DeterministicStep, or other component types
components:
  - name: "my_agent"
    type: AgentComponent  # Options: AgentComponent, DeterministicStepComponent
    prompt_id: "my_prompt"  # References a prompt defined below
    inputs:
      - "context:goal"  # Input from user or previous component
    toolset: []  # Add tool names here: ["get_issue", "create_issue_note"]

    # Optional: UI logging
    ui_log_events:
      - "on_agent_final_answer"
      - "on_tool_execution_success"

# Define your prompts here
# Each prompt configures an AI agent's behavior
prompts:
  - prompt_id: "my_prompt"  # Must match the prompt_id referenced above
    name: "My Agent Prompt"

    # System and user prompts define the agent's behavior
    prompt_template:
      system: |
        You are GitLab Duo Chat, an agentic AI assistant.
        Your role is to help users with their GitLab tasks.
        Be concise, accurate, and actionable in your responses.

        # Add specific instructions for your use case here

      # Available variables depend on your inputs:
      # {{goal}} - The user's request
      # {{context}} - Additional context from previous steps
      user: |
        {{goal}}

      placeholder: history  # Maintains conversation context

    unit_primitives: []
    params:
      timeout: 180  # Seconds before timeout

# Routers define the flow between components
# Use "end" as the final destination
routers:
  - from: "my_agent"
    to: "end"

  # Example: Multi-step flow
  # - from: "fetch_data"
  #   to: "process_data"
  # - from: "process_data"
  #   to: "my_agent"
  # - from: "my_agent"
  #   to: "end"

# Define the entry point for your flow
flow:
  entry_point: "my_agent"
`;

export const DEFAULT_THIRD_PARTY_FLOW_YML_STRING = `\
image: alpine:latest
injectGatewayToken: true
commands:
  - echo "Hello, World!"
`;

export const AI_CATALOG_ITEM_CONSUMER_DISCLAIMER_TEXTS = {
  [AI_CATALOG_TYPE_AGENT]: {
    enabledForMembers: s__(
      'AICatalog|When you enable this agent, all project members will be able to use it.',
    ),
    projectAccess: s__(
      'AICatalog|When this agent runs, it will have access to the projects the user who runs it has access to.',
    ),
    restricted: s__(
      'AICatalog|You must have the Maintainer or Owner role to enable an agent in a project.',
    ),
  },
  [AI_CATALOG_TYPE_FLOW]: {
    compositeIdentity: s__(
      'AICatalog|Enabling this flow creates a service account, which combines with a user role into a composite identity. The flow can access all projects that either the service account or the user role can access.',
    ),
    restricted: s__(
      'AICatalog|You must have the Maintainer or Owner role to enable a flow in a project.',
    ),
  },
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: {
    compositeIdentity: s__(
      'AICatalog|Enabling this agent creates a service account, which combines with a user role into a composite identity. The agent can access all projects that either the service account or the user role can access.',
    ),
    restricted: s__(
      'AICatalog|You must have the Maintainer or Owner role to enable an agent in a project.',
    ),
  },
};
