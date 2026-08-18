<script>
import { defineComponent } from 'vue';
import { GlButton, GlButtonGroup, GlCollapsibleListbox, GlModal, GlTab, GlTabs } from '@gitlab/ui';
import SimpleCopyButton from '~/vue_shared/components/simple_copy_button.vue';
import { s__, sprintf } from '~/locale';

const HOST_DUO = 'gitlab-duo';
const HOST_CLAUDE_CODE = 'claude-code';
const HOST_CLAUDE_DESKTOP = 'claude-desktop';
const HOST_CURSOR = 'cursor';
const HOST_CODEX = 'codex';
const HOST_OPENCODE = 'opencode';

const HOST_OPTIONS = [
  { value: HOST_DUO, text: s__('Orbit|GitLab Duo') },
  { value: HOST_CLAUDE_CODE, text: s__('Orbit|Claude Code') },
  { value: HOST_CLAUDE_DESKTOP, text: s__('Orbit|Claude for Desktop') },
  { value: HOST_CURSOR, text: s__('Orbit|Cursor') },
  { value: HOST_CODEX, text: s__('Orbit|Codex') },
  { value: HOST_OPENCODE, text: s__('Orbit|OpenCode') },
];

const VIEW_CONFIGURE = 'configure';
const VIEW_TOOLS = 'tools';

const TAB_CLI = 'cli';
const TAB_MANUAL = 'manual';

const VIEW_TAB_INDEX = { [VIEW_CONFIGURE]: 0, [VIEW_TOOLS]: 1 };

const DUO_MCP_CONFIG_PATH = '~/.gitlab/duo/mcp.json';
const OPENCODE_MCP_CONFIG_PATH = '~/.config/opencode/opencode.json';

/* eslint-disable @gitlab/require-i18n-strings */
function buildCliCommand(host, endpoint) {
  switch (host) {
    case HOST_CLAUDE_CODE:
      return `claude mcp add orbit ${endpoint} \\\n   --transport http`;
    case HOST_CLAUDE_DESKTOP:
    case HOST_CURSOR:
      return `npx -y mcp-remote ${endpoint}`;
    case HOST_CODEX:
      return `codex mcp add orbit \\\n   --url ${endpoint}`;
    default:
      return null;
  }
}
/* eslint-enable @gitlab/require-i18n-strings */

function buildManualConfig(host, endpoint) {
  switch (host) {
    case HOST_DUO:
      return JSON.stringify(
        {
          mcpServers: {
            orbit: {
              type: 'http',
              url: endpoint,
              approvedTools: true,
            },
          },
        },
        null,
        2,
      );
    case HOST_CLAUDE_CODE:
    case HOST_CURSOR:
      return JSON.stringify({ mcpServers: { orbit: { type: 'http', url: endpoint } } }, null, 2);
    case HOST_CLAUDE_DESKTOP:
      return JSON.stringify(
        {
          mcpServers: {
            orbit: {
              type: 'stdio',
              command: 'npx',
              args: ['-y', 'mcp-remote', endpoint],
            },
          },
        },
        null,
        2,
      );
    case HOST_CODEX:
      return `[mcp_servers.orbit]\nurl = "${endpoint}"`;
    case HOST_OPENCODE:
      return JSON.stringify(
        {
          mcp: {
            orbit: {
              type: 'remote',
              url: endpoint,
              enabled: true,
            },
          },
        },
        null,
        2,
      );
    default:
      return '';
  }
}

const i18n = {
  title: s__('Orbit|MCP quickstart'),
  description: s__(
    'Orbit|Connect your AI assistant to Orbit via MCP. Choose your host application, then use the CLI command or manual configuration to finish setup.',
  ),
  configureTab: s__('Orbit|Configure MCP'),
  toolsTab: s__('Orbit|Tools overview'),
  hostLabel: s__('Orbit|MCP host application'),
  configureMcpHostLabel: s__('Orbit|Configure MCP host'),
  cliLabel: s__('Orbit|CLI command'),
  manualLabel: s__('Orbit|Manual configuration'),
  copyConfig: s__('Orbit|Copy configuration'),
  copyCommand: s__('Orbit|Copy command'),

  noTools: s__('Orbit|No tools available.'),
  copyToolName: s__('Orbit|Copy tool name'),
  hideSchema: s__('Orbit|Hide schema'),
  showSchema: s__('Orbit|Show schema'),
};

