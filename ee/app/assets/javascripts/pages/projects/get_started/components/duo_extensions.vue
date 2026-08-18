<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';

export default {
  name: 'DuoExtensions',
  components: { GlButton },
  mixins: [InternalEvents.mixin()],
  EXTENSIONS: [
    {
      name: __('VS Code'),
      path: helpPagePath('editor_extensions/visual_studio_code/setup.md'),
      trackingLabel: 'vs_code',
    },
    {
      name: __('Jetbrains'),
      path: helpPagePath('editor_extensions/jetbrains_ide/setup.md'),
      trackingLabel: 'jetbrains',
    },
    {
      name: __('Visual Studio'),
      path: helpPagePath('editor_extensions/visual_studio/setup.md'),
      trackingLabel: 'visual_studio',
    },
    {
      name: __('Eclipse'),
      path: helpPagePath('editor_extensions/eclipse/setup.md'),
      trackingLabel: 'eclipse',
    },
    {
      name: __('Neovim'),
      path: helpPagePath('editor_extensions/neovim/setup.md'),
      trackingLabel: 'neovim',
    },
    {
      name: __('GitLab CLI'),
      path: helpPagePath('editor_extensions/gitlab_cli/_index.md'),

      trackingLabel: 'gitlab_cli',
    },
  ],
  methods: {
    trackExtensionClick(label) {
      this.trackEvent('click_duo_extension_download_link_in_get_started', { label });
    },
  },
};
</script>
<template>
  <div>
    <header>
      <h2 class="gl-text-size-h2">{{ s__('GetStarted|Use GitLab Duo locally') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
        {{
          s__(
            'GetStarted|Download the extension to access GitLab features and GitLab Duo AI capabilities to handle everyday tasks.',
          )
        }}
      </p>
    </header>
    <gl-button
      v-for="ext in $options.EXTENSIONS"
      :key="ext.name"
      category="secondary"
      :href="ext.path"
      class="gl-mr-3 gl-mt-3"
      :data-testid="`${ext.trackingLabel}-extension-link`"
      @click="trackExtensionClick(ext.trackingLabel)"
    >
      {{ ext.name }}
    </gl-button>
  </div>
</template>
