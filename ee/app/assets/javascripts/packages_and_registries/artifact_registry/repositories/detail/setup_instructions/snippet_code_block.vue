<script>
import CodeBlock from '~/vue_shared/components/code_block.vue';
import SimpleCopyButton from '~/vue_shared/components/simple_copy_button.vue';

export default {
  name: 'ArtifactRegistrySnippetCodeBlock',
  components: {
    CodeBlock,
    SimpleCopyButton,
  },
  props: {
    snippet: {
      type: String,
      required: true,
    },
    copyText: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-relative">
    <code-block
      :code="snippet"
      class="gl-mb-0 gl-whitespace-pre-wrap gl-border-1 gl-border-solid gl-border-default gl-p-3 gl-pr-7"
      data-testid="snippet"
    />
    <simple-copy-button
      :text="snippet"
      :title="copyText"
      size="small"
      class="gl-absolute gl-right-2 gl-top-2"
    />
  </div>
</template>
