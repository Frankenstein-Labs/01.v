<script>
import emptyStateSvgPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-package-md.svg';
import { GlEmptyState, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { SETUP_SECTION_PUBLISH, SETUP_TOOLS } from '../../constants';
import { buildRepositoryClientUrl, isContainerFormat } from '../../utils';
import SnippetCodeBlock from './setup_instructions/snippet_code_block.vue';
import { setupSnippetSections } from './setup_instructions/snippets';
import ToolSelector from './setup_instructions/tool_selector.vue';

export default {
  name: 'ArtifactRegistryArtifactsEmptyState',
  components: {
    GlEmptyState,
    GlSprintf,
    SnippetCodeBlock,
    ToolSelector,
  },
  inject: ['slug', 'clientBaseUrl'],
  props: {
    name: {
      type: String,
      required: true,
    },
    format: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      selectedTool: null,
    };
  },
  computed: {
    readsImages() {
      return isContainerFormat(this.format);
    },
    title() {
      const { imagesTitle, packagesTitle } = this.$options.i18n;

      return this.readsImages ? imagesTitle : packagesTitle;
    },
    description() {
      const { imagesDescription, packagesDescription } = this.$options.i18n;

      return this.readsImages ? imagesDescription : packagesDescription;
    },
    tools() {
      return SETUP_TOOLS[this.format] ?? [];
    },
    activeTool() {
      const selected = this.tools.find(({ value }) => value === this.selectedTool);

      return selected?.value ?? this.tools[0]?.value ?? '';
    },
    repositoryUrl() {
      const { clientBaseUrl, slug, format, name } = this;

      return buildRepositoryClientUrl({ clientBaseUrl, slug, format, name });
    },
    steps() {
      const { format, activeTool: tool, name, repositoryUrl } = this;

      const [publishSection, ...setupSections] = setupSnippetSections({
        format,
        tool,
        section: SETUP_SECTION_PUBLISH,
        name,
        repositoryUrl,
      });

      if (!publishSection) return [];

      return [...setupSections, publishSection].flatMap(({ blocks }) => blocks);
    },
  },
  i18n: {
    packagesTitle: s__('ArtifactRegistry|There are no packages in this repository yet'),
    imagesTitle: s__('ArtifactRegistry|There are no images in this repository yet'),
    packagesDescription: s__('ArtifactRegistry|Publish your first package to get started.'),
    imagesDescription: s__('ArtifactRegistry|Publish your first image to get started.'),
    cliCommands: s__('ArtifactRegistry|CLI commands'),
  },
  emptyStateSvgPath,
};
</script>

<template>
  <div>
    <gl-empty-state
      :svg-path="$options.emptyStateSvgPath"
      :title="title"
      :description="description"
    />

    <div v-if="steps.length" class="gl-text-center" data-testid="empty-state-setup">
      <div class="gl-mb-4 gl-flex gl-items-center gl-justify-center gl-gap-3">
        <h3 class="gl-heading-3 gl-mb-0">{{ $options.i18n.cliCommands }}</h3>

        <tool-selector :format="format" :selected="activeTool" @select="selectedTool = $event" />
      </div>

      <ol class="gl-mb-0 gl-pl-5 gl-text-left">
        <li
          v-for="(step, index) in steps"
          :key="index"
          class="gl-mb-4"
          data-testid="empty-state-step"
        >
          <p class="gl-mb-3">
            <gl-sprintf :message="step.text">
              <template #code="{ content }">
                <code>{{ content }}</code>
              </template>
            </gl-sprintf>
          </p>

          <snippet-code-block v-if="step.code" :snippet="step.code" :copy-text="step.copyText" />
        </li>
      </ol>
    </div>
  </div>
</template>
