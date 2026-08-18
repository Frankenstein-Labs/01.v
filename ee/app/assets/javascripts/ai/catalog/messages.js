import { s__ } from '~/locale';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from './constants';

export const AGENT_MESSAGES = {
  common: {
    label: s__('AICatalog|agent'),
    pluralLabel: s__('AICatalog|agents'),
    pageTitle: s__('AICatalog|Agents'),
    errorMessage: s__('AICatalog|Agent does not exist'),
    notFoundTitle: s__('AICatalog|Agent not found.'),
  },
  disable: {
    success: s__('AICatalog|Agent disabled in this %{namespaceType}.'),
    error: s__('AICatalog|Failed to disable agent'),
    confirmTitleTemplate: s__('AICatalog|Disable agent from this %{namespaceType}'),
    confirmMessageProject: s__(
      'AICatalog|Are you sure you want to disable agent %{name}? The agent will no longer work in this project.',
    ),
    confirmMessageGroup: s__(
      'AICatalog|Are you sure you want to disable agent %{name}? The agent will also be disabled from any projects in this group.',
    ),
  },
  index: {
    errorMessage: s__('AICatalog|There was a problem fetching agents.'),
    emptyStateTitleTemplate: s__('AICatalog|Use agents in your %{namespaceType}.'),
    emptyStateDescription: s__('AICatalog|Use agents to automate tasks and answer questions.'),
    itemTypeDisabledCanAdminAlert: s__(
      'AICatalog|Custom agents are inactive for all projects. To create or use custom agents, %{linkStart}turn on custom agents%{linkEnd}.',
    ),
    itemTypeDisabledAlert: s__(
      'AICatalog|Custom agents are inactive for all projects. To create or use custom agents, contact group owner.',
    ),
    duoSettingsDisabledEnabledTooltip: s__(
      'AICatalog|Enabling custom agents is turned off. Contact an administrator to change this.',
    ),
  },
  show: {
    enableErrorTitle: s__('AICatalog|Could not enable agent'),
    enableToastTemplate: s__('AICatalog|Agent enabled in %{name}.'),
    enableErrorTemplate: s__(
      'AICatalog|Could not enable agent in the %{target}. Check that the %{target} meets the %{linkStart}prerequisites%{linkEnd} and try again.',
    ),
    disableErrorTemplate: s__('AICatalog|Failed to disable agent. %{error}'),
    hardDeletedToast: s__('AICatalog|Agent deleted.'),
    softDeletedToast: s__('AICatalog|Agent hidden.'),
    deleteErrorTemplate: s__('AICatalog|Failed to delete agent. %{error}'),
    reportErrorTemplate: s__('AICatalog|Failed to report agent. %{error}'),
  },
  create: {
    heading: s__('AICatalog|New agent'),
    description: s__(
      'AICatalog|Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
    ),
    createdMessage: s__('AICatalog|Agent created.'),
    errorMessage: s__(
      'AICatalog|Could not create agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
    ),
  },
  edit: {
    heading: s__('AICatalog|Edit agent'),
    description: s__('AICatalog|Manage agent settings.'),
    updatedMessage: s__('AICatalog|Agent updated.'),
    errorMessage: s__('AICatalog|Could not update agent. Try again.'),
    versionWarningMessage: s__(
      'AICatalog|To prevent versioning issues, you can edit only the latest version of this agent. To edit an earlier version, %{linkStart}duplicate the agent%{linkEnd}.',
    ),
  },
  duplicate: {
    heading: s__('AICatalog|Duplicate agent'),
    description: s__('AICatalog|Create a copy of this agent with the same configuration.'),
    createdMessage: s__('AICatalog|Agent created.'),
    errorMessage: s__(
      'AICatalog|Could not create agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
    ),
  },
};

