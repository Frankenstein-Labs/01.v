<script>
import { GlButton, GlSprintf, GlDrawer } from '@gitlab/ui';
import Markdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';

export const i18n = {
  subtext: s__("Workspaces|What's the %{linkStart}Gitlab default devfile%{linkEnd}?"),
  drawerTitle: s__('Workspaces|GitLab devfile'),
  drawerParagraph1: s__(
    'Workspaces|A devfile is a file that defines a development environment by specifying the necessary tools, languages, runtimes, and other components for a GitLab project.',
  ),
  drawerParagraph2: s__(
    'Workspaces|When no devfile is provided, the GitLab default devfile will be used.',
  ),
  drawerParagraph3: s__(
    'Workspaces|Workspaces have built-in support for devfiles. The default location is .devfile.yaml, but you can also use a custom location. The devfile is used to automatically configure the development environment with the defined specifications.',
  ),
  drawerDefaultDevfileTitle: s__('Workspaces|GitLab default devfile contents'),
};

export default {
  name: 'DevfileHelpDrawer',
  components: {
    GlButton,
    GlSprintf,
    GlDrawer,
    Markdown,
  },
  inject: ['defaultDevfile'],
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  methods: {
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  i18n,
  DRAWER_Z_INDEX,
};
</script>

<template>
  <div class="gl-mt-3">
    <gl-sprintf :message="$options.i18n.subtext">
      <template #link="{ content }">
        <gl-button variant="link" @click="openDrawer">{{ content }}</gl-button>
      </template>
    </gl-sprintf>
    <gl-drawer
      :open="isDrawerOpen"
      :title="$options.i18n.drawerTitle"
      size="lg"
      class="gl-p-5"
      :z-index="$options.DRAWER_Z_INDEX"
      @close="closeDrawer"
    >
      <template #title>
        <h2 data-testid="drawer-title" class="gl-my-0 gl-text-size-h2 gl-leading-24">
          {{ $options.i18n.drawerTitle }}
        </h2>
      </template>

      <template #default>
        <div class="gl-flex gl-flex-col">
          <p>{{ $options.i18n.drawerParagraph1 }}</p>
          <p>{{ $options.i18n.drawerParagraph2 }}</p>
          <p class="gl-mb-0">{{ $options.i18n.drawerParagraph3 }}</p>
          <h3 data-testid="secondary-title" class="gl-my-6 gl-text-lg">
            {{ $options.i18n.drawerDefaultDevfileTitle }}
          </h3>
          <markdown :markdown="'```yaml\n' + defaultDevfile + '\n```'" />
        </div>
      </template>
    </gl-drawer>
  </div>
</template>
