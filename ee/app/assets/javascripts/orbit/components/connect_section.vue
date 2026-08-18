<script>
import { defineComponent } from 'vue';
import { GlButton, GlLink, GlModalDirective } from '@gitlab/ui';
import { DOCS_URL } from '~/constants';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { visitUrl } from '~/lib/utils/url_utility';
import { buildApiUrl } from '~/api/api_utils';
import { DUO_CHAT_AGENT_GITLAB_DUO } from 'ee/ai/constants';
import { fetchOrbitTools } from '../api/orbit_api';
import orbitSettingsUpdateMutation from '../graphql/mutations/orbit_settings_update.mutation.graphql';
import McpConfigModal from './mcp_config_modal.vue';
import ConnectExternalTools from './connect_external_tools.vue';
import ConnectCollapsibleSection from './connect_collapsible_section.vue';

const ALL_ORBIT_SETTINGS_ON = {
  enabled: true,
  orbit_agent_enabled: true,
  orbit_agentic_chat_enabled: true,
  orbit_other_foundational_agents_enabled: true,
  orbit_custom_agents_enabled: true,
};

const SUGGESTED_QUERIES = [
  s__('Orbit|Show me recent merge requests with failing pipelines'),
  s__('Orbit|What open vulnerabilities exist in my projects?'),
  s__('Orbit|List pipelines that failed in the last week'),
  s__('Orbit|Who merged the most this quarter?'),
];

const mcpEndpoint = `${window.location.origin}${buildApiUrl('/api/:version/orbit/mcp')}`;

// Some suggested queries are statements ("Show me…", "List…") and some are
// already questions. Add a period to statements so the trailing terminator
// is consistent in the UI.
const formatDisplay = (query) => (query.endsWith('?') ? query : `${query}.`);

const i18n = {
  connectTitle: s__('Orbit|Connect to Orbit'),
  connectSubtitle: s__(
    'Orbit|Orbit gives your AI tools structured access to everything in GitLab, with intelligent relationships that help agents understand your codebase.',
  ),
  tryAsking: s__('Orbit|Try asking…'),
  enableDuoToAsk: s__('Orbit|Enable GitLab Duo Agent Platform to ask…'),
  docs: s__('Orbit|Learn more'),
  close: __('Close'),
  duoSectionTitle: s__('Orbit|Use Orbit with GitLab Duo'),
  duoSectionSubhead: s__('Orbit|GitLab Duo will use Orbit to provide enhanced intelligence.'),
  toolsSectionTitle: s__('Orbit|Connect Orbit to your tools'),
  orbitOff: s__('Orbit|Orbit is turned off in GitLab Duo.'),
  useOrbitInDuo: s__('Orbit|Use Orbit in GitLab Duo'),
  // Hidden hint appended to the prompt sent to Duo agentic chat so the
  // model is steered to use Orbit's MCP tools. Not displayed in the UI.
  useOrbitHint: s__('Orbit|Use Orbit.'),
  enableFailed: s__('Orbit|Failed to enable Orbit in GitLab Duo. Please try again.'),
};

export default defineComponent({
  name: 'ConnectSection',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlLink,
    McpConfigModal,
    ConnectCollapsibleSection,
    ConnectExternalTools,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  props: {
    duoAccessible: {
      type: Boolean,
      required: false,
      default: false,
    },
    orbitSettingsEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close'],
  mcpEndpoint,
  docsHref: `${DOCS_URL}/orbit/`,
  suggestedQueries: SUGGESTED_QUERIES,
  formatDisplay,
  i18n,
  data() {
    return {
      tools: [],
      modalInitialView: 'configure',
      mcpModalVisible: false,
      open: { duo: false, tools: false },
      // Local mirror so we can flip it after the enable mutation
      // without re-fetching the page.
      orbitEnabled: this.orbitSettingsEnabled,
      enabling: false,
    };
  },
  computed: {
    orbitActionable() {
      return this.duoAccessible && this.orbitEnabled;
    },
  },
  async mounted() {
    try {
      const { data } = await fetchOrbitTools();
      // /api/v4/orbit/tools returns a top-level array; older shapes wrap as
      // { tools: [...] }. Accept both so a backend tweak doesn't blank the UI.
      this.tools = Array.isArray(data) ? data : data?.tools || [];
    } catch (error) {
      Sentry.captureException(error);
    }
  },
  methods: {
    onSuggestionClick(query) {
      const prompt = `${formatDisplay(query)} ${this.$options.i18n.useOrbitHint}`;
      import('ee/ai/utils')
        .then(({ sendDuoChatCommand }) => {
          sendDuoChatCommand({
            question: prompt,
            resourceId: 'orbit-suggested-prompt',
            agenticPrompt: prompt,
            agent: { name: DUO_CHAT_AGENT_GITLAB_DUO },
          });
        })
        .catch(() => {
          visitUrl(`${DOCS_URL}/orbit/duo_chat/`);
        });
    },
    openConfigure() {
      this.modalInitialView = 'configure';
      this.mcpModalVisible = true;
    },
    async enableOrbitInDuo() {
      if (this.enabling) return;
      this.enabling = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: orbitSettingsUpdateMutation,
          variables: {
            input: { orbitSettings: ALL_ORBIT_SETTINGS_ON },
          },
        });
        const errors = data?.userPreferencesUpdate?.errors || [];
        if (errors.length) throw new Error(errors.join(', '));
        this.orbitEnabled = true;
      } catch (error) {
        Sentry.captureException(error);
        createAlert({ message: this.$options.i18n.enableFailed, captureError: true, error });
      } finally {
        this.enabling = false;
      }
    },
  },
});
</script>

