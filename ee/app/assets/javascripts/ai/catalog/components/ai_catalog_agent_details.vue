<script>
import {
  GlBadge,
  GlLink,
  GlSprintf,
  GlToken,
  GlTooltipDirective,
  GlTruncateText,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToTitleCase } from '~/lib/utils/text_utility';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { canReadMcpServer } from '../permissions';
import { getByVersionKey, isGitLabMaintainedItem } from '../utils';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from '../constants';
import aiCatalogMcpToolsQuery from '../graphql/queries/ai_catalog_mcp_tools.query.graphql';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemFieldServiceAccount from './ai_catalog_item_field_service_account.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import TriggerField from './trigger_field.vue';
import FormSection from './form_section.vue';

export default {
  name: 'AiCatalogAgentDetails',
  components: {
    AiCatalogItemField,
    AiCatalogItemFieldServiceAccount,
    AiCatalogItemVisibilityField,
    FormFlowDefinition,
    FormSection,
    GlBadge,
    GlLink,
    GlSprintf,
    GlToken,
    GlTruncateText,
    TriggerField,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    instanceBetaFeaturesEnabled: {
      default: false,
    },
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
  },
  apollo: {
    availableMcpTools: {
      query: aiCatalogMcpToolsQuery,
      update: (data) =>
        Object.fromEntries((data.aiCatalogMcpTools?.nodes ?? []).map((t) => [t.name, t])),
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      availableMcpTools: {},
    };
  },
  truncateTextToggleButtonProps: {
    class: 'gl-font-regular',
  },
  computed: {
    isGitLabMaintained() {
      return isGitLabMaintainedItem(this.item);
    },
    projectName() {
      return this.item.project?.nameWithNamespace;
    },
    version() {
      return getByVersionKey(this.item, this.versionKey);
    },
    mcpToolsEnabled() {
      return this.instanceBetaFeaturesEnabled;
    },
    tools() {
      const builtInTools = (this.version.tools?.nodes ?? []).map((t) => ({
        key: `builtin-${t.id}`,
        title: t.title,
        description: t.description,
        source: 'builtin',
        iconUrl: null,
        disabled: false,
      }));
      const mcpTools = (this.version.mcpTools ?? []).map((name) => {
        const enriched = this.availableMcpTools?.[name];
        const icon = enriched?.icons?.find((i) => i.theme === 'light') || enriched?.icons?.[0];
        return {
          key: `mcp-${name}`,
          title: enriched?.title ?? convertToTitleCase(name.replace(/_/g, ' ')),
          description: enriched?.description ?? '',
          source: 'mcp',
          iconUrl: icon?.src ?? null,
          disabled: !this.mcpToolsEnabled,
        };
      });
      return [...builtInTools, ...mcpTools].sort((a, b) => a.title.localeCompare(b.title));
    },
    mcpServers() {
      return [...(this.version.mcpServers?.nodes ?? [])].sort((a, b) =>
        a.name.localeCompare(b.name),
      );
    },
    systemPrompt() {
      return this.version.systemPrompt;
    },
    definition() {
      return this.version.definition;
    },
    isThirdPartyFlow() {
      return this.item.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    typeField() {
      if (this.isThirdPartyFlow) {
        return s__('AICatalog|External');
      }
      if (this.item.foundational) {
        return s__('AICatalog|Foundational');
      }
      return s__('AICatalog|Custom');
    },
    hasProjectConfiguration() {
      return Boolean(this.item.configurationForProject);
    },
    serviceAccount() {
      if (this.hasProjectConfiguration) {
        return this.item.configurationForProject?.flowTrigger?.user;
      }
      return this.item.configurationForGroup?.serviceAccount;
    },
    canReadMcpServers() {
      return canReadMcpServer({ glAbilities: this.glAbilities });
    },
  },
  methods: {
    tokenStyleFor(tool) {
      if (tool.source !== 'mcp' || tool.disabled) return null;
      return {
        borderColor: 'var(--gl-feedback-warning-border-color)',
        backgroundColor: 'var(--gl-feedback-warning-background-color)',
      };
    },
  },
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  toolsDocsLink: helpPagePath('user/duo_agent_platform/agents/tools'),
};
</script>

<template>
  <div>
    <h2 class="gl-heading-3">
      {{ s__('AICatalog|Agent configuration') }}
    </h2>
    <dl class="gl-flex gl-flex-col gl-gap-5">
      <form-section :title="s__('AICatalog|Visibility & access')" is-display>
        <ai-catalog-item-field
          v-if="projectName || isGitLabMaintained"
          :title="s__('AICatalog|Managed by')"
          data-testid="managed-by-field"
        >
          <gl-link v-if="!isGitLabMaintained" :href="item.project.webUrl">{{
            projectName
          }}</gl-link>
          <span v-else>{{ s__('AICatalog|GitLab') }}</span>
        </ai-catalog-item-field>
        <ai-catalog-item-visibility-field
          :public="item.public"
          :visibility="item.visibility"
          :description-texts="$options.AGENT_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
      </form-section>
      <form-section v-if="serviceAccount" :title="s__('AICatalog|Service account')" is-display>
        <ai-catalog-item-field-service-account
          :service-account="serviceAccount"
          :item-type="item.itemType"
          data-testid="service-account-field"
        />
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')" is-display>
        <ai-catalog-item-field :title="s__('AICatalog|Type')" :value="typeField" />
        <template v-if="isThirdPartyFlow">
          <trigger-field v-if="hasProjectConfiguration" :item="item" />
          <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
            <form-flow-definition :value="definition" read-only class="gl-mt-3" />
          </ai-catalog-item-field>
        </template>
        <template v-else>
          <ai-catalog-item-field :title="s__('AICatalog|Tools')">
            <p class="gl-text-subtle">
              <gl-sprintf
                :message="
                  s__(
                    'AICatalog|Tools are built and maintained by GitLab. %{linkStart}What are tools?%{linkEnd}',
                  )
                "
              >
                <template #link="{ content }">
                  <gl-link :href="$options.toolsDocsLink">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </p>
            <span v-if="tools.length === 0" class="gl-text-subtle">
              {{ __('None') }}
            </span>
            <div v-else class="gl-mt-3 gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap">
              <gl-token
                v-for="tool in tools"
                :key="tool.key"
                view-only
                class="gl-min-h-7 gl-cursor-default gl-px-3 gl-py-1"
                :class="{ 'gl-opacity-5': tool.disabled }"
                :style="tokenStyleFor(tool)"
                :aria-disabled="tool.disabled ? 'true' : null"
              >
                <span
                  :class="[
                    'gl-flex gl-items-center gl-gap-2',
                    { 'gl-text-disabled gl-line-through': tool.disabled },
                  ]"
                >
                  <span
                    v-gl-tooltip
                    :title="
                      tool.disabled
                        ? s__(
                            'AICatalog|Enable experiment and beta features in admin settings to use this tool.',
                          )
                        : tool.description
                    "
                    data-testid="tool-description-tooltip"
                    >{{ tool.title }}</span
                  >
                  <gl-badge
                    v-if="tool.source === 'mcp'"
                    size="sm"
                    variant="neutral"
                    :aria-label="s__('AICatalog|GitLab MCP tool, beta')"
                  >
                    {{ s__('AICatalog|Beta') }}
                  </gl-badge>
                  <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
                  <img
                    v-if="tool.source === 'mcp' && tool.iconUrl"
                    v-gl-tooltip="s__('AICatalog|GitLab MCP')"
                    :src="tool.iconUrl"
                    alt=""
                    class="gl-ml-1 gl-h-4 gl-w-4 gl-rounded-sm"
                    aria-hidden="true"
                  />
                  <!-- eslint-enable @gitlab/vue-require-i18n-attribute-strings -->
                </span>
              </gl-token>
            </div>
          </ai-catalog-item-field>
          <ai-catalog-item-field v-if="canReadMcpServers" :title="s__('AICatalog|MCP servers')">
            <p class="gl-text-subtle">
              {{ s__('AICatalog|MCP servers allow your agent to connect with external tools.') }}
            </p>
            <span v-if="mcpServers.length === 0" class="gl-text-subtle">
              {{ __('None') }}
            </span>
            <div v-else class="gl-mt-3 gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap">
              <span
                v-for="server in mcpServers"
                :key="server.id"
                v-gl-tooltip
                :title="server.description"
                data-testid="mcp-server-description-tooltip"
              >
                <gl-token view-only class="gl-cursor-default">
                  {{ server.name }}
                </gl-token>
              </span>
            </div>
          </ai-catalog-item-field>
          <ai-catalog-item-field :title="s__('AICatalog|System prompt')">
            <div class="gl-border gl-mt-3 gl-rounded-default gl-bg-default gl-p-3">
              <pre class="gl-m-0 gl-whitespace-pre-wrap"><gl-truncate-text
              :lines="20"
              :show-more-text="__('Show more')"
              :show-less-text="__('Show less')"
              :toggle-button-props="$options.truncateTextToggleButtonProps"
              class="gl-flex gl-flex-col gl-items-start gl-gap-3"
            >{{ systemPrompt }}</gl-truncate-text></pre>
            </div>
          </ai-catalog-item-field>
        </template>
      </form-section>
    </dl>
  </div>
</template>
