<script>
import SafeHtml from '~/vue_shared/directives/safe_html';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { s__ } from '~/locale';
import { strictMarkdownConfig } from '~/lib/utils/text_utility';

export default {
  name: 'SolutionCard',
  directives: {
    SafeHtml,
  },
  props: {
    solutionHtml: {
      type: String,
      default: null,
      required: false,
    },
    solutionText: {
      type: String,
      default: null,
      required: false,
    },
    canDownloadPatch: {
      type: Boolean,
      required: true,
    },
  },
  safeHtmlConfig: strictMarkdownConfig,
  i18n: {
    createMergeRequestMsg: s__(
      'ciReport|Create a merge request to implement this solution, or download and apply the patch manually.',
    ),
  },
  mounted() {
    renderGFM(this.$refs.markdownContent);
  },
};
</script>
<template>
  <div>
    <h3>{{ s__('ciReport|Remediation Guidance') }}</h3>
    <p
      v-if="solutionHtml"
      ref="markdownContent"
      v-safe-html:[$options.safeHtmlConfig]="solutionHtml"
      data-testid="solution-html"
    ></p>
    <p v-else data-testid="solution-text">{{ solutionText }}</p>
    <p v-if="canDownloadPatch" class="gl-italic" data-testid="create-mr-message">
      {{ $options.i18n.createMergeRequestMsg }}
    </p>
  </div>
</template>
