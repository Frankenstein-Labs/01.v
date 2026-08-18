<script>
import { GlIcon, GlCard } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { renderGFM } from '~/behaviors/markdown/render_gfm';

export default {
  name: 'SolutionCardGraphql',
  directives: {
    SafeHtml,
  },
  components: { GlIcon, GlCard },
  props: {
    solutionHtml: {
      type: String,
      default: null,
      required: false,
    },
    solution: {
      type: String,
      default: '',
      required: false,
    },
    remediation: {
      type: Object,
      default: null,
      required: false,
    },
    mergeRequest: {
      type: Object,
      default: null,
      required: false,
    },
  },
  computed: {
    solutionText() {
      return this.solution || this.remediation?.summary;
    },
    showCreateMergeRequestMessage() {
      return !this.hasMr && this.remediation?.diff?.length > 0;
    },
    hasMr() {
      return Boolean(this.mergeRequest?.id);
    },
  },
  mounted() {
    renderGFM(this.$refs.markdownContent);
  },
};
</script>

<template>
  <gl-card v-if="solutionHtml || solutionText" class="gl-my-6">
    <template #default>
      <div class="gl-flex gl-items-start">
        <div class="gl-flex gl-items-center gl-justify-end gl-pl-0 gl-pr-5">
          <gl-icon class="gl-mr-3" name="bulb" />
          <strong data-testid="solution-title">{{ s__('ciReport|Remediation Guidance') }}</strong>
        </div>
        <span
          v-if="solutionHtml"
          ref="markdownContent"
          v-safe-html="solutionHtml"
          class="md"
          data-testid="solution-html"
        ></span>
        <span v-else data-testid="solution-text">{{ solutionText }}</span>
      </div>
    </template>
    <template v-if="showCreateMergeRequestMessage" #footer>
      <em class="gl-text-subtle" data-testid="merge-request-solution">
        {{
          s__(
            'ciReport|Create a merge request to implement this solution, or download and apply the patch manually.',
          )
        }}
      </em>
    </template>
  </gl-card>
</template>
