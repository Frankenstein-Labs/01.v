<script>
import { uniqueId } from 'lodash-es';
import {
  GlBadge,
  GlButton,
  GlLink,
  GlForm,
  GlFormInput,
  GlFormTextarea,
  GlTokenSelector,
  GlTooltipDirective,
  GlAlert,
  GlSprintf,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  MAX_LENGTH_PROMPT,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_AGENT,
  DEFAULT_THIRD_PARTY_FLOW_YML_STRING,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from 'ee/ai/catalog/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import { getCancelRoute, getSubmitButtonText } from '../utils';
import { canReadMcpServer, showTypeSelectionInAgentForm } from '../permissions';
import aiCatalogBuiltInToolsQuery from '../graphql/queries/ai_catalog_built_in_tools.query.graphql';
import aiCatalogMcpToolsQuery from '../graphql/queries/ai_catalog_mcp_tools.query.graphql';
import aiCatalogMcpServersQuery from '../graphql/queries/ai_catalog_mcp_servers.query.graphql';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import FormGroup from './form_group.vue';
import FormSection from './form_section.vue';
import FormAgentType from './form_agent_type.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import VisibilityLevelRadioGroup from './visibility_level_radio_group.vue';

export default {
  name: 'AiCatalogAgentForm',
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    FormAgentType,
    FormFlowDefinition,
    FormGroup,
    FormSection,
    FormProjectDropdown,
    GlBadge,
    GlButton,
    GlLink,
    GlForm,
    GlFormInput,
    GlFormTextarea,
    GlTokenSelector,
    GlAlert,
    GlSprintf,
    VisibilityLevelRadioGroup,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
  inject: {
    projectId: {
      default: null,
    },
    isGlobalNamespace: {},
    instanceBetaFeaturesEnabled: {
      default: false,
    },
  },
  apollo: {
    availableBuiltInTools: {
      query: aiCatalogBuiltInToolsQuery,
      update: (data) =>
        data.aiCatalogBuiltInTools.nodes.map((t) => ({
          id: t.id,
          machineName: t.title.toLowerCase().replace(/\s+/g, '_'),
          name: t.title,
          description: t.description,
          source: 'builtin',
        })),
      error(error) {
        Sentry.captureException(error);
      },
    },
    availableMcpTools: {
      query: aiCatalogMcpToolsQuery,
      update: (data) =>
        (data.aiCatalogMcpTools?.nodes ?? []).map((t) => ({
          id: `mcp-${t.name}`,
          mcpName: t.name,
          machineName: t.name,
          name: t.title,
          description: t.description,
          source: 'mcp',
          iconUrl: (t.icons?.find((i) => i.theme === 'light') || t.icons?.[0])?.src ?? null,
        })),
      error(error) {
        Sentry.captureException(error);
      },
    },
    availableMcpServers: {
      query: aiCatalogMcpServersQuery,
      variables: {
        first: 100,
      },
      skip() {
        return !this.glAbilities?.readAiCatalogMcpServer;
      },
      update: (data) =>
        data.aiCatalogMcpServers.nodes.map((s) => ({
          id: s.id,
          name: s.name,
          description: s.description,
        })),
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => ['edit', 'create'].includes(mode),
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    errors: {
      type: Array,
      required: true,
    },
    initialValues: {
      type: Object,
      required: false,
      default() {
        return {
          projectId: null,
          name: '',
          description: '',
          systemPrompt: '', // agent specific
          tools: [], // agent specific
          mcpTools: [], // agent specific
          mcpServers: [], // agent specific
          definition: DEFAULT_THIRD_PARTY_FLOW_YML_STRING, // third_party_flow specific
          public: false,
          itemType: AI_CATALOG_TYPE_AGENT,
          visibility: VISIBILITY_LEVEL_PRIVATE,
        };
      },
    },
  },
  emits: ['dismiss-errors', 'select-item-type', 'submit'],
  data() {
    const visibility = this.initialValues.public
      ? VISIBILITY_LEVEL_PUBLIC
      : VISIBILITY_LEVEL_PRIVATE;
    return {
      availableBuiltInTools: [],
      availableMcpTools: [],
      availableMcpServers: [],
      toolFilter: '',
      mcpServerFilter: '',
      formValues: {
        ...this.initialValues,
        projectId:
          !this.isGlobalNamespace && this.projectId
            ? convertToGraphQLId(TYPENAME_PROJECT, this.projectId)
            : this.initialValues.projectId,
        visibilityLevel: this.glFeatures.aiCatalogInternalVisibility
          ? this.initialValues.visibility
          : visibility,
        mcpServers: this.initialValues.mcpServers,
      },
      formErrors: [],
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-agent-form-');
    },
    isThirdPartyFlow() {
      return this.formValues.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    showTypeSelection() {
      return showTypeSelectionInAgentForm({
        isEditMode: this.isEditMode,
        glAbilities: this.glAbilities,
        glFeatures: this.glFeatures,
      });
    },
    mcpToolsEnabled() {
      return this.instanceBetaFeaturesEnabled;
    },
    preferMcpToolsEnabled() {
      return Boolean(this.glFeatures.duoAgenticChatPreferMcpTools);
    },
    canReadMcpServers() {
      return canReadMcpServer({ glAbilities: this.glAbilities });
    },
    allErrors() {
      return [...this.errors, ...this.formErrors];
    },
    submitButtonText() {
      return getSubmitButtonText(this.isEditMode, s__('AICatalog|Create agent'));
    },
    cancelRoute() {
      return getCancelRoute(
        this.$route.params,
        AI_CATALOG_AGENTS_SHOW_ROUTE,
        AI_CATALOG_AGENTS_ROUTE,
      );
    },
    availableTools() {
      const mcpToolsWithState = this.availableMcpTools.map((t) => ({
        ...t,
        disabled: !this.mcpToolsEnabled,
      }));

      // Dedup mirrors AI Gateway's prefer_mcp_tools behavior: when a tool exists in
      // both DAP and the GitLab MCP server, the MCP entry wins. Saved DAP selections
      // are preserved so save/edit roundtrips never silently drop a token.
      // source: 'mcp' is kept (not 'gitlab_mcp') because availableMcpTools today only
      // contains GitLab-internal MCP tools. Revisit when third-party MCP server tools
      // surface here.
      if (this.preferMcpToolsEnabled) {
        const mcpNames = new Set(mcpToolsWithState.map((t) => t.machineName));
        const selectedDapNames = new Set(this.formValues.tools);
        const dapKept = this.availableBuiltInTools.filter(
          (t) => !mcpNames.has(t.machineName) || selectedDapNames.has(t.id),
        );
        return [...mcpToolsWithState, ...dapKept].sort((a, b) => a.name.localeCompare(b.name));
      }

      return [...this.availableBuiltInTools, ...mcpToolsWithState].sort((a, b) =>
        a.name.localeCompare(b.name),
      );
    },
    filteredAvailableTools() {
      return this.availableTools.filter((tool) =>
        tool.name.toLowerCase().includes(this.toolFilter.toLowerCase()),
      );
    },
    selectedTools() {
      const selectedBuiltIn = this.availableTools.filter(
        (tool) => tool.source === 'builtin' && this.formValues.tools.includes(tool.id),
      );
      const availableMcpNames = new Set(this.availableMcpTools.map((t) => t.machineName));
      const selectedMcp = this.availableTools.filter(
        (tool) => tool.source === 'mcp' && this.formValues.mcpTools.includes(tool.mcpName),
      );
      // Create placeholder tokens for saved MCP tools not in the available list
      // (e.g., when the feature flag is off and the query was skipped)
      const savedMcpPlaceholders = this.formValues.mcpTools
        .filter((name) => !availableMcpNames.has(name))
        .map((name) => ({
          id: `mcp-${name}`,
          mcpName: name,
          machineName: name,
          name,
          description: '',
          source: 'mcp',
          disabled: true,
        }));
      // gl-token-selector forwards token.style onto its rendered gl-token, so we can
      // tint MCP tokens here instead of overriding via scoped CSS.
      return [...selectedBuiltIn, ...selectedMcp, ...savedMcpPlaceholders].map((tool) => ({
        ...tool,
        style:
          tool.source === 'mcp' && !tool.disabled
            ? {
                borderColor: 'var(--gl-feedback-warning-border-color)',
                backgroundColor: 'var(--gl-feedback-warning-background-color)',
              }
            : null,
      }));
    },
    filteredAvailableMcpServers() {
      return this.availableMcpServers.filter((server) =>
        server.name.toLowerCase().includes(this.mcpServerFilter.toLowerCase()),
      );
    },
    selectedMcpServers() {
      return this.availableMcpServers.filter((server) =>
        this.formValues.mcpServers.includes(server.id),
      );
    },
  },
  watch: {
    'formValues.projectId': function validateProjectField() {
      this.$nextTick(() => {
        this.$refs.fieldProject?.validate();
      });
    },
    'formValues.itemType': {
      handler(newItemType) {
        this.$emit('select-item-type', newItemType);
      },
    },
  },
  methods: {
    handleSubmit() {
      const isFormValid = this.validate();
      if (!isFormValid) {
        return;
      }

      const transformedValues = {
        projectId: this.isEditMode ? undefined : this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        itemType: this.formValues.itemType,
      };

      if (this.glFeatures.aiCatalogInternalVisibility) {
        transformedValues.visibility = this.formValues.visibilityLevel;
      } else {
        transformedValues.public = this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC;
      }

      if (this.isThirdPartyFlow) {
        transformedValues.definition = this.formValues.definition.trim();
      } else {
        transformedValues.systemPrompt = this.formValues.systemPrompt.trim();
        transformedValues.tools = this.formValues.tools;
        transformedValues.mcpTools = this.formValues.mcpTools;
        transformedValues.mcpServers = this.formValues.mcpServers;
      }

      this.$emit('submit', transformedValues);
    },
    handleToolsInput(input) {
      this.formValues.tools = input
        .filter((t) => t.source === 'builtin' && !t.disabled)
        .map((t) => t.id);
      this.formValues.mcpTools = input.filter((t) => t.source === 'mcp').map((t) => t.mcpName);
    },
    handleToolSearch(search) {
      this.toolFilter = search;
    },
    handleMcpServersInput(input) {
      this.formValues.mcpServers = input.map((s) => s.id);
    },
    handleMcpServerSearch(search) {
      this.mcpServerFilter = search;
    },
    onError(error) {
      this.formErrors.push(error);
    },
    dismissErrors() {
      this.formErrors = [];
      this.$emit('dismiss-errors');
    },
    validate() {
      return Object.keys(this.$refs)
        .filter((key) => key.startsWith('field'))
        .reduce((allValid, key) => {
          const field = this.$refs[key];
          if (!field) return allValid;
          const isFieldValid = this.$refs[key].validate();
          return allValid && isFieldValid;
        }, true);
    },
  },
  visibilityLevelTexts: {
    textPrivate: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE],
    textRestricted: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_RESTRICTED],
    textPublic: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC],
  },
  fields: {
    projectId: {
      id: 'agent-form-project-id',
      label: s__('AICatalog|Managed by'),
      validations: {
        requiredLabel: s__('AICatalog|Project is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Only members of this project can edit or delete this agent.',
        ),
      },
    },
    name: {
      id: 'agent-form-name',
      label: __('Display name'),
      validations: {
        requiredLabel: s__('AICatalog|Name is required.'),
        maxLength: MAX_LENGTH_NAME,
      },
      inputAttrs: {
        'data-testid': 'agent-form-input-name',
        placeholder: s__('AICatalog|Research Assistant, Creative Writer, Code Helper'),
      },
    },
    description: {
      id: 'agent-form-description',
      label: __('Description'),
      validations: {
        requiredLabel: s__('AICatalog|Description is required.'),
        maxLength: MAX_LENGTH_DESCRIPTION,
      },
    },
    itemType: {
      id: 'agent-form-type',
      label: __('Type'),
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Build a custom agent in GitLab or connect to an AI model provider you already use.',
        ),
      },
    },
    systemPrompt: {
      id: 'agent-form-system-prompt',
      label: s__('AICatalog|System prompt'),
      validations: {
        requiredLabel: s__('AICatalog|System prompt is required.'),
        maxLength: MAX_LENGTH_PROMPT,
      },
      groupAttrs: {
        labelDescription: s__(
          "AICatalog|Define the agent's personality, expertise, and behavior. This changes how the agent solves problems and responds to requests.",
        ),
      },
    },
    visibilityLevel: {
      id: 'agent-form-visibility-level',
      label: __('Visibility'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Choose who can view and interact with this agent.'),
      },
    },
    tools: {
      id: 'agent-form-tools',
      label: s__('AICatalog|Tools'),
      groupAttrs: {
        optional: true,
      },
    },
    mcpServers: {
      id: 'agent-form-mcp-servers',
      label: s__('AICatalog|MCP servers'),
      groupAttrs: {
        optional: true,
        labelDescription: s__(
          'AICatalog|Connect Model Context Protocol servers to extend this agent with external tools and data sources.',
        ),
      },
    },
    definition: {
      id: 'agent-form-configuration',
      label: s__('AICatalog|YAML configuration'),
      validations: {
        requiredLabel: s__('AICatalog|Configuration is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|This YAML configuration file determines the prompts, tools, and capabilities of your flow. Required properties: injectGatewayToken, image, commands',
        ),
      },
    },
  },
  AI_CATALOG_TYPE_AGENT,
  VISIBILITY_LEVEL_PUBLIC,
  toolsDocsLink: helpPagePath('user/duo_agent_platform/agents/tools'),
  publicDeletionHelpLink: helpPagePath('user/duo_agent_platform/agents/custom', {
    anchor: 'agent-visibility',
  }),
};
</script>

