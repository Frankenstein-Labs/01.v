<script>
import { GlDrawer, GlTab, GlTabs } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { MountingPortal } from 'portal-vue';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { s__ } from '~/locale';
import { SETUP_SECTION_INSTALL, SETUP_SECTION_PUBLISH, SETUP_TOOLS } from '../../../constants';
import SetupSnippets from './setup_snippets.vue';
import ToolSelector from './tool_selector.vue';

export default {
  name: 'ArtifactRegistrySetupDrawer',
  components: {
    GlDrawer,
    GlTab,
    GlTabs,
    MountingPortal,
    SetupSnippets,
    ToolSelector,
  },
  props: {
    open: {
      type: Boolean,
      required: false,
      default: false,
    },
    name: {
      type: String,
      required: true,
    },
    format: {
      type: String,
      required: true,
    },
  },
  emits: ['close'],
  data() {
    return {
      selectedTool: null,
      titleId: uniqueId('setup-drawer-title-'),
    };
  },
  computed: {
    headerHeight() {
      return getContentWrapperHeight();
    },
    tools() {
      return SETUP_TOOLS[this.format] ?? [];
    },
    activeTool() {
      const selected = this.tools.find(({ value }) => value === this.selectedTool);

      return selected?.value ?? this.tools[0]?.value ?? '';
    },
  },
  watch: {
    open(open) {
      if (open) this.selectedTool = null;
    },
  },
  i18n: {
    title: s__('ArtifactRegistry|Setup instructions'),
    install: s__('ArtifactRegistry|Install'),
    publish: s__('ArtifactRegistry|Publish'),
  },
  sections: {
    install: SETUP_SECTION_INSTALL,
    publish: SETUP_SECTION_PUBLISH,
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <!-- Mounted at the body: .panel-content is a containing block for fixed descendants
  (contain: layout), which would otherwise scope this drawer to the panel. -->
  <mounting-portal mount-to="body" append>
    <gl-drawer
      :aria-labelledby="titleId"
      :open="open"
      :header-height="headerHeight"
      :z-index="$options.DRAWER_Z_INDEX"
      header-sticky
      @close="$emit('close')"
    >
      <template #title>
        <h2 :id="titleId" class="gl-my-0 gl-text-size-h2 gl-leading-24">
          {{ $options.i18n.title }}
        </h2>
      </template>

      <gl-tabs class="!gl-pt-0">
        <gl-tab :title="$options.i18n.install" data-testid="install-tab">
          <setup-snippets
            :name="name"
            :format="format"
            :tool="activeTool"
            :section="$options.sections.install"
          />
        </gl-tab>

        <gl-tab :title="$options.i18n.publish" data-testid="publish-tab">
          <setup-snippets
            :name="name"
            :format="format"
            :tool="activeTool"
            :section="$options.sections.publish"
          />
        </gl-tab>

        <template #toolbar-end>
          <tool-selector
            class="gl-ml-auto gl-self-center"
            :format="format"
            :selected="activeTool"
            @select="selectedTool = $event"
          />
        </template>
      </gl-tabs>
    </gl-drawer>
  </mounting-portal>
</template>