export const FLOW_MESSAGES = {
  common: {
    label: s__('AICatalog|flow'),
    pluralLabel: s__('AICatalog|flows'),
    pageTitle: s__('AICatalog|Flows'),
    errorMessage: s__('AICatalog|Flow does not exist'),
    notFoundTitle: s__('AICatalog|Flow not found.'),
  },
  disable: {
    success: s__('AICatalog|Flow disabled in this %{namespaceType}.'),
    error: s__('AICatalog|Failed to disable flow'),
    confirmTitleTemplate: s__('AICatalog|Disable flow from this %{namespaceType}'),
    confirmMessageProject: s__(
      'AICatalog|Are you sure you want to disable flow %{name}? The flow, its service account, and any associated triggers will no longer work in this project.',
    ),
    confirmMessageGroup: s__(
      'AICatalog|Are you sure you want to disable flow %{name}? The flow will also be disabled from any projects in this group.',
    ),
  },
  index: {
    errorMessage: s__('AICatalog|There was a problem fetching flows.'),
    emptyStateTitleTemplate: s__('AICatalog|Use flows in your %{namespaceType}.'),
    emptyStateDescription: s__(
      'AICatalog|Flows use multiple agents to complete tasks automatically.',
    ),
    itemTypeDisabledCanAdminAlert: s__(
      'AICatalog|Custom flows are inactive for all projects. To create or use custom flows, %{linkStart}turn on custom flows%{linkEnd}.',
    ),
    itemTypeDisabledAlert: s__(
      'AICatalog|Custom flows are inactive for all projects. To create or use custom flows, contact group owner.',
    ),
    duoSettingsDisabledEnabledTooltip: s__(
      'AICatalog|Enabling custom flows is turned off. Contact an administrator to change this.',
    ),
  },
  show: {
    enableErrorTitle: s__('AICatalog|Could not enable flow'),
    enableToastTemplate: s__('AICatalog|Flow enabled in %{name}.'),
    enableErrorTemplate: s__(
      'AICatalog|Could not enable flow in the %{target}. Check that the %{target} meets the %{linkStart}prerequisites%{linkEnd} and try again.',
    ),
    disableErrorTemplate: s__('AICatalog|Failed to disable flow. %{error}'),
    hardDeletedToast: s__('AICatalog|Flow deleted.'),
    softDeletedToast: s__('AICatalog|Flow hidden.'),
    deleteErrorTemplate: s__('AICatalog|Failed to delete flow. %{error}'),
    reportErrorTemplate: s__('AICatalog|Failed to report flow. %{error}'),
  },
  create: {
    heading: s__('AICatalog|New flow'),
    description: s__('AICatalog|Use flows to automate complex, multi-step tasks.'),
    createdMessage: s__('AICatalog|Flow created.'),
    errorMessage: s__(
      'AICatalog|Could not create flow in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
    ),
  },
  edit: {
    heading: s__('AICatalog|Edit flow'),
    description: s__('AICatalog|Manage flow settings.'),
    updatedMessage: s__('AICatalog|Flow updated.'),
    errorMessage: s__('AICatalog|Could not update flow. Try again.'),
    versionWarningMessage: s__(
      'AICatalog|To prevent versioning issues, you can edit only the latest version of this flow. To edit an earlier version, %{linkStart}duplicate the flow%{linkEnd}.',
    ),
  },
  duplicate: {
    heading: s__('AICatalog|Duplicate flow'),
    description: s__('AICatalog|Duplicate this flow with all its settings and configuration.'),
    createdMessage: s__('AICatalog|Flow created.'),
    errorMessage: s__(
      'AICatalog|Could not create flow in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
    ),
  },
};

export const THIRD_PARTY_FLOW_MESSAGES = {
  ...AGENT_MESSAGES,
  index: {
    ...AGENT_MESSAGES.index,
    itemTypeDisabledCanAdminAlert: s__(
      'AICatalog|External agents are inactive for all projects. To create or use external agents, %{linkStart}turn on external agents%{linkEnd}.',
    ),
    itemTypeDisabledAlert: s__(
      'AICatalog|External agents are inactive for all projects. To create or use external agents, contact group owner.',
    ),
    duoSettingsDisabledEnabledTooltip: s__(
      'AICatalog|Enabling external agents is turned off. Contact an administrator to change this.',
    ),
  },
};

export const MESSAGES_BY_TYPE = {
  [AI_CATALOG_TYPE_AGENT]: AGENT_MESSAGES,
  [AI_CATALOG_TYPE_FLOW]: FLOW_MESSAGES,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: THIRD_PARTY_FLOW_MESSAGES,
};
