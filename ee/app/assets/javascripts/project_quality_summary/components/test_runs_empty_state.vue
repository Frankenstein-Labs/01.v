<script>
import { GlEmptyState, GlLink, GlIcon } from '@gitlab/ui';
import TEST_RUNS_EMPTY_STATE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import { i18n } from '../constants';

export default {
  name: 'TestRunsEmptyState',
  components: {
    GlEmptyState,
    GlLink,
    GlIcon,
  },
  testRunsHelpPath: helpPagePath('ci/testing/code_coverage/_index.md'),
  i18n,
  TEST_RUNS_EMPTY_STATE_SVG,
};
</script>
<template>
  <div>
    <gl-empty-state
      :svg-path="$options.TEST_RUNS_EMPTY_STATE_SVG"
      :svg-height="null"
      class="gl-items-center"
    >
      <template #title>
        <h5 class="gl-my-4 gl-block gl-text-lg">
          {{ $options.i18n.testRuns.title }}
        </h5>
      </template>
      <template #description>
        {{ $options.i18n.testRuns.emptyStateDescription }}
      </template>
      <template #actions>
        <gl-link
          :href="$options.testRunsHelpPath"
          target="_blank"
          rel="noopener noreferrer"
          :aria-label="$options.i18n.testRuns.emptyStateLinkLabel"
          >{{ $options.i18n.testRuns.emptyStateLink }}
          <gl-icon name="external-link" />
        </gl-link>
      </template>
    </gl-empty-state>
  </div>
</template>