export default defineComponent({
  name: 'McpConfigModal',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlButtonGroup,
    GlCollapsibleListbox,
    GlModal,
    GlTab,
    GlTabs,
    SimpleCopyButton,
  },
  i18n,
  hostOptions: HOST_OPTIONS,
  cancelAction: { text: s__('Orbit|Close') },
  configTabs: [TAB_CLI, TAB_MANUAL],
  model: { prop: 'visible', event: 'change' },
  props: {
    mcpEndpoint: {
      type: String,
      required: true,
    },
    tools: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialView: {
      type: String,
      required: false,
      default: VIEW_CONFIGURE,
    },
    modalId: {
      type: String,
      required: false,
      default: 'orbit-mcp-config-modal',
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      selectedHost: HOST_DUO,
      configTab: TAB_CLI,
      activeView: this.initialView,
      expandedTools: {},
    };
  },
  computed: {
    viewTabIndex() {
      return VIEW_TAB_INDEX[this.activeView] ?? 0;
    },
    selectedHostText() {
      return HOST_OPTIONS.find((o) => o.value === this.selectedHost)?.text || '';
    },
    cliCommand() {
      return buildCliCommand(this.selectedHost, this.mcpEndpoint);
    },
    manualConfig() {
      return buildManualConfig(this.selectedHost, this.mcpEndpoint);
    },
    hasCli() {
      return Boolean(this.cliCommand);
    },
    cliDescription() {
      return sprintf(
        s__('Orbit|Run this command in your terminal to configure %{host} automatically.'),
        { host: this.selectedHostText },
      );
    },
    manualDescription() {
      if (this.selectedHost === HOST_DUO) {
        return sprintf(s__('Orbit|Add this to your %{configPath} file.'), {
          configPath: DUO_MCP_CONFIG_PATH,
        });
      }
      if (this.selectedHost === HOST_OPENCODE) {
        return sprintf(s__('Orbit|Add this to your %{configPath} file.'), {
          configPath: OPENCODE_MCP_CONFIG_PATH,
        });
      }
      return sprintf(s__('Orbit|Copy this configuration and add it to your %{host} settings.'), {
        host: this.selectedHostText,
      });
    },
    showCliBlock() {
      return this.hasCli && this.configTab === TAB_CLI;
    },
    showManualBlock() {
      return !this.hasCli || this.configTab === TAB_MANUAL;
    },
  },
  watch: {
    initialView(val) {
      this.activeView = val;
    },
  },
  methods: {
    onChange(value) {
      this.$emit('change', value);
    },
    onViewTabInput(index) {
      this.activeView = index === 0 ? VIEW_CONFIGURE : VIEW_TOOLS;
    },
    onHostSelect(value) {
      this.selectedHost = value;
    },
    selectConfigTab(tab) {
      this.configTab = tab;
    },
    isConfigTabSelected(tab) {
      return this.configTab === tab;
    },
    toolSummary(tool) {
      const toonPattern = /<toon>[\s\S]*?<\/toon>/;
      return (tool.description || '').replace(toonPattern, '').trim();
    },
    toolSchema(tool) {
      const toonPattern = /<toon>([\s\S]*?)<\/toon>/;
      const match = (tool.description || '').match(toonPattern);
      return match ? match[1].trim() : '';
    },
    toggleTool(name) {
      this.expandedTools = { ...this.expandedTools, [name]: !this.expandedTools[name] };
    },
  },
});
</script>

