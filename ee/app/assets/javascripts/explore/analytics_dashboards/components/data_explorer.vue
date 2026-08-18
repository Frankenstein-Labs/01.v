<script>
// This component is still under active development. Updates on the current progress
// can be found in https://gitlab.com/groups/gitlab-org/-/epics/19359
import EMPTY_CHART_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-chart-md.svg?url';
import { GlFormTextarea, GlButton, GlDashboardPanel, GlEmptyState, GlLink } from '@gitlab/ui';
import SimpleCopyButton from '~/vue_shared/components/simple_copy_button.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import AnalyticsDashboardPanel from '~/analytics/shared/components/analytics_dashboard_panel.vue';
import { wrapGlqlInVisualization, parseGlqlTitle } from 'ee/explore/analytics_dashboards/utils';

export default {
  name: 'DataExplorer',
  components: {
    GlFormTextarea,
    GlButton,
    GlDashboardPanel,
    GlEmptyState,
    GlLink,
    SimpleCopyButton,
    AnalyticsDashboardPanel,
  },
  glqlDocsLink: helpPagePath('user/glql/_index'),
  EMPTY_CHART_SVG,
  model: {
    prop: 'query',
    event: 'input',
  },
  props: {
    query: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['submit', 'input'],
  data() {
    return {
      submittedQuery: '',
      retryCount: 0,
    };
  },
  computed: {
    hasQueryText() {
      return this.query.trim() !== '';
    },
    visualization() {
      return wrapGlqlInVisualization(this.submittedQuery);
    },
    panelTitle() {
      return parseGlqlTitle(this.submittedQuery);
    },
  },
  methods: {
    handleRunQuery() {
      if (this.submittedQuery === this.query) {
        this.retryCount += 1;
      } else {
        this.retryCount = 0;
        this.submittedQuery = this.query;
      }

      this.$emit('submit', this.submittedQuery);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <div class="gl-relative">
      <gl-form-textarea
        :value="query"
        :aria-label="s__('DataExplorer|Data query')"
        :placeholder="s__('DataExplorer|// TYPE YOUR QUERY HERE')"
        :no-resize="false"
        rows="16"
        textarea-classes="!gl-p-6 !gl-font-monospace"
        autofocus
        @input="$emit('input', $event)"
      />
      <simple-copy-button
        v-if="hasQueryText"
        :title="s__('DataExplorer|Copy query')"
        :text="query"
        class="gl-absolute gl-right-6 gl-top-6 gl-z-1"
      />

      <gl-link :href="$options.glqlDocsLink" class="gl-absolute gl-bottom-6 gl-right-6 gl-z-1">{{
        s__('DataExplorer|What is GLQL?')
      }}</gl-link>
    </div>

    <div>
      <gl-button variant="confirm" icon="play" :disabled="!hasQueryText" @click="handleRunQuery">{{
        s__('DataExplorer|Run query')
      }}</gl-button>
    </div>

    <analytics-dashboard-panel
      v-if="submittedQuery"
      :key="retryCount"
      :title="panelTitle"
      :visualization="visualization"
    />
    <gl-dashboard-panel v-else>
      <template #body>
        <gl-empty-state
          :title="s__('DataExplorer|Preview not available')"
          :description="s__('DataExplorer|Start by typing a GLQL query.')"
          :svg-path="$options.EMPTY_CHART_SVG"
        />
      </template>
    </gl-dashboard-panel>
  </div>
</template>