<template>
  <div
    class="orbit-dot-grid-host gl-relative gl-overflow-hidden gl-rounded-lg gl-border-1 gl-border-solid gl-border-subtle gl-bg-subtle gl-px-6 gl-py-8"
    data-testid="connect-section"
  >
    <div class="orbit-dot-grid" aria-hidden="true"></div>

    <gl-button
      class="gl-absolute gl-right-4 gl-top-4 gl-z-1"
      size="small"
      category="tertiary"
      icon="close"
      :aria-label="$options.i18n.close"
      data-testid="connect-close"
      @click="$emit('close')"
    />

    <div class="gl-relative gl-mx-auto gl-flex gl-max-w-75 gl-flex-col gl-gap-5">
      <div>
        <h2 class="gl-heading-3 gl-mb-3">{{ $options.i18n.connectTitle }}</h2>
        <p class="gl-mb-0">
          {{ $options.i18n.connectSubtitle }}
          <gl-link :href="$options.docsHref">{{ $options.i18n.docs }}</gl-link>
        </p>
      </div>

      <div class="gl-flex gl-flex-col gl-gap-3">
        <!-- Use Orbit with GitLab Duo -->
        <connect-collapsible-section
          :open="open.duo"
          icon="tanuki-ai"
          :title="$options.i18n.duoSectionTitle"
          testid="duo-section"
          @update:open="open.duo = $event"
        >
          <p class="gl-mb-3 gl-text-subtle">{{ $options.i18n.duoSectionSubhead }}</p>

          <div
            v-if="duoAccessible && !orbitEnabled"
            class="gl-flex gl-flex-wrap gl-items-center gl-gap-3"
            data-testid="orbit-off-prompt"
          >
            <span>{{ $options.i18n.orbitOff }}</span>
            <gl-button
              :loading="enabling"
              data-testid="enable-orbit-in-duo"
              @click="enableOrbitInDuo"
            >
              {{ $options.i18n.useOrbitInDuo }}
            </gl-button>
          </div>

          <template v-else>
            <p class="gl-mb-2 gl-font-bold">
              {{ orbitActionable ? $options.i18n.tryAsking : $options.i18n.enableDuoToAsk }}
            </p>
            <div class="gl-flex gl-flex-col">
              <template v-if="orbitActionable">
                <button
                  v-for="(query, index) in $options.suggestedQueries"
                  :key="index"
                  type="button"
                  class="gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-border-0 gl-bg-transparent gl-px-2 gl-py-2 gl-text-left gl-text-sm gl-text-default hover:gl-bg-strong"
                  :class="
                    index < $options.suggestedQueries.length - 1
                      ? 'gl-border-b gl-border-default'
                      : ''
                  "
                  data-testid="suggested-query"
                  @click="onSuggestionClick(query)"
                >
                  {{ $options.formatDisplay(query) }}
                </button>
              </template>
              <template v-else>
                <div
                  v-for="(query, index) in $options.suggestedQueries"
                  :key="index"
                  class="gl-flex gl-w-full gl-py-2"
                  :class="
                    index < $options.suggestedQueries.length - 1
                      ? 'gl-border-b gl-border-subtle'
                      : ''
                  "
                  data-testid="suggested-query-readonly"
                >
                  {{ $options.formatDisplay(query) }}
                </div>
              </template>
            </div>
          </template>
        </connect-collapsible-section>

        <!-- Connect Orbit to your tools -->
        <connect-collapsible-section
          :open="open.tools"
          icon="connected"
          :title="$options.i18n.toolsSectionTitle"
          testid="tools-section"
          @update:open="open.tools = $event"
        >
          <connect-external-tools @quick-start="openConfigure" />
        </connect-collapsible-section>
      </div>
    </div>

    <mcp-config-modal
      :visible="mcpModalVisible"
      :mcp-endpoint="$options.mcpEndpoint"
      :tools="tools"
      :initial-view="modalInitialView"
      @change="mcpModalVisible = $event"
    />
  </div>
</template>