<template>
  <gl-modal
    :visible="visible"
    :modal-id="modalId"
    :title="$options.i18n.title"
    size="md"
    :action-cancel="$options.cancelAction"
    scrollable
    @change="onChange"
  >
    <gl-tabs :value="viewTabIndex" @input="onViewTabInput">
      <gl-tab :title="$options.i18n.configureTab">
        <p class="gl-mb-4 gl-text-sm gl-text-subtle">
          {{ $options.i18n.description }}
        </p>

        <div class="gl-mb-6">
          <label class="gl-mb-2 gl-block gl-text-sm gl-font-semibold">
            {{ $options.i18n.hostLabel }}
          </label>
          <gl-collapsible-listbox
            :items="$options.hostOptions"
            :selected="selectedHost"
            :toggle-text="selectedHostText"
            fluid-width
            @select="onHostSelect"
          />
        </div>

        <label class="gl-mb-2 gl-block gl-text-sm gl-font-semibold">
          {{ $options.i18n.configureMcpHostLabel }}
        </label>
        <gl-button-group v-if="hasCli" class="gl-mb-4">
          <gl-button
            v-for="tab in $options.configTabs"
            :key="tab"
            :selected="isConfigTabSelected(tab)"
            :data-testid="`${tab}-config-tab-btn`"
            @click="selectConfigTab(tab)"
          >
            {{ tab === 'cli' ? $options.i18n.cliLabel : $options.i18n.manualLabel }}
          </gl-button>
        </gl-button-group>

        <template v-if="showCliBlock">
          <div class="gl-mb-3 gl-flex gl-items-center gl-justify-between">
            <p class="gl-m-0 gl-text-sm gl-text-subtle">{{ cliDescription }}</p>
            <simple-copy-button
              :text="cliCommand"
              :title="$options.i18n.copyCommand"
              size="small"
              category="tertiary"
              data-testid="copy-cli-command-btn"
            />
          </div>
          <div class="markdown-code-block js-markdown-code">
            <pre
              class="code code-syntax-highlight-theme highlight js-syntax-highlight gl-rounded-base"
              >{{ cliCommand }}</pre>
          </div>
        </template>

        <template v-if="showManualBlock">
          <div class="gl-mb-3 gl-flex gl-items-center gl-justify-between">
            <p class="gl-m-0 gl-text-sm gl-text-subtle">{{ manualDescription }}</p>
            <simple-copy-button
              :text="manualConfig"
              :title="$options.i18n.copyConfig"
              size="small"
              category="tertiary"
              data-testid="copy-manual-config-btn"
            />
          </div>
          <div class="markdown-code-block js-markdown-code">
            <pre
              class="code code-syntax-highlight-theme highlight js-syntax-highlight gl-rounded-base"
              >{{ manualConfig }}</pre>
          </div>
        </template>
      </gl-tab>

      <gl-tab :title="$options.i18n.toolsTab">
        <div class="gl-flex gl-flex-col gl-gap-4">
          <p v-if="tools.length === 0" class="gl-text-sm gl-text-subtle">
            {{ $options.i18n.noTools }}
          </p>

          <div
            v-for="tool in tools"
            :key="tool.name"
            class="gl-border gl-rounded-lg gl-border-solid gl-border-default gl-p-4"
          >
            <div class="gl-mb-2 gl-flex gl-items-center gl-gap-2">
              <code class="gl-font-bold">{{ tool.name }}</code>
              <simple-copy-button
                :text="tool.name"
                :title="$options.i18n.copyToolName"
                size="small"
                category="tertiary"
                data-testid="copy-tool-name-btn"
              />
            </div>
            <p class="gl-mb-0 gl-whitespace-pre-line gl-text-sm gl-text-subtle">
              {{ toolSummary(tool) }}
            </p>
            <template v-if="toolSchema(tool)">
              <gl-button variant="link" size="small" class="gl-mt-2" @click="toggleTool(tool.name)">
                {{ expandedTools[tool.name] ? $options.i18n.hideSchema : $options.i18n.showSchema }}
              </gl-button>
              <pre
                v-if="expandedTools[tool.name]"
                class="gl-mb-0 gl-mt-2 gl-overflow-x-auto gl-whitespace-pre-wrap gl-rounded-base gl-bg-subtle gl-p-3 gl-font-monospace gl-text-sm"
                >{{ toolSchema(tool) }}</pre>
            </template>
          </div>
        </div>
      </gl-tab>
    </gl-tabs>
  </gl-modal>
</template>
