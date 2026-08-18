<script>
import { defineComponent } from 'vue';
import { GlButton } from '@gitlab/ui';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { InternalEvents } from '~/tracking';
import { s__ } from '~/locale';
import { buildApiUrl } from '~/api/api_utils';

const mcpEndpoint = `${window.location.origin}${buildApiUrl('/api/:version/orbit/mcp')}`;
// eslint-disable-next-line @gitlab/require-i18n-strings
const glabInstallCommand = 'glab orbit setup';

export default defineComponent({
  name: 'OrbitConnectExternalTools',
  compatConfig: { MODE: 3 },
  components: { GlButton, ClipboardButton },
  mixins: [InternalEvents.mixin()],
  emits: ['quick-start'],
  mcpEndpoint,
  glabInstallCommand,
  i18n: {
    subhead: s__(
      'Orbit|Query Orbit directly, or power up your agents with GitLab context. Using Orbit outside of GitLab uses GitLab Credits.',
    ),
    cliLabel: s__('Orbit|CLI & API'),
    mcpLabel: s__('Orbit|MCP'),
    copyInstallCommand: s__('Orbit|Copy install command'),
    copyMcpEndpoint: s__('Orbit|Copy MCP endpoint'),
    quickStart: s__('Orbit|MCP quickstart'),
  },
  methods: {
    onQuickStart() {
      this.trackEvent('click_orbit_mcp_quickstart');
      this.$emit('quick-start');
    },
    trackCopy(label) {
      this.trackEvent('click_orbit_copy_to_clipboard', { label });
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-4" data-testid="connect-links">
    <p class="gl-mb-0 gl-text-subtle">{{ $options.i18n.subhead }}</p>
    <div class="gl-flex gl-items-center gl-gap-3">
      <span class="gl-w-16 gl-shrink-0 gl-text-sm gl-font-semibold">
        {{ $options.i18n.cliLabel }}
      </span>
      <code class="gl-font-monospace gl-text-sm gl-text-default">
        {{ $options.glabInstallCommand }}
      </code>
      <clipboard-button
        :text="$options.glabInstallCommand"
        :title="$options.i18n.copyInstallCommand"
        size="small"
        category="tertiary"
        @click="trackCopy('CLI')"
      />
    </div>
    <div class="gl-flex gl-items-start gl-gap-3">
      <span class="gl-w-16 gl-shrink-0 gl-pt-1 gl-text-sm gl-font-semibold">
        {{ $options.i18n.mcpLabel }}
      </span>
      <span class="gl-min-w-0 gl-flex-1 gl-break-all">
        <code class="gl-text-sm gl-text-default">{{ $options.mcpEndpoint }}</code>
        <clipboard-button
          :text="$options.mcpEndpoint"
          :title="$options.i18n.copyMcpEndpoint"
          size="small"
          category="tertiary"
          class="gl-align-middle"
          @click="trackCopy('MCP')"
        />
      </span>
    </div>
    <div>
      <gl-button @click="onQuickStart">
        {{ $options.i18n.quickStart }}
      </gl-button>
    </div>
  </div>
</template>