<template>
  <div>
    <errors-alert :errors="allErrors" @dismiss="dismissErrors" />
    <gl-form :id="formId" class="gl-flex gl-flex-col gl-gap-5" @submit.prevent="handleSubmit">
      <form-section :title="s__('AICatalog|Basic information')">
        <form-group
          #default="{ state, blur }"
          ref="fieldName"
          :field="$options.fields.name"
          :field-value="formValues.name"
        >
          <gl-form-input
            :id="$options.fields.name.id"
            v-model="formValues.name"
            :data-testid="$options.fields.name.inputAttrs['data-testid']"
            :placeholder="$options.fields.name.inputAttrs.placeholder"
            :state="state"
            @blur="blur"
          />
        </form-group>
        <form-group
          #default="{ state, blur }"
          ref="fieldDescription"
          :field="$options.fields.description"
          :field-value="formValues.description"
        >
          <gl-form-textarea
            :id="$options.fields.description.id"
            v-model="formValues.description"
            :no-resize="false"
            :placeholder="
              s__(
                'AICatalog|This agent specializes in... It can help you with... Best suited for...',
              )
            "
            :state="state"
            data-testid="agent-form-textarea-description"
            @blur="blur"
          />
        </form-group>
      </form-section>
      <form-section :title="s__('AICatalog|Visibility & access')">
        <form-group
          v-if="isGlobalNamespace"
          ref="fieldProject"
          :field="$options.fields.projectId"
          :field-value="formValues.projectId"
        >
          <form-project-dropdown
            :id="$options.fields.projectId.id"
            v-model="formValues.projectId"
            :disabled="isEditMode"
            @error="onError"
          />
        </form-group>
        <form-group
          :field="$options.fields.visibilityLevel"
          :field-value="formValues.visibilityLevel"
        >
          <visibility-level-radio-group
            :id="$options.fields.visibilityLevel.id"
            v-model="formValues.visibilityLevel"
            :item-type="$options.AI_CATALOG_TYPE_AGENT"
            :texts="$options.visibilityLevelTexts"
          />
          <gl-alert
            v-if="formValues.visibilityLevel === $options.VISIBILITY_LEVEL_PUBLIC"
            :dismissible="false"
            class="gl-mt-2"
          >
            <gl-sprintf
              :message="
                s__(
                  `AICatalog|If a public agent is enabled, you can't delete it or make it private. %{linkStart}Learn more about agent visibility.%{linkEnd}`,
                )
              "
            >
              <template #link="{ content }">
                <gl-link :href="$options.publicDeletionHelpLink">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </gl-alert>
        </form-group>
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')">
        <form-group
          v-if="showTypeSelection"
          :field="$options.fields.itemType"
          :field-value="formValues.itemType"
        >
          <form-agent-type v-model="formValues.itemType" :disabled="isEditMode" />
        </form-group>
        <form-group
          v-if="isThirdPartyFlow"
          ref="fieldDefinitionThirdPartyFlow"
          :key="$options.fields.definition.id"
          :field="$options.fields.definition"
          :field-value="formValues.definition"
        >
          <form-flow-definition
            v-model="formValues.definition"
            data-testid="flow-form-definition-third-party-flow"
          />
        </form-group>
        <template v-else>
          <form-group :field="$options.fields.tools" :field-value="formValues.tools">
            <template #label-description>
              <span>{{ s__('AICatalog|Tools are built and maintained by GitLab.') }}</span>
              <gl-link :href="$options.toolsDocsLink" target="_blank">{{
                s__('AICatalog|What are tools?')
              }}</gl-link>
            </template>
            <gl-token-selector
              :id="$options.fields.tools.id"
              :selected-tokens="selectedTools"
              :dropdown-items="filteredAvailableTools"
              :placeholder="s__('AICatalog|Search tools.')"
              allow-clear-all
              data-testid="agent-form-token-selector-tools"
              @input="handleToolsInput"
              @text-input="handleToolSearch"
              @keydown.enter.prevent
            >
              <template #dropdown-item-content="{ dropdownItem }">
                <span
                  :aria-disabled="dropdownItem.disabled ? 'true' : null"
                  :class="{ 'gl-text-disabled': dropdownItem.disabled }"
                  class="gl-flex gl-w-full gl-items-center gl-justify-between gl-gap-2"
                  data-testid="agent-form-tool-dropdown-row"
                >
                  <span
                    v-gl-tooltip="
                      dropdownItem.disabled
                        ? s__(
                            'AICatalog|Enable experiment and beta features in admin settings to use this tool.',
                          )
                        : dropdownItem.description
                    "
                    >{{ dropdownItem.name }}</span
                  >
                  <span
                    v-if="dropdownItem.source === 'mcp'"
                    class="gl-flex gl-items-center gl-gap-2"
                    role="group"
                    :aria-label="s__('AICatalog|GitLab MCP tool, beta')"
                  >
                    <gl-badge size="sm" variant="neutral" aria-hidden="true">{{
                      s__('AICatalog|Beta')
                    }}</gl-badge>
                    <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
                    <img
                      v-if="dropdownItem.iconUrl"
                      v-gl-tooltip="s__('AICatalog|GitLab MCP')"
                      :src="dropdownItem.iconUrl"
                      alt=""
                      class="gl-h-4 gl-w-4 gl-rounded-sm"
                      aria-hidden="true"
                    />
                    <!-- eslint-enable @gitlab/vue-require-i18n-attribute-strings -->
                  </span>
                </span>
              </template>
              <template #token-content="{ token }">
                <span
                  :aria-disabled="token.disabled ? 'true' : null"
                  :class="[
                    'gl-flex gl-items-center gl-gap-2',
                    { 'gl-text-disabled gl-line-through': token.disabled },
                  ]"
                  data-testid="agent-form-tool-token"
                >
                  <span
                    v-gl-tooltip="
                      token.disabled
                        ? s__(
                            'AICatalog|Enable experiment and beta features in admin settings to use this tool.',
                          )
                        : token.description
                    "
                    >{{ token.name }}</span
                  >
                  <gl-badge
                    v-if="token.source === 'mcp'"
                    size="sm"
                    variant="neutral"
                    :aria-label="s__('AICatalog|GitLab MCP tool, beta')"
                  >
                    {{ s__('AICatalog|Beta') }}
                  </gl-badge>
                  <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
                  <img
                    v-if="token.source === 'mcp' && token.iconUrl"
                    v-gl-tooltip="s__('AICatalog|GitLab MCP')"
                    :src="token.iconUrl"
                    alt=""
                    class="gl-mr-1 gl-h-4 gl-w-4 gl-rounded-sm"
                    aria-hidden="true"
                  />
                  <!-- eslint-enable @gitlab/vue-require-i18n-attribute-strings -->
                </span>
              </template>
            </gl-token-selector>
          </form-group>
          <form-group
            v-if="canReadMcpServers"
            :field="$options.fields.mcpServers"
            :field-value="formValues.mcpServers"
          >
            <gl-token-selector
              :id="$options.fields.mcpServers.id"
              :selected-tokens="selectedMcpServers"
              :dropdown-items="filteredAvailableMcpServers"
              :placeholder="s__('AICatalog|Search MCP servers.')"
              allow-clear-all
              data-testid="agent-form-token-selector-mcp-servers"
              @input="handleMcpServersInput"
              @text-input="handleMcpServerSearch"
              @keydown.enter.prevent
            >
              <template #token-content="{ token }">
                <span v-gl-tooltip="token.description">
                  {{ token.name }}
                </span>
              </template>
            </gl-token-selector>
          </form-group>
          <form-group
            #default="{ state, blur }"
            ref="fieldSystemPrompt"
            :field="$options.fields.systemPrompt"
            :field-value="formValues.systemPrompt"
          >
            <gl-form-textarea
              :id="$options.fields.systemPrompt.id"
              v-model="formValues.systemPrompt"
              :no-resize="false"
              :placeholder="
                s__(
                  'AICatalog|You are an expert in [domain]. Your communication style is [style]. When helping users, you should always... Your key strengths include... You approach problems by...',
                )
              "
              :rows="20"
              data-testid="agent-form-textarea-system-prompt"
              :state="state"
              @blur="blur"
            />
          </form-group>
        </template>
      </form-section>
      <ai-catalog-form-buttons :is-disabled="isLoading" :cancel-route="cancelRoute">
        <gl-button
          class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
          type="submit"
          variant="confirm"
          category="primary"
          data-testid="agent-form-submit-button"
          :loading="isLoading"
        >
          {{ submitButtonText }}
        </gl-button>
      </ai-catalog-form-buttons>
    </gl-form>
  </div>
</template>
