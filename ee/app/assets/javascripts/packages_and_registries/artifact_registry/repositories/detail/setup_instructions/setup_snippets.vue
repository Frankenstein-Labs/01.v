<script>
import { GlSprintf } from '@gitlab/ui';
import { SETUP_SECTION_INSTALL, SETUP_SECTION_PUBLISH } from '../../../constants';
import { buildRepositoryClientUrl } from '../../../utils';
import SnippetCodeBlock from './snippet_code_block.vue';
import { setupSnippetSections } from './snippets';

export default {
  name: 'ArtifactRegistrySetupSnippets',
  components: {
    GlSprintf,
    SnippetCodeBlock,
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
    tool: {
      type: String,
      required: true,
    },
    section: {
      type: String,
      required: false,
      default: SETUP_SECTION_INSTALL,
      validator: (value) => [SETUP_SECTION_INSTALL, SETUP_SECTION_PUBLISH].includes(value),
    },
  },
  computed: {
    repositoryUrl() {
      const { clientBaseUrl, slug, format, name } = this;

      return buildRepositoryClientUrl({ clientBaseUrl, slug, format, name });
    },
    sections() {
      const { format, tool, section, name, repositoryUrl } = this;

      return setupSnippetSections({ format, tool, section, name, repositoryUrl });
    },
  },
};
</script>

<template>
  <div>
    <section
      v-for="(setupSection, sectionIndex) in sections"
      :key="sectionIndex"
      data-testid="setup-section"
    >
      <h3 v-if="setupSection.heading" class="gl-heading-3 gl-mt-5">{{ setupSection.heading }}</h3>

      <div
        v-for="(block, blockIndex) in setupSection.blocks"
        :key="blockIndex"
        class="gl-mb-4"
        data-testid="setup-block"
      >
        <p class="gl-mb-3">
          <gl-sprintf :message="block.text">
            <template #code="{ content }">
              <code>{{ content }}</code>
            </template>
          </gl-sprintf>
        </p>

        <snippet-code-block v-if="block.code" :snippet="block.code" :copy-text="block.copyText" />
      </div>
    </section>
  </div>
</template>
